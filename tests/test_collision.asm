; ============================================================================
; test_collision.asm - Unit tests for collision detection
; Tests: collision_check_point, collision_find_nearest
; Exit 0 = all tests pass, exit 1 = failure
; ============================================================================

%include "syscalls.inc"
%include "constants.inc"

extern entities_init, entity_spawn, entity_set_stats
extern collision_check_point, collision_find_nearest
extern ent_x, ent_y, ent_type, ent_team, ent_active, ent_state, ent_count

section .data

align 8
pos_100:  dq 100.0
pos_200:  dq 200.0
pos_500:  dq 500.0
pos_1000: dq 1000.0

msg_header: db "=== Collision Tests ===", 10
msg_header_len equ $ - msg_header

msg_t1:  db "  point hit on entity: ", 0
msg_t1_len equ $ - msg_t1
msg_t2:  db "  point miss (empty space): ", 0
msg_t2_len equ $ - msg_t2
msg_t3:  db "  find_nearest returns closest: ", 0
msg_t3_len equ $ - msg_t3
msg_t4:  db "  find_nearest no match (-1): ", 0
msg_t4_len equ $ - msg_t4

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

    ; Setup: create some entities
    call entities_init

    ; Entity 0: champion at (100, 200), blue team
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    movsd xmm0, [rel pos_100]
    movsd xmm1, [rel pos_200]
    call entity_spawn

    ; Entity 1: minion at (500, 200), red team
    mov edi, ENT_MINION_MELEE
    mov esi, TEAM_RED
    movsd xmm0, [rel pos_500]
    movsd xmm1, [rel pos_200]
    call entity_spawn

    ; Entity 2: tower at (1000, 1000), red team
    mov edi, ENT_TOWER
    mov esi, TEAM_RED
    movsd xmm0, [rel pos_1000]
    movsd xmm1, [rel pos_1000]
    call entity_spawn

    ; ========================================
    ; Test 1: collision_check_point hits entity 0
    ; ========================================
    lea rdi, [rel msg_t1]
    mov rsi, msg_t1_len
    call print_str

    mov edi, 100            ; x near entity 0
    mov esi, 200            ; y near entity 0
    call collision_check_point
    cmp eax, 0              ; should find entity 0
    jne .t1_fail
    call print_pass
    jmp .t2
.t1_fail:
    call print_fail

.t2:
    ; ========================================
    ; Test 2: collision_check_point misses in empty space
    ; ========================================
    lea rdi, [rel msg_t2]
    mov rsi, msg_t2_len
    call print_str

    mov edi, 3000           ; far from all entities
    mov esi, 3000
    call collision_check_point
    cmp eax, -1             ; should find nothing
    jne .t2_fail
    call print_pass
    jmp .t3
.t2_fail:
    call print_fail

.t3:
    ; ========================================
    ; Test 3: find_nearest finds closest red team entity
    ; ========================================
    lea rdi, [rel msg_t3]
    mov rsi, msg_t3_len
    call print_str

    ; From entity 0 (blue), find nearest red team
    mov edi, 0              ; source = entity 0
    mov esi, TEAM_RED       ; target team
    mov edx, 2000           ; max range
    call collision_find_nearest
    cmp eax, 1              ; should find entity 1 (closer than entity 2)
    jne .t3_fail
    call print_pass
    jmp .t4
.t3_fail:
    call print_fail

.t4:
    ; ========================================
    ; Test 4: find_nearest with no matching team
    ; ========================================
    lea rdi, [rel msg_t4]
    mov rsi, msg_t4_len
    call print_str

    ; From entity 1 (red), find nearest red team (same team = should find entity 2)
    mov edi, 1              ; source = entity 1
    mov esi, TEAM_BLUE      ; target = blue
    mov edx, 100            ; max range very small (entity 0 is at 400 away)
    call collision_find_nearest
    cmp eax, -1             ; should find nothing within range
    jne .t4_fail
    call print_pass
    jmp .done
.t4_fail:
    call print_fail

.done:
    mov rax, SYS_EXIT
    movsx rdi, dword [test_failures]
    syscall
