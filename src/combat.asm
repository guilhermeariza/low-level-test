; ============================================================================
; combat.asm - Full combat system
; Tasks 2.01-2.14: Damage types, armor/MR, crit, lifesteal, CC, tower aggro,
;                  plates, bounties, assist gold
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_range, ent_speed, ent_atk_speed
extern ent_atk_cooldown, ent_atk_target
extern ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_xp, ent_count
extern entity_kill

section .data

align 8
hundred_d:  dq 100.0
sixty_d:    dq 60.0
zero_d:     dq 0.0

section .bss

; Extended combat stats per entity (SoA)
alignb 64
global ent_armor, ent_mr, ent_ap
global ent_armor_pen_flat, ent_armor_pen_pct, ent_magic_pen_flat, ent_magic_pen_pct
global ent_crit_chance, ent_crit_mult, ent_lifesteal, ent_spell_vamp
global ent_cdr, ent_tenacity, ent_lethality
global ent_shield, ent_shield_timer
global ent_kill_streak, ent_death_streak
global ent_last_attacker, ent_assist_list, ent_assist_count

ent_armor:          resd MAX_ENTITIES
ent_mr:             resd MAX_ENTITIES
ent_ap:             resd MAX_ENTITIES
ent_armor_pen_flat: resd MAX_ENTITIES
ent_armor_pen_pct:  resd MAX_ENTITIES   ; percent (0-100)
ent_magic_pen_flat: resd MAX_ENTITIES
ent_magic_pen_pct:  resd MAX_ENTITIES
ent_crit_chance:    resd MAX_ENTITIES   ; 0-100%
ent_crit_mult:      resd MAX_ENTITIES   ; 175 = 175% = 1.75x
ent_lifesteal:      resd MAX_ENTITIES   ; 0-100%
ent_spell_vamp:     resd MAX_ENTITIES
ent_cdr:            resd MAX_ENTITIES   ; 0-40%
ent_tenacity:       resd MAX_ENTITIES   ; 0-100%
ent_lethality:      resd MAX_ENTITIES
ent_shield:         resd MAX_ENTITIES   ; current shield amount
ent_shield_timer:   resd MAX_ENTITIES   ; frames until shield expires

ent_kill_streak:    resd MAX_ENTITIES
ent_death_streak:   resd MAX_ENTITIES
ent_last_attacker:  resd MAX_ENTITIES   ; who last hit us
; Assist tracking: last 5 entities that damaged us
ent_assist_list:    resd MAX_ENTITIES * 5
ent_assist_count:   resd MAX_ENTITIES

; Tower aggro state
alignb 64
global tower_aggro_target, tower_aggro_prio
tower_aggro_target: resd MAX_ENTITIES   ; who this tower is targeting
tower_aggro_prio:   resd MAX_ENTITIES   ; priority level

; Tower plates
global tower_plates
tower_plates:       resd MAX_ENTITIES   ; remaining plates (0-5)

; Damage event queue (for floating numbers and kill feed)
global dmg_queue, dmg_queue_count
%define DMG_QUEUE_MAX 64
dmg_queue:                              ; each entry: target(4), amount(4), type(4), x(4), y(4) = 20 bytes
    resb DMG_QUEUE_MAX * 20
dmg_queue_count: resd 1

; Random state for crit rolls
rand_state: resq 1

section .text

; ============================================================================
; combat_init - Initialize combat system
; ============================================================================
global combat_init
combat_init:
    ; Zero all combat arrays
    lea rdi, [rel ent_armor]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_mr]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_ap]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_crit_chance]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Set default crit multiplier to 175%
    lea rdi, [rel ent_crit_mult]
    mov eax, 175
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_lifesteal]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_cdr]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_tenacity]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_lethality]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_shield]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_shield_timer]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_kill_streak]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_death_streak]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_last_attacker]
    mov eax, -1
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel ent_assist_count]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel tower_plates]
    mov eax, TOWER_PLATES_COUNT
    mov ecx, MAX_ENTITIES
    rep stosd

    lea rdi, [rel tower_aggro_target]
    mov eax, -1
    mov ecx, MAX_ENTITIES
    rep stosd

    mov dword [dmg_queue_count], 0

    ; Init random state
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel rand_state]
    syscall

    ret

; ============================================================================
; combat_set_defenses - Set armor/MR for an entity
; edi = entity index, esi = armor, edx = mr
; ============================================================================
global combat_set_defenses
combat_set_defenses:
    lea rax, [rel ent_armor]
    mov [rax + rdi * 4], esi
    lea rax, [rel ent_mr]
    mov [rax + rdi * 4], edx
    ret

