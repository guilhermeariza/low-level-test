; ============================================================================
; level.asm - Level/XP system + passive gold
; Tasks 1.03, 1.04: Level/XP system, passive gold generation
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_speed, ent_atk_speed
extern ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_xp, ent_count
extern ent_armor, ent_mr
extern game_frame

section .data

; XP required to reach each level (cumulative)
align 4
global xp_table
xp_table:
    dd 0        ; level 1 (start)
    dd 280      ; level 2
    dd 660      ; level 3
    dd 1140     ; level 4
    dd 1720     ; level 5
    dd 2400     ; level 6
    dd 3180     ; level 7
    dd 4060     ; level 8
    dd 5040     ; level 9
    dd 6120     ; level 10
    dd 7300     ; level 11
    dd 8580     ; level 12
    dd 9960     ; level 13
    dd 11440    ; level 14
    dd 13020    ; level 15
    dd 14700    ; level 16
    dd 16480    ; level 17
    dd 18360    ; level 18

section .bss

; Ability points available per entity
alignb 64
global ent_ability_points
ent_ability_points: resd MAX_ENTITIES

; Passive gold timer
global gold_timer
gold_timer: resd 1

section .text

; ============================================================================
; level_init - Initialize level system
; ============================================================================
global level_init
level_init:
    lea rdi, [rel ent_ability_points]
    xor eax, eax
    mov ecx, MAX_ENTITIES
    rep stosd

    mov dword [gold_timer], 0
    ret

; ============================================================================
; level_update - Check XP and level up entities, tick passive gold
; Called once per frame
; ============================================================================
global level_update
level_update:
    push rbx
    push r12
    push r13

    ; --- Passive gold generation ---
    inc dword [gold_timer]
    cmp dword [gold_timer], GOLD_PASSIVE_RATE
    jl .no_passive_gold

    mov dword [gold_timer], 0

    ; Give passive gold to all living champions
    mov r12d, [ent_count]
    xor ebx, ebx
.gold_loop:
    cmp ebx, r12d
    jge .no_passive_gold

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .gold_next
    lea rax, [rel ent_type]
    cmp byte [rax + rbx], ENT_CHAMPION
    jne .gold_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .gold_next

    lea rax, [rel ent_gold]
    add dword [rax + rbx * 4], GOLD_PASSIVE_AMOUNT

.gold_next:
    inc ebx
    jmp .gold_loop

.no_passive_gold:

    ; --- Level up check ---
    mov r12d, [ent_count]
    xor ebx, ebx

.level_loop:
    cmp ebx, r12d
    jge .level_done

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .level_next
    lea rax, [rel ent_type]
    cmp byte [rax + rbx], ENT_CHAMPION
    jne .level_next

    ; Get current level and XP
    lea rax, [rel ent_level]
    mov ecx, [rax + rbx * 4]       ; current level
    cmp ecx, MAX_LEVEL
    jge .level_next                 ; already max

    ; Check if XP exceeds threshold for next level
    lea rax, [rel ent_xp]
    mov edx, [rax + rbx * 4]       ; current XP

    lea rax, [rel xp_table]
    mov r13d, [rax + rcx * 4]      ; XP needed for next level

    cmp edx, r13d
    jl .level_next                  ; not enough XP

    ; LEVEL UP!
    lea rax, [rel ent_level]
    inc dword [rax + rbx * 4]

    ; Grant ability point
    lea rax, [rel ent_ability_points]
    inc dword [rax + rbx * 4]

    ; Increase stats per level
    ; HP
    lea rax, [rel ent_max_hp]
    add dword [rax + rbx * 4], CHAMPION_HP_LVL
    lea rax, [rel ent_hp]
    add dword [rax + rbx * 4], CHAMPION_HP_LVL  ; heal the bonus

    ; Mana
    lea rax, [rel ent_max_mana]
    add dword [rax + rbx * 4], CHAMPION_MANA_LVL
    lea rax, [rel ent_mana]
    add dword [rax + rbx * 4], CHAMPION_MANA_LVL

    ; AD
    lea rax, [rel ent_atk]
    add dword [rax + rbx * 4], CHAMPION_AD_LVL

    ; Armor
    lea rax, [rel ent_armor]
    add dword [rax + rbx * 4], CHAMPION_ARMOR_LVL

    ; MR
    lea rax, [rel ent_mr]
    add dword [rax + rbx * 4], CHAMPION_MR_LVL

    ; Attack speed
    lea rax, [rel ent_atk_speed]
    add dword [rax + rbx * 4], CHAMPION_ATK_SPD_LVL

    ; Check for another level up (in case of large XP gain)
    jmp .level_loop

.level_next:
    inc ebx
    jmp .level_loop

.level_done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; level_get_respawn_time - Calculate respawn time based on level
; edi = entity index
; Returns: eax = respawn time in frames
; ============================================================================
global level_get_respawn_time
level_get_respawn_time:
    lea rax, [rel ent_level]
    mov eax, [rax + rdi * 4]
    imul eax, CHAMPION_RESPAWN_LVL
    add eax, CHAMPION_RESPAWN_BASE
    ret
