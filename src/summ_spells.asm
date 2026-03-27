; ============================================================================
; summ_spells.asm - Summoner spells system
; Tasks 7.01-7.10: Flash, Ignite, Heal, Teleport, Smite, Barrier, Exhaust,
;                  Ghost, Cleanse
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_hp, ent_max_hp, ent_mana
extern ent_speed, ent_state, ent_active, ent_team, ent_type
extern ent_count
extern math_distance

section .bss

alignb 64
global ent_summ1, ent_summ2, ent_summ1_cd, ent_summ2_cd

ent_summ1:      resd MAX_ENTITIES       ; summoner spell 1 ID per entity
ent_summ2:      resd MAX_ENTITIES       ; summoner spell 2 ID per entity
ent_summ1_cd:   resd MAX_ENTITIES       ; cooldown timer spell 1
ent_summ2_cd:   resd MAX_ENTITIES       ; cooldown timer spell 2

section .text

; ============================================================================
; summ_init - Zero all summoner spell arrays
; ============================================================================
global summ_init
summ_init:
    push rdi
    push rcx
    push rax

    ; Zero ent_summ1
    lea rdi, [rel ent_summ1]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Zero ent_summ2
    lea rdi, [rel ent_summ2]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Zero ent_summ1_cd
    lea rdi, [rel ent_summ1_cd]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    ; Zero ent_summ2_cd
    lea rdi, [rel ent_summ2_cd]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    pop rax
    pop rcx
    pop rdi
    ret

; ============================================================================
; summ_set - Set summoner spells for an entity
; edi = entity index, esi = spell1 ID, edx = spell2 ID
; ============================================================================
global summ_set
summ_set:
    movsxd rax, edi
    lea rcx, [rel ent_summ1]
    mov dword [rcx + rax*4], esi
    lea rcx, [rel ent_summ2]
    mov dword [rcx + rax*4], edx
    ret

; ============================================================================
; summ_cast - Cast a summoner spell
; edi = caster index, esi = slot (0=spell1, 1=spell2), edx = target index
; ============================================================================
global summ_cast
summ_cast:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 8                  ; align stack to 16 bytes

    movsxd r12, edi             ; r12 = caster index
    mov r13d, esi               ; r13 = slot
    movsxd r14, edx             ; r14 = target index

    ; Look up spell ID based on slot
    test r13d, r13d
    jnz .slot1

    lea rcx, [rel ent_summ1]
    mov eax, dword [rcx + r12*4]
    lea rcx, [rel ent_summ1_cd]
    mov ebx, dword [rcx + r12*4]
    jmp .check_cd

.slot1:
    lea rcx, [rel ent_summ2]
    mov eax, dword [rcx + r12*4]
    lea rcx, [rel ent_summ2_cd]
    mov ebx, dword [rcx + r12*4]

.check_cd:
    ; Check cooldown is 0
    test ebx, ebx
    jnz .done                   ; spell on cooldown, do nothing

    mov r15d, eax               ; r15 = spell ID

    ; Switch on spell ID
    cmp r15d, SUMM_FLASH
    je .do_flash
    cmp r15d, SUMM_IGNITE
    je .do_ignite
    cmp r15d, SUMM_HEAL
    je .do_heal
    cmp r15d, SUMM_TELEPORT
    je .do_teleport
    cmp r15d, SUMM_SMITE
    je .do_smite
    cmp r15d, SUMM_BARRIER
    je .do_barrier
    cmp r15d, SUMM_EXHAUST
    je .do_exhaust
    cmp r15d, SUMM_GHOST
    je .do_ghost
    cmp r15d, SUMM_CLEANSE
    je .do_cleanse
    jmp .done                   ; unknown spell ID

