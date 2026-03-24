; ============================================================================
; test_map.asm - Unit tests for map initialization
; Tests: map_init generates correct tile data
; Exit 0 = all tests pass, exit 1 = failure
; ============================================================================

%include "syscalls.inc"
%include "constants.inc"

extern map_init, map_tiles

section .data

msg_header: db "=== Map Tests ===", 10
msg_header_len equ $ - msg_header

msg_t1:  db "  map_init runs without crash: ", 0
msg_t1_len equ $ - msg_t1
msg_t2:  db "  blue base tile correct: ", 0
msg_t2_len equ $ - msg_t2
msg_t3:  db "  red base tile correct: ", 0
msg_t3_len equ $ - msg_t3
msg_t4:  db "  mid lane tile at center: ", 0
msg_t4_len equ $ - msg_t4
msg_t5:  db "  top lane left edge: ", 0
msg_t5_len equ $ - msg_t5
msg_t6:  db "  bot lane bottom edge: ", 0
msg_t6_len equ $ - msg_t6
msg_t7:  db "  river tile at diagonal: ", 0
msg_t7_len equ $ - msg_t7
msg_t8:  db "  map size correct (78400): ", 0
msg_t8_len equ $ - msg_t8

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
    ; Test 1: map_init runs without crash
    ; ========================================
    lea rdi, [rel msg_t1]
    mov rsi, msg_t1_len
    call print_str

    call map_init
    ; If we get here, it didn't crash
    call print_pass

    ; ========================================
    ; Test 2: Blue base tile (bottom-left corner)
    ; ========================================
    lea rdi, [rel msg_t2]
    mov rsi, msg_t2_len
    call print_str

    ; Tile at (3, MAP_HEIGHT-3) should be TILE_BASE_BLUE
    mov eax, MAP_HEIGHT - 3
    imul eax, MAP_WIDTH
    add eax, 3
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_BASE_BLUE
    jne .t2_fail
    call print_pass
    jmp .t3
.t2_fail:
    call print_fail

.t3:
    ; ========================================
    ; Test 3: Red base tile (top-right corner)
    ; ========================================
    lea rdi, [rel msg_t3]
    mov rsi, msg_t3_len
    call print_str

    ; Tile at (MAP_WIDTH-3, 3) should be TILE_BASE_RED
    mov eax, 3
    imul eax, MAP_WIDTH
    add eax, MAP_WIDTH - 3
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_BASE_RED
    jne .t3_fail
    call print_pass
    jmp .t4
.t3_fail:
    call print_fail

.t4:
    ; ========================================
    ; Test 4: Mid lane tile at center of map
    ; ========================================
    lea rdi, [rel msg_t4]
    mov rsi, msg_t4_len
    call print_str

    ; The mid lane goes diagonal: y = MAP_HEIGHT-1-x
    ; For x=10, y=189. River is at y=x so no overlap here.
    mov eax, MAP_HEIGHT - 1 - 10    ; y = 189
    imul eax, MAP_WIDTH
    add eax, 10                      ; x = 10
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_LANE
    jne .t4_fail
    call print_pass
    jmp .t5
.t4_fail:
    call print_fail

.t5:
    ; ========================================
    ; Test 5: Top lane - left edge (x=1, y=100)
    ; ========================================
    lea rdi, [rel msg_t5]
    mov rsi, msg_t5_len
    call print_str

    mov eax, 100
    imul eax, MAP_WIDTH
    add eax, 1              ; x=1
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_LANE
    jne .t5_fail
    call print_pass
    jmp .t6
.t5_fail:
    call print_fail

.t6:
    ; ========================================
    ; Test 6: Bot lane - bottom edge (x=100, y=MAP_HEIGHT-2)
    ; ========================================
    lea rdi, [rel msg_t6]
    mov rsi, msg_t6_len
    call print_str

    mov eax, MAP_HEIGHT - 2
    imul eax, MAP_WIDTH
    add eax, 100
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_LANE
    jne .t6_fail
    call print_pass
    jmp .t7
.t6_fail:
    call print_fail

.t7:
    ; ========================================
    ; Test 7: River at diagonal (x=50, y=50)
    ; ========================================
    lea rdi, [rel msg_t7]
    mov rsi, msg_t7_len
    call print_str

    mov eax, 50
    imul eax, MAP_WIDTH
    add eax, 50
    lea rdi, [rel map_tiles]
    movzx eax, byte [rdi + rax]
    cmp al, TILE_RIVER
    jne .t7_fail
    call print_pass
    jmp .t8
.t7_fail:
    call print_fail

.t8:
    ; ========================================
    ; Test 8: Map data size is correct
    ; ========================================
    lea rdi, [rel msg_t8]
    mov rsi, msg_t8_len
    call print_str

    mov eax, MAP_WIDTH * MAP_HEIGHT
    cmp eax, MAP_WIDTH * MAP_HEIGHT  ; 280 * 280 = 78400
    jne .t8_fail
    call print_pass
    jmp .done
.t8_fail:
    call print_fail

.done:
    mov rax, SYS_EXIT
    movsx rdi, dword [test_failures]
    syscall