; ============================================================================
; combat_calc_damage - Calculate actual damage after defenses
; edi = raw_damage, esi = damage_type, edx = attacker_idx, ecx = target_idx
; Returns: eax = final damage
;
; Formula: damage * 100 / (100 + effective_defense)
; Physical: defense = armor - flat_pen - (armor * pct_pen / 100)
; Magic: defense = mr - flat_pen - (mr * pct_pen / 100)
; True: no reduction
; ============================================================================
global combat_calc_damage
combat_calc_damage:
    push rbx
    push r12
    push r13

    mov r12d, edi           ; raw damage
    mov r13d, ecx           ; target index
    mov ebx, edx            ; attacker index

    ; True damage - no reduction
    cmp esi, DMG_TRUE
    je .true_damage

    ; Get target's defense
    cmp esi, DMG_PHYSICAL
    je .physical

    ; Magic damage
    lea rax, [rel ent_mr]
    mov ecx, [rax + r13 * 4]    ; target MR

    ; Apply magic pen
    ; First % pen
    lea rax, [rel ent_magic_pen_pct]
    mov edx, [rax + rbx * 4]
    test edx, edx
    jz .no_mpct_pen
    mov eax, ecx
    imul eax, edx
    xor edx, edx
    mov edi, 100
    div edi
    sub ecx, eax            ; mr -= mr * pct / 100
.no_mpct_pen:
    ; Then flat pen
    lea rax, [rel ent_magic_pen_flat]
    sub ecx, [rax + rbx * 4]
    jmp .apply_defense

.physical:
    lea rax, [rel ent_armor]
    mov ecx, [rax + r13 * 4]    ; target armor

    ; Apply lethality (acts as flat armor pen)
    lea rax, [rel ent_lethality]
    sub ecx, [rax + rbx * 4]

    ; Apply % armor pen
    lea rax, [rel ent_armor_pen_pct]
    mov edx, [rax + rbx * 4]
    test edx, edx
    jz .apply_defense
    mov eax, ecx
    imul eax, edx
    xor edx, edx
    mov edi, 100
    div edi
    sub ecx, eax

.apply_defense:
    ; Clamp defense to minimum 0
    test ecx, ecx
    jns .def_positive
    xor ecx, ecx
.def_positive:
    ; damage = raw * 100 / (100 + defense)
    mov eax, r12d
    imul eax, 100
    add ecx, 100            ; 100 + defense
    xor edx, edx
    div ecx
    jmp .done

.true_damage:
    mov eax, r12d

.done:
    ; Minimum 1 damage (if raw > 0)
    test r12d, r12d
    jz .zero_dmg
    test eax, eax
    jnz .not_zero
    mov eax, 1
.not_zero:
.zero_dmg:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; combat_apply_damage - Apply damage to target with all combat mechanics
; edi = attacker_idx, esi = target_idx, edx = raw_damage, ecx = damage_type
; Returns: eax = actual damage dealt
; ============================================================================
global combat_apply_damage
combat_apply_damage:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi           ; attacker
    mov r13d, esi           ; target
    mov r14d, edx           ; raw damage
    mov r15d, ecx           ; damage type

    ; Check for critical strike (physical auto-attacks only)
    cmp r15d, DMG_PHYSICAL
    jne .no_crit

    ; Random roll for crit
    call .rand_0_100
    lea rcx, [rel ent_crit_chance]
    cmp eax, [rcx + r12 * 4]
    jge .no_crit

    ; Critical hit!
    lea rcx, [rel ent_crit_mult]
    mov eax, [rcx + r12 * 4]  ; crit multiplier (175 = 175%)
    imul eax, r14d
    xor edx, edx
    mov ecx, 100
    div ecx
    mov r14d, eax            ; boosted damage

.no_crit:
    ; Calculate damage after defenses
    mov edi, r14d
    mov esi, r15d
    mov edx, r12d
    mov ecx, r13d
    call combat_calc_damage
    mov r14d, eax            ; final damage

    ; Apply shield first
    lea rcx, [rel ent_shield]
    mov ebx, [rcx + r13 * 4]
    test ebx, ebx
    jz .no_shield

    cmp r14d, ebx
    jle .shield_absorbs
    ; Damage exceeds shield
    sub r14d, ebx
    mov dword [rcx + r13 * 4], 0
    jmp .apply_hp

.shield_absorbs:
    sub ebx, r14d
    mov [rcx + r13 * 4], ebx
    xor r14d, r14d          ; all damage absorbed
    jmp .post_damage

