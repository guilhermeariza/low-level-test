; ============================================================================
; abilities.asm - Ability/spell system (QWER)
; Tasks 3.01-3.12: Ability framework, targeting, projectiles, cooldowns
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_target_x, ent_target_y
extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_speed, ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_count
extern ent_armor, ent_mr, ent_ap, ent_cdr, ent_shield
extern combat_apply_damage, combat_apply_shield
extern entity_spawn, entity_kill
extern math_distance, math_normalize
extern ent_ability_points

section .data

; ============================================================================
; Champion ability definitions
; Each ability: mana_cost(4), cooldown_base(4), range(4), damage_base(4),
;               damage_per_rank(4), target_type(4), effect_type(4), radius(4)
;               = 32 bytes per ability
; Each champion has 5 abilities (passive + QWER) = 160 bytes
; ============================================================================

align 64
global champion_abilities
champion_abilities:

; --- CHAMP_GAREN (ID 1) ---
; Passive: Perseverance (regen when not in combat) - handled in code
    dd 0, 0, 0, 0, 0, TARGET_PASSIVE, 0, 0
; Q: Decisive Strike - speed boost + empowered auto
    dd 0, 480, 0, 30, 35, TARGET_SELF, 1, 0       ; no mana cost, 8s CD
; W: Courage - shield
    dd 0, 1440, 0, 0, 0, TARGET_SELF, 2, 0         ; 24s CD
; E: Judgment - spin AoE
    dd 0, 540, 325, 30, 20, TARGET_AUTO_AREA, 3, 325
; R: Demacian Justice - execute damage
    dd 100, 7200, 400, 150, 100, TARGET_POINT_CLICK, 4, 0  ; ult 120s

; --- CHAMP_ASHE (ID 2) ---
; Passive: Frost Shot - slows on hit
    dd 0, 0, 0, 0, 0, TARGET_PASSIVE, 10, 0
; Q: Ranger's Focus - attack speed steroid
    dd 50, 900, 0, 0, 0, TARGET_SELF, 11, 0
; W: Volley - skillshot cone
    dd 70, 840, 600, 20, 25, TARGET_CONE, 12, 400
; E: Hawkshot - vision reveal
    dd 0, 540, 2000, 0, 0, TARGET_SKILLSHOT, 13, 300
; R: Enchanted Crystal Arrow - global stun
    dd 100, 6000, 9999, 200, 100, TARGET_GLOBAL, 14, 100

; --- CHAMP_ANNIE (ID 3) ---
; Passive: Pyromania - stun every 4 spells
    dd 0, 0, 0, 0, 0, TARGET_PASSIVE, 20, 0
; Q: Disintegrate - point click damage
    dd 60, 240, 625, 80, 35, TARGET_POINT_CLICK, 21, 0
; W: Incinerate - cone AoE
    dd 70, 480, 600, 70, 30, TARGET_CONE, 22, 500
; E: Molten Shield - shield + speed
    dd 40, 600, 0, 0, 0, TARGET_SELF, 23, 0
; R: Summon Tibbers - large AoE
    dd 100, 7200, 600, 150, 100, TARGET_CIRCULAR_AOE, 24, 290

; --- CHAMP_ZED (ID 4) ---
; Passive: Contempt for the Weak - bonus damage below 50% hp
    dd 0, 0, 0, 0, 0, TARGET_PASSIVE, 30, 0
; Q: Razor Shuriken - line skillshot
    dd 75, 360, 900, 80, 30, TARGET_SKILLSHOT, 31, 0
; W: Living Shadow - shadow dash
    dd 40, 1200, 600, 0, 0, TARGET_SKILLSHOT, 32, 0
; E: Shadow Slash - AoE around self
    dd 50, 300, 290, 70, 20, TARGET_AUTO_AREA, 33, 290
; R: Death Mark - dash + mark
    dd 0, 7200, 625, 0, 0, TARGET_POINT_CLICK, 34, 0

