; ============================================================================
; entities.asm - Entity Component System (Structure of Arrays)
; Cache-friendly SoA layout for SIMD batch processing
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

section .data

section .bss

; ============================================================================
; SoA Entity Arrays - all aligned to 64 bytes for AVX-512
; ============================================================================

; Position (double precision for smooth movement)
alignb 64
global ent_x, ent_y
ent_x:          resq MAX_ENTITIES       ; world X position (double)
ent_y:          resq MAX_ENTITIES       ; world Y position (double)

; Movement target
alignb 64
global ent_target_x, ent_target_y
ent_target_x:   resq MAX_ENTITIES       ; target X (double)
ent_target_y:   resq MAX_ENTITIES       ; target Y (double)

; Health
alignb 64
global ent_hp, ent_max_hp
ent_hp:         resd MAX_ENTITIES       ; current HP
ent_max_hp:     resd MAX_ENTITIES       ; max HP

; Mana
alignb 64
global ent_mana, ent_max_mana
ent_mana:       resd MAX_ENTITIES       ; current mana
ent_max_mana:   resd MAX_ENTITIES       ; max mana

; Combat stats
alignb 64
global ent_atk, ent_range, ent_speed, ent_atk_speed
ent_atk:        resd MAX_ENTITIES       ; attack damage
ent_range:      resd MAX_ENTITIES       ; attack range (pixels)
ent_speed:      resd MAX_ENTITIES       ; movement speed
ent_atk_speed:  resd MAX_ENTITIES       ; attack speed (100 = 1.0/sec)

; Attack cooldown
alignb 64
global ent_atk_cooldown
ent_atk_cooldown: resd MAX_ENTITIES     ; frames until next attack

; Attack target
alignb 64
global ent_atk_target
ent_atk_target: resd MAX_ENTITIES       ; entity index of attack target (-1 = none)

; Entity metadata
alignb 64
global ent_type, ent_team, ent_state, ent_active
ent_type:       resb MAX_ENTITIES       ; ENT_* type
ent_team:       resb MAX_ENTITIES       ; TEAM_* team
ent_state:      resb MAX_ENTITIES       ; STATE_* state
ent_active:     resb MAX_ENTITIES       ; 1 = active, 0 = inactive

; Respawn timer
alignb 64
global ent_respawn_timer
ent_respawn_timer: resd MAX_ENTITIES    ; frames until respawn

; Lane assignment (for minions)
alignb 64
global ent_lane, ent_waypoint_idx
ent_lane:       resb MAX_ENTITIES       ; 0=top, 1=mid, 2=bot
ent_waypoint_idx: resd MAX_ENTITIES     ; current waypoint index in lane path

; Gold and level (for champions)
alignb 64
global ent_gold, ent_level, ent_xp
ent_gold:       resd MAX_ENTITIES       ; gold amount
ent_level:      resd MAX_ENTITIES       ; level (1-18)
ent_xp:         resd MAX_ENTITIES       ; experience points

; Entity count
global ent_count
ent_count:      resd 1

section .text

; ============================================================================
; entities_init - Initialize entity system
; ============================================================================
global entities_init
entities_init:
    ; Zero all entity arrays
    xor eax, eax
    mov dword [ent_count], eax

    ; Clear active flags
    lea rdi, [rel ent_active]
    mov ecx, MAX_ENTITIES / 4
    rep stosd

    ; Clear types
    lea rdi, [rel ent_type]
    mov ecx, MAX_ENTITIES / 4
    rep stosd

    ; Clear states
    lea rdi, [rel ent_state]
    mov ecx, MAX_ENTITIES / 4
    rep stosd

    ; Set all attack targets to -1
    lea rdi, [rel ent_atk_target]
    mov eax, -1
    mov ecx, MAX_ENTITIES
    rep stosd

    ret

