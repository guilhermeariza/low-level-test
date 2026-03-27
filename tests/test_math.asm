; ============================================================================
; test_math.asm - Unit tests for math functions
; Tests: distance, normalize, move_toward, int/double conversion
; Exit 0 = all tests pass, exit 1 = failure
; ============================================================================

%include "syscalls.inc"
%include "constants.inc"

extern math_distance, math_distance_sq, math_normalize
extern math_move_toward, math_lerp, math_clamp_double
extern math_int_to_double, math_double_to_int

section .data

align 8
; Test values
val_0:      dq 0.0
val_1:      dq 1.0
val_3:      dq 3.0
val_4:      dq 4.0
val_5:      dq 5.0
val_10:     dq 10.0
val_25:     dq 25.0
val_100:    dq 100.0
val_neg1:   dq -1.0
val_half:   dq 0.5
val_epsilon: dq 0.01

; Test result messages
msg_pass:   db "PASS", 10
msg_pass_len equ $ - msg_pass
msg_fail:   db "FAIL", 10
msg_fail_len equ $ - msg_fail

msg_test1:  db "  math_distance(3,4,0,0)=5: ", 0
msg_test1_len equ $ - msg_test1
msg_test2:  db "  math_distance_sq(3,4,0,0)=25: ", 0
msg_test2_len equ $ - msg_test2
msg_test3:  db "  math_normalize(3,4) unit: ", 0
msg_test3_len equ $ - msg_test3
msg_test4:  db "  math_move_toward reach: ", 0
msg_test4_len equ $ - msg_test4
msg_test5:  db "  math_move_toward partial: ", 0
msg_test5_len equ $ - msg_test5
msg_test6:  db "  math_int_to_double(42): ", 0
msg_test6_len equ $ - msg_test6
msg_test7:  db "  math_double_to_int(100.0): ", 0
msg_test7_len equ $ - msg_test7
msg_test8:  db "  math_lerp(0,10,0.5)=5: ", 0
msg_test8_len equ $ - msg_test8
msg_test9:  db "  math_clamp(50,0,10)=10: ", 0
msg_test9_len equ $ - msg_test9

msg_header: db "=== Math Tests ===", 10
msg_header_len equ $ - msg_header

section .bss

test_failures: resd 1

section .text

global _start

; Helper: print string at rdi, length rsi
print_str:
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, 1              ; stdout
    mov rax, SYS_WRITE
    syscall
    ret

; Helper: print PASS
print_pass:
    lea rdi, [rel msg_pass]
    mov rsi, msg_pass_len
    jmp print_str

; Helper: print FAIL and increment failure counter
print_fail:
    inc dword [test_failures]
    lea rdi, [rel msg_fail]
    mov rsi, msg_fail_len
    jmp print_str

; Helper: compare xmm0 to expected value [rdi] within epsilon
; Returns: eax = 1 if close enough, 0 otherwise
check_approx:
    movsd xmm1, [rdi]
    vsubsd xmm2, xmm0, xmm1
    ; abs(xmm2)
    vpand xmm2, xmm2, [rel abs_mask]
    vucomisd xmm2, [rel val_epsilon]
    jbe .approx_ok
    xor eax, eax
    ret
.approx_ok:
    mov eax, 1
    ret

align 16
abs_mask: dq 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF

_start:
    mov dword [test_failures], 0

    ; Print header
    lea rdi, [rel msg_header]
    mov rsi, msg_header_len
    call print_str

    ; ========================================
    ; Test 1: math_distance(3, 4, 0, 0) = 5
    ; ========================================
    lea rdi, [rel msg_test1]
    mov rsi, msg_test1_len
    call print_str

    movsd xmm0, [rel val_3]     ; x1 = 3
    movsd xmm1, [rel val_4]     ; y1 = 4
    movsd xmm2, [rel val_0]     ; x2 = 0
    movsd xmm3, [rel val_0]     ; y2 = 0
    call math_distance
    ; xmm0 should be 5.0
    lea rdi, [rel val_5]
    call check_approx
    test eax, eax
    jz .t1_fail
    call print_pass
    jmp .t2
.t1_fail:
    call print_fail

.t2:
    ; ========================================
    ; Test 2: math_distance_sq(3, 4, 0, 0) = 25
    ; ========================================
    lea rdi, [rel msg_test2]
    mov rsi, msg_test2_len
    call print_str

    movsd xmm0, [rel val_3]
    movsd xmm1, [rel val_4]
    movsd xmm2, [rel val_0]
    movsd xmm3, [rel val_0]
    call math_distance_sq
    lea rdi, [rel val_25]
    call check_approx
    test eax, eax
    jz .t2_fail
    call print_pass
    jmp .t3
.t2_fail:
    call print_fail