.no_shield:
.apply_hp:
    ; Apply damage to HP
    lea rcx, [rel ent_hp]
    sub [rcx + r13 * 4], r14d

    ; Track last attacker
    lea rcx, [rel ent_last_attacker]
    mov [rcx + r13 * 4], r12d

    ; Track assist (add attacker to target's assist list)
    call .track_assist

    ; Lifesteal (physical damage only)
    cmp r15d, DMG_PHYSICAL
    jne .no_lifesteal
    lea rcx, [rel ent_lifesteal]
    mov eax, [rcx + r12 * 4]
    test eax, eax
    jz .no_lifesteal
    imul eax, r14d
    xor edx, edx
    mov ecx, 100
    div ecx                 ; heal = damage * lifesteal% / 100
    lea rcx, [rel ent_hp]
    add [rcx + r12 * 4], eax
    ; Clamp to max HP
    mov edx, [rcx + r12 * 4]
    lea rcx, [rel ent_max_hp]
    cmp edx, [rcx + r12 * 4]
    jle .no_lifesteal
    lea rcx, [rel ent_hp]
    mov [rcx + r12 * 4], edx  ; clamp to max
.no_lifesteal:

    ; Check for kill
    lea rcx, [rel ent_hp]
    cmp dword [rcx + r13 * 4], 0
    jg .post_damage

    ; Target died
    mov dword [rcx + r13 * 4], 0

    ; Award gold and XP
    call .award_kill_rewards

    ; Kill the entity
    mov edi, r13d
    call entity_kill

.post_damage:
    ; Queue damage number for floating display
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    call .queue_damage_number

    mov eax, r14d            ; return actual damage
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Internal: track assist ---
.track_assist:
    push rax
    push rcx
    push rdx

    ; Add attacker to target's assist list (if not already there)
    lea rcx, [rel ent_assist_count]
    mov edx, [rcx + r13 * 4]
    cmp edx, 5
    jge .assist_full

    ; Check if already in list
    imul eax, r13d, 5
    lea rcx, [rel ent_assist_list]
    xor edi, edi
.assist_check:
    cmp edi, edx
    jge .assist_add
    lea r8, [rcx + rax * 4]
    cmp [r8 + rdi * 4], r12d
    je .assist_done
    inc edi
    jmp .assist_check

.assist_add:
    lea r8, [rcx + rax * 4]
    mov [r8 + rdx * 4], r12d
    lea rcx, [rel ent_assist_count]
    inc dword [rcx + r13 * 4]

.assist_full:
.assist_done:
    pop rdx
    pop rcx
    pop rax
    ret

; --- Internal: award kill gold/xp ---
.award_kill_rewards:
    push rax
    push rcx
    push rdx

    ; Determine gold reward based on target type
    lea rcx, [rel ent_type]
    movzx eax, byte [rcx + r13]

    cmp al, ENT_CHAMPION
    je .reward_champion
    cmp al, ENT_MINION_MELEE
    je .reward_minion_melee
    cmp al, ENT_MINION_CASTER
    je .reward_minion_caster
    cmp al, ENT_MINION_CANNON
    je .reward_minion_cannon
    cmp al, ENT_TOWER
    je .reward_tower
    cmp al, ENT_DRAGON
    je .reward_dragon
    cmp al, ENT_BARON
    je .reward_baron
    jmp .reward_done

.reward_champion:
    ; Base + bounty
    mov eax, BOUNTY_BASE
    ; Add kill streak bounty
    lea rcx, [rel ent_kill_streak]
    mov edx, [rcx + r13 * 4]
    imul edx, BOUNTY_PER_KILL
    add eax, edx
    cmp eax, BOUNTY_MAX
    jle .bounty_ok
    mov eax, BOUNTY_MAX
.bounty_ok:
    ; Award gold to killer
    lea rcx, [rel ent_gold]
    add [rcx + r12 * 4], eax

    ; Award assist gold
    call .award_assists

    ; Update streaks
    lea rcx, [rel ent_kill_streak]
    inc dword [rcx + r12 * 4]
    lea rcx, [rel ent_death_streak]
    inc dword [rcx + r13 * 4]
    mov dword [rcx + r12 * 4 - (ent_death_streak - ent_kill_streak)], 0  ; reset killer's death streak

    ; XP
    lea rcx, [rel ent_xp]
    add dword [rcx + r12 * 4], XP_PER_CHAMPION
    jmp .reward_done

.reward_minion_melee:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_MINION_MELEE
    lea rcx, [rel ent_xp]
    add dword [rcx + r12 * 4], XP_PER_MINION
    jmp .reward_done

.reward_minion_caster:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_MINION_CASTER
    lea rcx, [rel ent_xp]
    add dword [rcx + r12 * 4], XP_PER_MINION
    jmp .reward_done

.reward_minion_cannon:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_MINION_CANNON
    lea rcx, [rel ent_xp]
    add dword [rcx + r12 * 4], XP_PER_CANNON
    jmp .reward_done

.reward_tower:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_TOWER
    jmp .reward_done

.reward_dragon:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_DRAGON
    jmp .reward_done

.reward_baron:
    lea rcx, [rel ent_gold]
    add dword [rcx + r12 * 4], GOLD_PER_BARON
    jmp .reward_done

.reward_done:
    pop rdx
    pop rcx
    pop rax
    ret

; --- Internal: award assist gold ---
.award_assists:
    push rbx
    push r8

    lea rcx, [rel ent_assist_count]
    mov ebx, [rcx + r13 * 4]
    test ebx, ebx
    jz .assists_done

    ; assist_gold = kill_gold * ASSIST_GOLD_PCT / 100
    mov r8d, eax
    imul r8d, ASSIST_GOLD_PCT
    xor edx, edx
    push rax
    mov eax, r8d
    mov ecx, 100
    div ecx
    mov r8d, eax             ; assist gold per assister
    pop rax

    ; Award to each assister (except killer)
    imul edx, r13d, 5
    lea rcx, [rel ent_assist_list]
    xor edi, edi
.assist_loop:
    cmp edi, ebx
    jge .assists_done
    lea r8, [rcx + rdx * 4]
    mov esi, [r8 + rdi * 4]
    cmp esi, r12d           ; skip killer
    je .assist_next
    cmp esi, -1
    je .assist_next
    lea rax, [rel ent_gold]
    add [rax + rsi * 4], r8d
.assist_next:
    inc edi
    jmp .assist_loop

.assists_done:
    ; Clear assist list for target
    lea rcx, [rel ent_assist_count]
    mov dword [rcx + r13 * 4], 0

    pop r8
    pop rbx
    ret

; --- Internal: queue damage number ---
.queue_damage_number:
    push rax
    mov eax, [dmg_queue_count]
    cmp eax, DMG_QUEUE_MAX
    jge .queue_full

    ; Calculate entry offset
    imul ecx, eax, 20
    lea rax, [rel dmg_queue]

    ; Store: target, amount, type, x, y
    mov [rax + rcx], edi         ; target index
    mov [rax + rcx + 4], esi     ; damage amount
    mov [rax + rcx + 8], edx     ; damage type

    ; Get target screen position
    push rdx
    lea rdx, [rel ent_x]
    vcvttsd2si r8d, [rdx + rdi * 8]
    mov [rax + rcx + 12], r8d

    lea rdx, [rel ent_y]
    vcvttsd2si r8d, [rdx + rdi * 8]
    mov [rax + rcx + 16], r8d
    pop rdx

    inc dword [dmg_queue_count]
.queue_full:
    pop rax
    ret

; --- Internal: pseudo-random 0-99 ---
.rand_0_100:
    push rcx
    push rdx
    mov rax, [rand_state]
    mov rcx, 6364136223846793005
    imul rax, rcx
    add rax, 1442695040888963407
    mov [rand_state], rax
    shr rax, 33
    xor edx, edx
    mov ecx, 100
    div ecx
    mov eax, edx             ; remainder 0-99
    pop rdx
    pop rcx
    ret

; ============================================================================
; combat_update_shields - Tick shield timers
; ============================================================================
global combat_update_shields
combat_update_shields:
    push rbx
    mov ebx, [ent_count]
    xor ecx, ecx
.shield_loop:
    cmp ecx, ebx
    jge .shield_done

    lea rax, [rel ent_shield]
    cmp dword [rax + rcx * 4], 0
    je .shield_next

    lea rax, [rel ent_shield_timer]
    cmp dword [rax + rcx * 4], 0
    jle .expire_shield
    dec dword [rax + rcx * 4]
    jmp .shield_next

.expire_shield:
    lea rax, [rel ent_shield]
    mov dword [rax + rcx * 4], 0

.shield_next:
    inc ecx
    jmp .shield_loop

.shield_done:
    pop rbx
    ret

; ============================================================================
; combat_apply_shield - Give a shield to entity
; edi = entity_idx, esi = shield_amount, edx = duration_frames
; ============================================================================
global combat_apply_shield
combat_apply_shield:
    lea rax, [rel ent_shield]
    add [rax + rdi * 4], esi
    lea rax, [rel ent_shield_timer]
    mov [rax + rdi * 4], edx
    ret

; ============================================================================
; combat_tower_aggro - Update tower targeting with priority system
; Task 2.11: Turret aggro priority
; edi = tower_entity_idx
; ============================================================================
global combat_tower_aggro
combat_tower_aggro:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi           ; tower index

    ; Get tower team
    lea rax, [rel ent_team]
    movzx r13d, byte [rax + r12]    ; tower team

    ; Find best target: priority order: enemy minion > pet > champion
    mov r14d, -1            ; best target
    mov r15d, 0x7FFFFFFF    ; best distance
    xor ebx, ebx            ; best priority (lower = better)

    mov ecx, [ent_count]
    xor edx, edx

.aggro_loop:
    cmp edx, ecx
    jge .aggro_done

    lea rax, [rel ent_active]
    cmp byte [rax + rdx], 0
    je .aggro_next
    lea rax, [rel ent_state]
    cmp byte [rax + rdx], STATE_DEAD
    je .aggro_next

    ; Skip same team
    lea rax, [rel ent_team]
    cmp byte [rax + rdx], r13b
    je .aggro_next

    ; Get priority
    lea rax, [rel ent_type]
    movzx eax, byte [rax + rdx]
    mov esi, AGGRO_CHAMPION
    cmp al, ENT_CHAMPION
    je .got_prio
    mov esi, AGGRO_MINION
    cmp al, ENT_MINION_MELEE
    je .got_prio
    cmp al, ENT_MINION_CASTER
    je .got_prio
    cmp al, ENT_MINION_CANNON
    je .got_prio
    cmp al, ENT_MINION_SUPER
    je .got_prio
    jmp .aggro_next

.got_prio:
    ; Check range
    push rcx
    push rdx
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + r12 * 8]
    lea rcx, [rel ent_x]
    vcvttsd2si ecx, [rcx + rdx * 8]
    sub eax, ecx
    imul eax, eax
    push rax
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + r12 * 8]
    lea rcx, [rel ent_y]
    pop rdi
    vcvttsd2si ecx, [rcx + rdx * 8]
    sub eax, ecx
    imul eax, eax
    add eax, edi             ; dist^2
    pop rdx
    pop rcx

    ; Check if in tower range
    cmp eax, TOWER_RANGE * TOWER_RANGE
    jg .aggro_next

    ; Better priority? (lower number = higher priority)
    cmp esi, ebx
    jg .aggro_next           ; worse priority
    jl .update_target        ; better priority
    ; Same priority - take closer
    cmp eax, r15d
    jge .aggro_next