; --- CHAMP_SORAKA (ID 5) ---
; Passive: Salvation - speed toward low HP allies
    dd 0, 0, 0, 0, 0, TARGET_PASSIVE, 40, 0
; Q: Starcall - ground AoE
    dd 60, 480, 800, 85, 35, TARGET_CIRCULAR_AOE, 41, 235
; W: Astral Infusion - heal ally (costs HP)
    dd 40, 240, 550, 80, 40, TARGET_POINT_CLICK, 42, 0
; E: Equinox - silence zone
    dd 70, 1200, 925, 70, 30, TARGET_CIRCULAR_AOE, 43, 260
; R: Wish - global heal
    dd 100, 9600, 9999, 150, 100, TARGET_GLOBAL, 44, 9999

; Padding for champions 6-10 (will be filled later)
times (NUM_CHAMPIONS - 5) * 5 * 32 db 0

section .bss

; Per-entity ability state
alignb 64
; Ability ranks (5 per entity: passive, Q, W, E, R)
global ent_ability_rank
ent_ability_rank:   resb MAX_ENTITIES * 5

; Ability cooldowns (5 per entity, in frames)
global ent_ability_cd
ent_ability_cd:     resd MAX_ENTITIES * 5

; Champion ID per entity
global ent_champion_id
ent_champion_id:    resd MAX_ENTITIES

; Passive counters (for Annie stun stacks, etc.)
global ent_passive_stacks
ent_passive_stacks: resd MAX_ENTITIES

; Summoner spell slots and cooldowns
global ent_summ_spell, ent_summ_cd
ent_summ_spell:     resb MAX_ENTITIES * 2   ; 2 spells per champion
ent_summ_cd:        resd MAX_ENTITIES * 2   ; cooldowns

; Buff/debuff system
global ent_buffs
; Each buff: type(1), duration(4), value(4), source(4) = 13 bytes, padded to 16
ent_buffs:          resb MAX_ENTITIES * MAX_BUFFS * 16

section .text

; ============================================================================
; abilities_init - Initialize ability system
; ============================================================================
global abilities_init
abilities_init:
    ; Clear all ability ranks
    lea rdi, [rel ent_ability_rank]
    xor eax, eax
    mov ecx, (MAX_ENTITIES * 5) / 4
    rep stosd

    ; Clear all ability cooldowns
    lea rdi, [rel ent_ability_cd]
    xor eax, eax
    mov ecx, MAX_ENTITIES * 5
    rep stosd

    ; Clear champion IDs
    lea rdi, [rel ent_champion_id]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Clear passive stacks
    lea rdi, [rel ent_passive_stacks]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Clear summoner spells
    lea rdi, [rel ent_summ_spell]
    xor eax, eax
    mov ecx, (MAX_ENTITIES * 2) / 4
    rep stosd

    lea rdi, [rel ent_summ_cd]
    xor eax, eax
    mov ecx, MAX_ENTITIES * 2
    rep stosd

    ; Clear buffs
    lea rdi, [rel ent_buffs]
    xor eax, eax
    mov ecx, (MAX_ENTITIES * MAX_BUFFS * 16) / 4
    rep stosd

    ret

; ============================================================================
; abilities_set_champion - Set champion type for entity
; edi = entity_idx, esi = champion_id
; ============================================================================
global abilities_set_champion
abilities_set_champion:
    lea rax, [rel ent_champion_id]
    mov [rax + rdi * 4], esi

    ; Give 1 ability point at level 1
    lea rax, [rel ent_ability_points]
    mov dword [rax + rdi * 4], ABILITY_POINTS_INIT
    ret

; ============================================================================
; abilities_set_summoners - Set summoner spells for entity
; edi = entity_idx, esi = spell1, edx = spell2
; ============================================================================
global abilities_set_summoners
abilities_set_summoners:
    lea rax, [rel ent_summ_spell]
    mov [rax + rdi * 2], sil
    mov [rax + rdi * 2 + 1], dl
    ret