; ============================================================================
; entity_spawn - Create a new entity
; edi = type, esi = team, xmm0 = x (double), xmm1 = y (double)
; Returns: eax = entity index, -1 if full
; ============================================================================
global entity_spawn
entity_spawn:
    push rbx
    push r12
    push r13

    mov r12d, edi           ; type
    mov r13d, esi           ; team

    ; Find free slot
    xor ebx, ebx
.find_slot:
    cmp ebx, MAX_ENTITIES
    jge .spawn_full
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .found_slot
    inc ebx
    jmp .find_slot

.found_slot:
    ; Set basic properties
    lea rax, [rel ent_active]
    mov byte [rax + rbx], 1

    lea rax, [rel ent_type]
    mov byte [rax + rbx], r12b

    lea rax, [rel ent_team]
    mov byte [rax + rbx], r13b

    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_IDLE

    ; Set position
    lea rax, [rel ent_x]
    movsd [rax + rbx * 8], xmm0
    lea rax, [rel ent_target_x]
    movsd [rax + rbx * 8], xmm0

    lea rax, [rel ent_y]
    movsd [rax + rbx * 8], xmm1
    lea rax, [rel ent_target_y]
    movsd [rax + rbx * 8], xmm1

    ; Set attack target to none
    lea rax, [rel ent_atk_target]
    mov dword [rax + rbx * 4], -1

    ; Set cooldown to 0
    lea rax, [rel ent_atk_cooldown]
    mov dword [rax + rbx * 4], 0

    ; Set respawn timer to 0
    lea rax, [rel ent_respawn_timer]
    mov dword [rax + rbx * 4], 0

    ; Set waypoint to 0
    lea rax, [rel ent_waypoint_idx]
    mov dword [rax + rbx * 4], 0

    ; Initialize gold/level
    lea rax, [rel ent_gold]
    mov dword [rax + rbx * 4], 0
    lea rax, [rel ent_level]
    mov dword [rax + rbx * 4], 1
    lea rax, [rel ent_xp]
    mov dword [rax + rbx * 4], 0

    ; Update count
    mov eax, [ent_count]
    cmp ebx, eax
    jl .no_update_count
    lea eax, [ebx + 1]
    mov [ent_count], eax
.no_update_count:

    mov eax, ebx            ; return entity index
    pop r13
    pop r12
    pop rbx
    ret

.spawn_full:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; entity_set_stats - Set combat stats for entity
; edi = entity index, esi = hp, edx = mana, ecx = atk, r8d = range
; r9d = speed, [rsp+8] = atk_speed
; ============================================================================
global entity_set_stats
entity_set_stats:
    ; HP
    lea rax, [rel ent_hp]
    mov [rax + rdi * 4], esi
    lea rax, [rel ent_max_hp]
    mov [rax + rdi * 4], esi

    ; Mana
    lea rax, [rel ent_mana]
    mov [rax + rdi * 4], edx
    lea rax, [rel ent_max_mana]
    mov [rax + rdi * 4], edx

    ; Attack damage
    lea rax, [rel ent_atk]
    mov [rax + rdi * 4], ecx

    ; Range
    lea rax, [rel ent_range]
    mov [rax + rdi * 4], r8d

    ; Speed
    lea rax, [rel ent_speed]
    mov [rax + rdi * 4], r9d

    ; Attack speed from stack
    mov eax, [rsp + 8]
    lea rcx, [rel ent_atk_speed]
    mov [rcx + rdi * 4], eax

    ret

; ============================================================================
; entity_kill - Mark entity as dead
; edi = entity index
; ============================================================================
global entity_kill
entity_kill:
    lea rax, [rel ent_state]
    mov byte [rax + rdi], STATE_DEAD
    lea rax, [rel ent_hp]
    mov dword [rax + rdi * 4], 0
    ret

; ============================================================================
; entity_deactivate - Remove entity completely
; edi = entity index
; ============================================================================
global entity_deactivate
entity_deactivate:
    lea rax, [rel ent_active]
    mov byte [rax + rdi], 0
    lea rax, [rel ent_type]
    mov byte [rax + rdi], ENT_NONE
    ret