.t3:
    ; ========================================
    ; Test 3: math_normalize(3, 4) -> length = 1
    ; ========================================
    lea rdi, [rel msg_test3]
    mov rsi, msg_test3_len
    call print_str

    movsd xmm0, [rel val_3]
    movsd xmm1, [rel val_4]
    call math_normalize
    ; Check length of result = 1.0
    vmulsd xmm2, xmm0, xmm0    ; dx^2
    vmulsd xmm3, xmm1, xmm1    ; dy^2
    vaddsd xmm0, xmm2, xmm3    ; length^2
    vsqrtsd xmm0, xmm0, xmm0    ; length
    lea rdi, [rel val_1]
    call check_approx
    test eax, eax
    jz .t3_fail
    call print_pass
    jmp .t4
.t3_fail:
    call print_fail

.t4:
    ; ========================================
    ; Test 4: math_move_toward reaches target when close
    ; ========================================
    lea rdi, [rel msg_test4]
    mov rsi, msg_test4_len
    call print_str

    movsd xmm0, [rel val_0]     ; current_x = 0
    movsd xmm1, [rel val_0]     ; current_y = 0
    movsd xmm2, [rel val_1]     ; target_x = 1
    movsd xmm3, [rel val_0]     ; target_y = 0
    movsd xmm4, [rel val_10]    ; speed = 10 (bigger than distance)
    call math_move_toward
    ; eax should be 1 (reached), xmm0 should be 1.0
    cmp eax, 1
    jne .t4_fail
    lea rdi, [rel val_1]
    call check_approx
    test eax, eax
    jz .t4_fail
    call print_pass
    jmp .t5
.t4_fail:
    call print_fail

.t5:
    ; ========================================
    ; Test 5: math_move_toward partial movement
    ; ========================================
    lea rdi, [rel msg_test5]
    mov rsi, msg_test5_len
    call print_str

    movsd xmm0, [rel val_0]     ; current_x = 0
    movsd xmm1, [rel val_0]     ; current_y = 0
    movsd xmm2, [rel val_100]   ; target_x = 100
    movsd xmm3, [rel val_0]     ; target_y = 0
    movsd xmm4, [rel val_5]     ; speed = 5
    call math_move_toward
    ; eax should be 0 (not reached), xmm0 should be 5.0
    cmp eax, 0
    jne .t5_fail
    lea rdi, [rel val_5]
    call check_approx
    test eax, eax
    jz .t5_fail
    call print_pass
    jmp .t6
.t5_fail:
    call print_fail

.t6:
    ; ========================================
    ; Test 6: math_int_to_double(42) = 42.0
    ; ========================================
    lea rdi, [rel msg_test6]
    mov rsi, msg_test6_len
    call print_str

    mov edi, 42
    call math_int_to_double
    ; xmm0 should be 42.0
    mov eax, 42
    vcvtsi2sd xmm1, xmm1, eax
    vsubsd xmm2, xmm0, xmm1
    vpand xmm2, xmm2, [rel abs_mask]
    vucomisd xmm2, [rel val_epsilon]
    ja .t6_fail
    call print_pass
    jmp .t7
.t6_fail:
    call print_fail

.t7:
    ; ========================================
    ; Test 7: math_double_to_int(100.0) = 100
    ; ========================================
    lea rdi, [rel msg_test7]
    mov rsi, msg_test7_len
    call print_str

    movsd xmm0, [rel val_100]
    call math_double_to_int
    cmp eax, 100
    jne .t7_fail
    call print_pass
    jmp .t8
.t7_fail:
    call print_fail

.t8:
    ; ========================================
    ; Test 8: math_lerp(0, 10, 0.5) = 5
    ; ========================================
    lea rdi, [rel msg_test8]
    mov rsi, msg_test8_len
    call print_str

    movsd xmm0, [rel val_0]     ; a = 0
    movsd xmm1, [rel val_10]    ; b = 10
    movsd xmm2, [rel val_half]  ; t = 0.5
    call math_lerp
    lea rdi, [rel val_5]
    call check_approx
    test eax, eax
    jz .t8_fail
    call print_pass
    jmp .t9
.t8_fail:
    call print_fail

.t9:
    ; ========================================
    ; Test 9: math_clamp(50, 0, 10) = 10
    ; ========================================
    lea rdi, [rel msg_test9]
    mov rsi, msg_test9_len
    call print_str

    mov eax, 50
    vcvtsi2sd xmm0, xmm0, eax   ; value = 50.0
    movsd xmm1, [rel val_0]     ; min = 0
    movsd xmm2, [rel val_10]    ; max = 10
    call math_clamp_double
    lea rdi, [rel val_10]
    call check_approx
    test eax, eax
    jz .t9_fail
    call print_pass
    jmp .done
.t9_fail:
    call print_fail

.done:
    ; Exit with failure count
    mov rax, SYS_EXIT
    movsx rdi, dword [test_failures]
    syscall