; ============================================================================
; abilities_level_up - Level up an ability slot
; edi = entity_idx, esi = slot (1=Q, 2=W, 3=E, 4=R)
; Returns: eax = 1 success, 0 failure
; ============================================================================
global abilities_level_up
abilities_level_up:
    push rbx

    ; Check ability points available
    lea rax, [rel ent_ability_points]
    cmp dword [rax + rdi * 4], 0
    jle .levelup_fail

    ; Check max rank
    imul ebx, edi, 5
    add ebx, esi
    lea rax, [rel ent_ability_rank]
    movzx ecx, byte [rax + rbx]

    ; Ultimate (slot 4) max rank 3, others max 5
    cmp esi, SLOT_R
    je .check_ult_rank
    cmp ecx, ABILITY_MAX_RANK
    jge .levelup_fail
    jmp .do_levelup

.check_ult_rank:
    cmp ecx, ULTIMATE_MAX_RANK
    jge .levelup_fail
    ; Check level requirement for ult
    lea rax, [rel ent_level]
    mov edx, [rax + rdi * 4]
    cmp ecx, 0
    jne .check_ult_2
    cmp edx, ULT_UNLOCK_LVL
    jl .levelup_fail
    jmp .do_levelup
.check_ult_2:
    cmp ecx, 1
    jne .check_ult_3
    cmp edx, ULT_LVL_2
    jl .levelup_fail
    jmp .do_levelup
.check_ult_3:
    cmp edx, ULT_LVL_3
    jl .levelup_fail

.do_levelup:
    ; Increment rank
    lea rax, [rel ent_ability_rank]
    inc byte [rax + rbx]

    ; Consume ability point
    lea rax, [rel ent_ability_points]
    dec dword [rax + rdi * 4]

    mov eax, 1
    pop rbx
    ret

.levelup_fail:
    xor eax, eax
    pop rbx
    ret

; ============================================================================
; abilities_cast - Cast an ability
; edi = caster_idx, esi = slot (1-4 for QWER), edx = target_x, ecx = target_y
; Returns: eax = 1 success, 0 failure
; ============================================================================
global abilities_cast
abilities_cast:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi           ; caster
    mov r13d, esi           ; slot
    mov r14d, edx           ; target_x
    mov r15d, ecx           ; target_y

    ; Check if ability is ranked
    imul ebx, r12d, 5
    add ebx, r13d
    lea rax, [rel ent_ability_rank]
    movzx ecx, byte [rax + rbx]
    test ecx, ecx
    jz .cast_fail

    ; Check cooldown
    lea rax, [rel ent_ability_cd]
    cmp dword [rax + rbx * 4], 0
    jg .cast_fail

    ; Get ability definition
    lea rax, [rel ent_champion_id]
    mov eax, [rax + r12 * 4]
    test eax, eax
    jz .cast_fail

    ; Calculate ability data offset: (champ_id-1) * 5 * 32 + slot * 32
    dec eax
    imul eax, 5 * 32
    imul edx, r13d, 32
    add eax, edx
    lea rdi, [rel champion_abilities]
    add rdi, rax            ; rdi = pointer to ability data

    ; Check mana cost
    mov eax, [rdi]          ; mana_cost
    lea rcx, [rel ent_mana]
    cmp eax, [rcx + r12 * 4]
    jg .cast_fail            ; not enough mana

    ; Deduct mana
    sub [rcx + r12 * 4], eax

    ; Set cooldown (with CDR)
    mov eax, [rdi + 4]      ; base cooldown
    lea rcx, [rel ent_cdr]
    mov ecx, [rcx + r12 * 4]
    ; cd = base * (100 - cdr) / 100
    mov edx, 100
    sub edx, ecx
    imul eax, edx
    xor edx, edx
    mov ecx, 100
    div ecx

    ; Store cooldown
    imul ecx, r12d, 5
    add ecx, r13d
    lea rdx, [rel ent_ability_cd]
    mov [rdx + rcx * 4], eax

    ; Calculate damage
    mov eax, [rdi + 12]     ; damage_base
    mov ecx, [rdi + 16]     ; damage_per_rank

    ; Get rank
    imul edx, r12d, 5
    add edx, r13d
    lea r8, [rel ent_ability_rank]
    movzx edx, byte [r8 + rdx]
    dec edx                 ; rank 1 = base only
    imul ecx, edx           ; damage_per_rank * (rank - 1)
    add eax, ecx            ; total base damage

    ; Add AP scaling (simplified: +60% AP ratio)
    push rax
    lea rcx, [rel ent_ap]
    mov ecx, [rcx + r12 * 4]
    imul ecx, 60            ; 60% ratio
    xor edx, edx
    push rax
    mov eax, ecx
    mov ecx, 100
    div ecx
    mov ecx, eax
    pop rax
    pop rax
    add eax, ecx            ; total damage

    ; Store damage for later use
    mov ebx, eax

    ; Handle based on target type
    mov eax, [rdi + 20]     ; target_type

    cmp eax, TARGET_SELF
    je .cast_self
    cmp eax, TARGET_POINT_CLICK
    je .cast_point_click
    cmp eax, TARGET_SKILLSHOT
    je .cast_skillshot
    cmp eax, TARGET_CIRCULAR_AOE
    je .cast_aoe
    cmp eax, TARGET_CONE
    je .cast_cone
    cmp eax, TARGET_AUTO_AREA
    je .cast_auto_area
    cmp eax, TARGET_GLOBAL
    je .cast_global

    ; Default: success but no effect
    jmp .cast_success