; --- FLASH (1): Teleport 400 pixels toward target position ---
.do_flash:
    ; Get caster position
    lea rcx, [rel ent_x]
    mov eax, dword [rcx + r12*4]
    mov edi, dword [rcx + r14*4]
    lea rcx, [rel ent_y]
    mov ebp, dword [rcx + r12*4]
    mov esi, dword [rcx + r14*4]

    ; Calculate delta
    sub edi, eax                ; dx = target_x - caster_x
    sub esi, ebp                ; dy = target_y - caster_y

    ; Convert to float for normalization
    cvtsi2sd xmm0, edi         ; xmm0 = dx (double)
    cvtsi2sd xmm1, esi         ; xmm1 = dy (double)

    ; distance = sqrt(dx*dx + dy*dy)
    movapd xmm2, xmm0
    mulsd xmm2, xmm2           ; dx*dx
    movapd xmm3, xmm1
    mulsd xmm3, xmm3           ; dy*dy
    addsd xmm2, xmm3           ; dx*dx + dy*dy
    sqrtsd xmm2, xmm2          ; dist

    ; Avoid divide by zero
    xorpd xmm4, xmm4
    ucomisd xmm2, xmm4
    je .flash_set_cd            ; zero distance, skip move

    ; If distance <= FLASH_RANGE, just teleport to target
    mov edi, FLASH_RANGE
    cvtsi2sd xmm4, edi
    ucomisd xmm2, xmm4
    jbe .flash_to_target

    ; Normalize and scale by FLASH_RANGE
    divsd xmm0, xmm2           ; dx / dist
    divsd xmm1, xmm2           ; dy / dist
    mulsd xmm0, xmm4           ; dx * FLASH_RANGE / dist
    mulsd xmm1, xmm4           ; dy * FLASH_RANGE / dist

    ; New position = caster + offset
    lea rcx, [rel ent_x]
    mov eax, dword [rcx + r12*4]
    cvtsi2sd xmm2, eax
    lea rcx, [rel ent_y]
    mov eax, dword [rcx + r12*4]
    cvtsi2sd xmm3, eax
    addsd xmm2, xmm0
    addsd xmm3, xmm1
    cvttsd2si eax, xmm2
    cvttsd2si ebx, xmm3
    lea rcx, [rel ent_x]
    mov dword [rcx + r12*4], eax
    lea rcx, [rel ent_y]
    mov dword [rcx + r12*4], ebx
    jmp .flash_set_cd

.flash_to_target:
    lea rcx, [rel ent_x]
    mov eax, dword [rcx + r14*4]
    mov dword [rcx + r12*4], eax
    lea rcx, [rel ent_y]
    mov eax, dword [rcx + r14*4]
    mov dword [rcx + r12*4], eax

.flash_set_cd:
    mov eax, FLASH_CD
    jmp .set_cd

; --- IGNITE (2): Instant damage to target ---
.do_ignite:
    lea rcx, [rel ent_hp]
    mov eax, dword [rcx + r14*4]
    sub eax, IGNITE_TOTAL_DMG
    mov dword [rcx + r14*4], eax
    mov eax, IGNITE_CD
    jmp .set_cd

; --- HEAL (3): Heal caster, cap at max HP ---
.do_heal:
    lea rcx, [rel ent_hp]
    mov eax, dword [rcx + r12*4]
    add eax, HEAL_AMOUNT
    lea rbx, [rel ent_max_hp]
    mov edx, dword [rbx + r12*4]
    cmp eax, edx
    cmovg eax, edx             ; cap at max_hp
    mov dword [rcx + r12*4], eax
    mov eax, HEAL_CD
    jmp .set_cd

; --- TELEPORT (4): Set caster position to target position ---
.do_teleport:
    lea rcx, [rel ent_x]
    mov eax, dword [rcx + r14*4]
    mov dword [rcx + r12*4], eax
    lea rcx, [rel ent_y]
    mov eax, dword [rcx + r14*4]
    mov dword [rcx + r12*4], eax
    mov eax, TELEPORT_CD
    jmp .set_cd

