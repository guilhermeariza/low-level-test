; ============================================================================
; test_entities.asm - Unit tests for entity system
; Tests: init, spawn, set_stats, kill, deactivate
; Exit 0 = all tests pass, exit 1 = failure
; ============================================================================

%include "syscalls.inc"
%include "constants.inc"

extern entities_init, entity_spawn, entity_set_stats
extern entity_kill, entity_deactivate
extern ent_x, ent_y, ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_range, ent_speed, ent_atk_speed
extern ent_type, ent_team, ent_state, ent_active, ent_count
extern ent_atk_target, ent_gold, ent_level

section .data

align 8
spawn_x: dq 100.0
spawn_y: dq 200.0
spawn_x2: dq 500.0
spawn_y2: dq 600.0

msg_header: db "=== Entity Tests ===", 10
msg_header_len equ $ - msg_header

msg_t1:  db "  entities_init clears state: ", 0
msg_t1_len equ $ - msg_t1
msg_t2:  db "  entity_spawn returns 0: ", 0
msg_t2_len equ $ - msg_t2
msg_t3:  db "  spawn sets type/team: ", 0
msg_t3_len equ $ - msg_t3
msg_t4:  db "  spawn sets position: ", 0
msg_t4_len equ $ - msg_t4
msg_t5:  db "  entity_set_stats HP: ", 0
msg_t5_len equ $ - msg_t5
msg_t6:  db "  entity_set_stats ATK/range: ", 0
msg_t6_len equ $ - msg_t6
msg_t7:  db "  second spawn returns 1: ", 0
msg_t7_len equ $ - msg_t7
msg_t8:  db "  entity_kill sets DEAD: ", 0
msg_t8_len equ $ - msg_t8
msg_t9:  db "  entity_kill zeroes HP: ", 0
msg_t9_len equ $ - msg_t9
msg_t10: db "  entity_deactivate clears: ", 0
msg_t10_len equ $ - msg_t10
msg_t11: db "  spawn reuses deactivated slot: ", 0
msg_t11_len equ $ - msg_t11
msg_t12: db "  atk_target init to -1: ", 0
msg_t12_len equ $ - msg_t12

msg_pass: db "PASS", 10
msg_pass_len equ $ - msg_pass
msg_fail: db "FAIL", 10
msg_fail_len equ $ - msg_fail

section .bss

test_failures: resd 1

section .text

global _start

print_str:
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, 1
    mov rax, SYS_WRITE
    syscall
    ret

print_pass:
    lea rdi, [rel msg_pass]
    mov rsi, msg_pass_len
    jmp print_str

print_fail:
    inc dword [test_failures]
    lea rdi, [rel msg_fail]
    mov rsi, msg_fail_len
    jmp print_str

_start:
    mov dword [test_failures], 0

    lea rdi, [rel msg_header]
    mov rsi, msg_header_len
    call print_str

    ; ========================================
    ; Test 1: entities_init clears state
    ; ========================================
    lea rdi, [rel msg_t1]
    mov rsi, msg_t1_len
    call print_str

    call entities_init

    ; Check ent_count = 0
    cmp dword [ent_count], 0
    jne .t1_fail
    ; Check first active = 0
    lea rax, [rel ent_active]
    cmp byte [rax], 0
    jne .t1_fail
    call print_pass
    jmp .t2
.t1_fail:
    call print_fail

.t2:
    ; ========================================
    ; Test 2: entity_spawn returns 0 (first entity)
    ; ========================================
    lea rdi, [rel msg_t2]
    mov rsi, msg_t2_len
    call print_str

    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    movsd xmm0, [rel spawn_x]
    movsd xmm1, [rel spawn_y]
    call entity_spawn

    cmp eax, 0
    jne .t2_fail
    call print_pass
    jmp .t3
.t2_fail:
    call print_fail

.t3:
    ; ========================================
    ; Test 3: spawn sets type and team correctly
    ; ========================================
    lea rdi, [rel msg_t3]
    mov rsi, msg_t3_len
    call print_str

    lea rax, [rel ent_type]
    cmp byte [rax], ENT_CHAMPION
    jne .t3_fail
    lea rax, [rel ent_team]
    cmp byte [rax], TEAM_BLUE
    jne .t3_fail
    lea rax, [rel ent_active]
    cmp byte [rax], 1
    jne .t3_fail
    lea rax, [rel ent_state]
    cmp byte [rax], STATE_IDLE
    jne .t3_fail
    call print_pass
    jmp .t4
.t3_fail:
    call print_fail

.t4:
    ; ========================================
    ; Test 4: spawn sets position correctly
    ; ========================================
    lea rdi, [rel msg_t4]
    mov rsi, msg_t4_len
    call print_str

    lea rax, [rel ent_x]
    movsd xmm0, [rax]
    movsd xmm1, [rel spawn_x]
    vucomisd xmm0, xmm1
    jne .t4_fail

    lea rax, [rel ent_y]
    movsd xmm0, [rax]
    movsd xmm1, [rel spawn_y]
    vucomisd xmm0, xmm1
    jne .t4_fail

    call print_pass
    jmp .t5