.cast_self:
    ; Self-targeting ability (buffs, shields, steroids)
    ; Apply effect based on effect_type
    mov eax, [rdi + 24]     ; effect_type

    ; Garen W (effect 2): shield
    cmp eax, 2
    jne .self_not_shield
    mov edi, r12d
    mov esi, 100            ; shield amount
    mov edx, 150            ; 2.5 sec duration
    call combat_apply_shield
    jmp .cast_success

.self_not_shield:
    ; Generic self-buff: add speed buff
    ; (simplified: just apply a generic buff)
    jmp .cast_success

.cast_point_click:
    ; Find target entity at click position
    ; (simplified: damage first enemy near click)
    call .find_target_at_point
    cmp eax, -1
    je .cast_success         ; no target, still consume CD

    ; Apply damage
    mov edi, r12d           ; attacker
    mov esi, eax            ; target
    mov edx, ebx            ; damage
    mov ecx, DMG_MAGIC      ; most point-click = magic
    call combat_apply_damage
    jmp .cast_success

.cast_skillshot:
    ; Spawn a projectile entity traveling in direction
    mov edi, ENT_PROJECTILE
    lea rax, [rel ent_team]
    movzx esi, byte [rax + r12]

    lea rax, [rel ent_x]
    movsd xmm0, [rax + r12 * 8]     ; start at caster position
    lea rax, [rel ent_y]
    movsd xmm1, [rax + r12 * 8]
    call entity_spawn
    cmp eax, -1
    je .cast_success

    ; Set projectile target to mouse position
    vcvtsi2sd xmm0, xmm0, r14d
    lea rcx, [rel ent_target_x]
    movsd [rcx + rax * 8], xmm0

    vcvtsi2sd xmm0, xmm0, r15d
    lea rcx, [rel ent_target_y]
    movsd [rcx + rax * 8], xmm0

    lea rcx, [rel ent_state]
    mov byte [rcx + rax], STATE_MOVING

    lea rcx, [rel ent_speed]
    mov dword [rcx + rax * 4], 800   ; projectile speed

    lea rcx, [rel ent_atk]
    mov [rcx + rax * 4], ebx         ; projectile carries damage

    jmp .cast_success