.update_target:
    mov r14d, edx
    mov r15d, eax
    mov ebx, esi

.aggro_next:
    inc edx
    jmp .aggro_loop

.aggro_done:
    ; Set tower's attack target
    lea rax, [rel ent_atk_target]
    mov [rax + r12 * 4], r14d

    cmp r14d, -1
    je .no_tower_attack
    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_ATTACKING
    jmp .tower_aggro_ret

.no_tower_attack:
    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_IDLE

.tower_aggro_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; combat_check_plate - Check/award tower plate gold
; Task 2.12: Tower plates
; edi = tower_idx, esi = attacker_idx
; ============================================================================
global combat_check_plate
combat_check_plate:
    push rbx

    ; Check remaining plates
    lea rax, [rel tower_plates]
    mov ebx, [rax + rdi * 4]
    test ebx, ebx
    jz .no_plate

    ; Check if HP crossed a plate threshold
    lea rax, [rel ent_hp]
    mov ecx, [rax + rdi * 4]
    lea rax, [rel ent_max_hp]
    mov edx, [rax + rdi * 4]

    ; Plate threshold = max_hp - plate_index * TOWER_PLATE_HP
    mov eax, TOWER_PLATES_COUNT
    sub eax, ebx
    inc eax
    imul eax, TOWER_PLATE_HP
    mov r8d, edx
    sub r8d, eax            ; threshold HP

    cmp ecx, r8d
    jge .no_plate            ; HP still above threshold

    ; Plate broken! Award gold
    lea rax, [rel tower_plates]
    dec dword [rax + rdi * 4]

    lea rax, [rel ent_gold]
    add dword [rax + rsi * 4], GOLD_PER_PLATE

.no_plate:
    pop rbx
    ret