.t4_fail:
    call print_fail

.t5:
    ; ========================================
    ; Test 5: entity_set_stats sets HP
    ; ========================================
    lea rdi, [rel msg_t5]
    mov rsi, msg_t5_len
    call print_str

    mov edi, 0              ; entity 0
    mov esi, 1000           ; hp
    mov edx, 500            ; mana
    mov ecx, 60             ; atk
    mov r8d, 125            ; range
    mov r9d, 330            ; speed
    push qword 100          ; atk_speed
    call entity_set_stats
    add rsp, 8

    lea rax, [rel ent_hp]
    cmp dword [rax], 1000
    jne .t5_fail
    lea rax, [rel ent_max_hp]
    cmp dword [rax], 1000
    jne .t5_fail
    lea rax, [rel ent_mana]
    cmp dword [rax], 500
    jne .t5_fail
    lea rax, [rel ent_max_mana]
    cmp dword [rax], 500
    jne .t5_fail
    call print_pass
    jmp .t6
.t5_fail:
    call print_fail

.t6:
    ; ========================================
    ; Test 6: entity_set_stats sets ATK, range, speed
    ; ========================================
    lea rdi, [rel msg_t6]
    mov rsi, msg_t6_len
    call print_str

    lea rax, [rel ent_atk]
    cmp dword [rax], 60
    jne .t6_fail
    lea rax, [rel ent_range]
    cmp dword [rax], 125
    jne .t6_fail
    lea rax, [rel ent_speed]
    cmp dword [rax], 330
    jne .t6_fail
    lea rax, [rel ent_atk_speed]
    cmp dword [rax], 100
    jne .t6_fail
    call print_pass
    jmp .t7
.t6_fail:
    call print_fail

.t7:
    ; ========================================
    ; Test 7: second spawn returns index 1
    ; ========================================
    lea rdi, [rel msg_t7]
    mov rsi, msg_t7_len
    call print_str

    mov edi, ENT_MINION_MELEE
    mov esi, TEAM_RED
    movsd xmm0, [rel spawn_x2]
    movsd xmm1, [rel spawn_y2]
    call entity_spawn

    cmp eax, 1
    jne .t7_fail
    cmp dword [ent_count], 2
    jne .t7_fail
    call print_pass
    jmp .t8
.t7_fail:
    call print_fail

.t8:
    ; ========================================
    ; Test 8: entity_kill sets state to DEAD
    ; ========================================
    lea rdi, [rel msg_t8]
    mov rsi, msg_t8_len
    call print_str

    mov edi, 1              ; kill entity 1
    call entity_kill

    lea rax, [rel ent_state]
    cmp byte [rax + 1], STATE_DEAD
    jne .t8_fail
    call print_pass
    jmp .t9
.t8_fail:
    call print_fail

.t9:
    ; ========================================
    ; Test 9: entity_kill zeroes HP
    ; ========================================
    lea rdi, [rel msg_t9]
    mov rsi, msg_t9_len
    call print_str

    lea rax, [rel ent_hp]
    cmp dword [rax + 4], 0      ; entity 1 HP
    jne .t9_fail
    call print_pass
    jmp .t10
.t9_fail:
    call print_fail

.t10:
    ; ========================================
    ; Test 10: entity_deactivate clears entity
    ; ========================================
    lea rdi, [rel msg_t10]
    mov rsi, msg_t10_len
    call print_str

    mov edi, 1
    call entity_deactivate

    lea rax, [rel ent_active]
    cmp byte [rax + 1], 0
    jne .t10_fail
    lea rax, [rel ent_type]
    cmp byte [rax + 1], ENT_NONE
    jne .t10_fail
    call print_pass
    jmp .t11
.t10_fail:
    call print_fail

.t11:
    ; ========================================
    ; Test 11: spawn reuses deactivated slot (index 1)
    ; ========================================
    lea rdi, [rel msg_t11]
    mov rsi, msg_t11_len
    call print_str

    mov edi, ENT_TOWER
    mov esi, TEAM_BLUE
    movsd xmm0, [rel spawn_x2]
    movsd xmm1, [rel spawn_y2]
    call entity_spawn

    cmp eax, 1              ; should reuse slot 1
    jne .t11_fail
    lea rax, [rel ent_active]
    cmp byte [rax + 1], 1
    jne .t11_fail
    lea rax, [rel ent_type]
    cmp byte [rax + 1], ENT_TOWER
    jne .t11_fail
    call print_pass
    jmp .t12
.t11_fail:
    call print_fail

.t12:
    ; ========================================
    ; Test 12: atk_target initialized to -1
    ; ========================================
    lea rdi, [rel msg_t12]
    mov rsi, msg_t12_len
    call print_str

    lea rax, [rel ent_atk_target]
    cmp dword [rax], -1         ; entity 0
    jne .t12_fail
    cmp dword [rax + 4], -1     ; entity 1
    jne .t12_fail
    call print_pass
    jmp .done
.t12_fail:
    call print_fail

.done:
    mov rax, SYS_EXIT
    movsx rdi, dword [test_failures]
    syscall