.cast_aoe:
    ; Damage all enemies in radius around target point
    mov edi, [rdi + 28]     ; radius
    call .aoe_damage_at_point
    jmp .cast_success

.cast_cone:
    ; Simplified as AoE in front of caster
    mov edi, [rdi + 28]
    call .aoe_damage_at_point
    jmp .cast_success

.cast_auto_area:
    ; AoE around caster
    mov r14d, r12d          ; target = self position
    lea rax, [rel ent_x]
    vcvttsd2si r14d, [rax + r12 * 8]
    lea rax, [rel ent_y]
    vcvttsd2si r15d, [rax + r12 * 8]
    mov edi, [rdi + 28]     ; radius
    call .aoe_damage_at_point
    jmp .cast_success

.cast_global:
    ; Damage/heal all enemies/allies globally
    ; Simplified: apply to all enemies
    mov ecx, [ent_count]
    xor edx, edx
    lea rax, [rel ent_team]
    movzx r8d, byte [rax + r12]  ; caster team

.global_loop:
    cmp edx, ecx
    jge .cast_success
    cmp edx, r12d
    je .global_next

    lea rax, [rel ent_active]
    cmp byte [rax + rdx], 0
    je .global_next
    lea rax, [rel ent_state]
    cmp byte [rax + rdx], STATE_DEAD
    je .global_next

    lea rax, [rel ent_team]
    cmp byte [rax + rdx], r8b
    je .global_next          ; skip same team

    ; Apply damage
    push rcx
    push rdx
    mov edi, r12d
    mov esi, edx
    mov edx, ebx
    mov ecx, DMG_MAGIC
    call combat_apply_damage
    pop rdx
    pop rcx

.global_next:
    inc edx
    jmp .global_loop

.cast_success:
    mov eax, 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.cast_fail:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Internal: find enemy entity near (r14d, r15d) ---
.find_target_at_point:
    push rcx
    push rdx

    mov ecx, [ent_count]
    xor edx, edx
    lea rax, [rel ent_team]
    movzx r8d, byte [rax + r12]

.ftp_loop:
    cmp edx, ecx
    jge .ftp_none
    cmp edx, r12d
    je .ftp_next

    lea rax, [rel ent_active]
    cmp byte [rax + rdx], 0
    je .ftp_next
    lea rax, [rel ent_state]
    cmp byte [rax + rdx], STATE_DEAD
    je .ftp_next
    lea rax, [rel ent_team]
    cmp byte [rax + rdx], r8b
    je .ftp_next

    ; Check distance
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rdx * 8]
    sub eax, r14d
    imul eax, eax
    push rax
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + rdx * 8]
    sub eax, r15d
    imul eax, eax
    pop rdi
    add eax, edi

    cmp eax, 900            ; 30px radius
    jle .ftp_found

.ftp_next:
    inc edx
    jmp .ftp_loop

.ftp_found:
    mov eax, edx
    pop rdx
    pop rcx
    ret

.ftp_none:
    mov eax, -1
    pop rdx
    pop rcx
    ret

; --- Internal: AoE damage at (r14d, r15d) with radius edi ---
.aoe_damage_at_point:
    push rcx
    push rdx
    push r8
    push r9

    mov r9d, edi            ; radius
    imul r9d, r9d           ; radius^2

    mov ecx, [ent_count]
    xor edx, edx
    lea rax, [rel ent_team]
    movzx r8d, byte [rax + r12]

.aoe_loop:
    cmp edx, ecx
    jge .aoe_done
    cmp edx, r12d
    je .aoe_next

    lea rax, [rel ent_active]
    cmp byte [rax + rdx], 0
    je .aoe_next
    lea rax, [rel ent_state]
    cmp byte [rax + rdx], STATE_DEAD
    je .aoe_next
    lea rax, [rel ent_team]
    cmp byte [rax + rdx], r8b
    je .aoe_next

    ; Distance check
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rdx * 8]
    sub eax, r14d
    imul eax, eax
    push rax
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + rdx * 8]
    sub eax, r15d
    imul eax, eax
    pop rdi
    add eax, edi

    cmp eax, r9d
    jg .aoe_next

    ; Apply damage
    push rcx
    push rdx
    mov edi, r12d
    mov esi, edx
    mov edx, ebx            ; damage
    mov ecx, DMG_MAGIC
    call combat_apply_damage
    pop rdx
    pop rcx