; --- SMITE (5): Deal SMITE_DMG to target ---
.do_smite:
    lea rcx, [rel ent_hp]
    mov eax, dword [rcx + r14*4]
    sub eax, SMITE_DMG
    mov dword [rcx + r14*4], eax
    mov eax, SMITE_CD
    jmp .set_cd

; --- BARRIER (6): Add shield HP (can exceed max) ---
.do_barrier:
    lea rcx, [rel ent_hp]
    mov eax, dword [rcx + r12*4]
    add eax, BARRIER_SHIELD
    mov dword [rcx + r12*4], eax
    mov eax, BARRIER_CD
    jmp .set_cd

; --- EXHAUST (7): Reduce target speed by EXHAUST_SLOW_PCT percent ---
.do_exhaust:
    lea rcx, [rel ent_speed]
    mov eax, dword [rcx + r14*4]
    mov ebx, eax                ; ebx = original speed
    imul eax, EXHAUST_SLOW_PCT  ; eax = speed * slow_pct
    cdq
    mov edi, 100
    idiv edi                    ; eax = (speed * slow_pct) / 100
    sub ebx, eax                ; new_speed = speed - reduction
    lea rcx, [rel ent_speed]
    mov dword [rcx + r14*4], ebx
    mov eax, EXHAUST_CD
    jmp .set_cd

; --- GHOST (8): Increase caster speed by GHOST_SPEED_PCT percent ---
.do_ghost:
    lea rcx, [rel ent_speed]
    mov eax, dword [rcx + r12*4]
    mov ebx, eax                ; ebx = original speed
    imul eax, GHOST_SPEED_PCT   ; eax = speed * pct
    cdq
    mov edi, 100
    idiv edi                    ; eax = (speed * pct) / 100
    add ebx, eax                ; new_speed = speed + bonus
    lea rcx, [rel ent_speed]
    mov dword [rcx + r12*4], ebx
    mov eax, GHOST_CD
    jmp .set_cd

; --- CLEANSE (9): Clear CC states ---
.do_cleanse:
    lea rcx, [rel ent_state]
    mov eax, dword [rcx + r12*4]
    cmp eax, STATE_STUNNED
    je .cleanse_clear
    cmp eax, STATE_ROOTED
    je .cleanse_clear
    cmp eax, STATE_SILENCED
    je .cleanse_clear
    jmp .cleanse_set_cd         ; not CC'd, just set cooldown

.cleanse_clear:
    lea rcx, [rel ent_state]
    mov dword [rcx + r12*4], STATE_IDLE

.cleanse_set_cd:
    mov eax, CLEANSE_CD
    jmp .set_cd

; --- Set cooldown for the appropriate slot ---
.set_cd:
    test r13d, r13d
    jnz .set_cd_slot1
    lea rcx, [rel ent_summ1_cd]
    mov dword [rcx + r12*4], eax
    jmp .done

.set_cd_slot1:
    lea rcx, [rel ent_summ2_cd]
    mov dword [rcx + r12*4], eax

.done:
    add rsp, 8
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; summ_tick_cooldowns - Decrement cooldowns each frame for all entities
; ============================================================================
global summ_tick_cooldowns
summ_tick_cooldowns:
    push rbx
    push r12
    push r13

    lea r12, [rel ent_summ1_cd]
    lea r13, [rel ent_summ2_cd]
    mov ecx, dword [rel ent_count]
    xor ebx, ebx               ; ebx = loop index

.tick_loop:
    cmp ebx, ecx
    jge .tick_done

    ; Decrement spell 1 cooldown if > 0
    mov eax, dword [r12 + rbx*4]
    test eax, eax
    jz .tick_s2
    dec eax
    mov dword [r12 + rbx*4], eax

.tick_s2:
    ; Decrement spell 2 cooldown if > 0
    mov eax, dword [r13 + rbx*4]
    test eax, eax
    jz .tick_next
    dec eax
    mov dword [r13 + rbx*4], eax

.tick_next:
    inc ebx
    jmp .tick_loop

.tick_done:
    pop r13
    pop r12
    pop rbx
    ret