.aoe_next:
    inc edx
    jmp .aoe_loop

.aoe_done:
    pop r9
    pop r8
    pop rdx
    pop rcx
    ret

; ============================================================================
; abilities_tick_cooldowns - Decrease all cooldowns by 1 per frame
; ============================================================================
global abilities_tick_cooldowns
abilities_tick_cooldowns:
    push rbx

    ; Ability cooldowns
    lea rdi, [rel ent_ability_cd]
    mov ecx, MAX_ENTITIES * 5
    xor ebx, ebx
.cd_loop:
    cmp ebx, ecx
    jge .cd_summ

    cmp dword [rdi + rbx * 4], 0
    jle .cd_next
    dec dword [rdi + rbx * 4]
.cd_next:
    inc ebx
    jmp .cd_loop

.cd_summ:
    ; Summoner spell cooldowns
    lea rdi, [rel ent_summ_cd]
    mov ecx, MAX_ENTITIES * 2
    xor ebx, ebx
.summ_cd_loop:
    cmp ebx, ecx
    jge .cd_done
    cmp dword [rdi + rbx * 4], 0
    jle .summ_cd_next
    dec dword [rdi + rbx * 4]
.summ_cd_next:
    inc ebx
    jmp .summ_cd_loop

.cd_done:
    ; Tick buffs
    call abilities_tick_buffs

    pop rbx
    ret

; ============================================================================
; abilities_tick_buffs - Decrease buff durations
; ============================================================================
abilities_tick_buffs:
    push rbx
    push r12

    mov r12d, [ent_count]
    xor ebx, ebx

.buff_ent_loop:
    cmp ebx, r12d
    jge .buff_done

    ; Process MAX_BUFFS per entity
    imul eax, ebx, MAX_BUFFS * 16
    lea rdi, [rel ent_buffs]
    add rdi, rax

    xor ecx, ecx
.buff_slot_loop:
    cmp ecx, MAX_BUFFS
    jge .buff_ent_next

    ; Check if buff active (type != 0)
    imul edx, ecx, 16
    cmp byte [rdi + rdx], BUFF_NONE
    je .buff_slot_next

    ; Decrease duration
    sub dword [rdi + rdx + 4], 1    ; duration field
    cmp dword [rdi + rdx + 4], 0
    jg .buff_slot_next

    ; Buff expired - clear it
    mov byte [rdi + rdx], BUFF_NONE

.buff_slot_next:
    inc ecx
    jmp .buff_slot_loop

.buff_ent_next:
    inc ebx
    jmp .buff_ent_loop

.buff_done:
    pop r12
    pop rbx
    ret

; ============================================================================
; abilities_add_buff - Add a buff to entity
; edi = entity, esi = buff_type, edx = duration, ecx = value, r8d = source
; ============================================================================
global abilities_add_buff
abilities_add_buff:
    push rbx

    ; Find empty buff slot
    imul eax, edi, MAX_BUFFS * 16
    lea rbx, [rel ent_buffs]
    add rbx, rax

    xor eax, eax
.find_slot:
    cmp eax, MAX_BUFFS
    jge .buff_full

    imul r9d, eax, 16
    cmp byte [rbx + r9], BUFF_NONE
    je .found_buff_slot
    inc eax
    jmp .find_slot

.found_buff_slot:
    mov byte [rbx + r9], sil        ; type
    mov [rbx + r9 + 4], edx         ; duration
    mov [rbx + r9 + 8], ecx         ; value
    mov [rbx + r9 + 12], r8d        ; source

.buff_full:
    pop rbx
    ret
