; ============================================================================
; math.asm - Fast math functions using SSE/AVX
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

section .data

align 16
one_double:     dq 1.0
sixty_inv:      dq 0.016666666666666666  ; 1/60 for per-frame scaling
half_double:    dq 0.5
zero_double:    dq 0.0
epsilon:        dq 0.001

section .text

; ============================================================================
; math_distance - Calculate distance between two points
; xmm0 = x1, xmm1 = y1, xmm2 = x2, xmm3 = y2
; Returns: xmm0 = distance
; ============================================================================
global math_distance
math_distance:
    vsubsd xmm0, xmm0, xmm2    ; dx = x1 - x2
    vsubsd xmm1, xmm1, xmm3    ; dy = y1 - y2
    vmulsd xmm0, xmm0, xmm0    ; dx^2
    vmulsd xmm1, xmm1, xmm1    ; dy^2
    vaddsd xmm0, xmm0, xmm1    ; dx^2 + dy^2
    vsqrtsd xmm0, xmm0, xmm0   ; sqrt
    ret

; ============================================================================
; math_distance_sq - Distance squared (faster, for comparisons)
; xmm0 = x1, xmm1 = y1, xmm2 = x2, xmm3 = y2
; Returns: xmm0 = distance^2
; ============================================================================
global math_distance_sq
math_distance_sq:
    vsubsd xmm0, xmm0, xmm2
    vsubsd xmm1, xmm1, xmm3
    vmulsd xmm0, xmm0, xmm0
    vmulsd xmm1, xmm1, xmm1
    vaddsd xmm0, xmm0, xmm1
    ret

; ============================================================================
; math_normalize - Normalize direction vector
; xmm0 = dx, xmm1 = dy
; Returns: xmm0 = normalized dx, xmm1 = normalized dy
; ============================================================================
global math_normalize
math_normalize:
    ; Calculate length
    vmulsd xmm2, xmm0, xmm0    ; dx^2
    vmulsd xmm3, xmm1, xmm1    ; dy^2
    vaddsd xmm2, xmm2, xmm3    ; length^2
    vsqrtsd xmm2, xmm2, xmm2   ; length

    ; Check for zero length
    vucomisd xmm2, [rel epsilon]
    jb .zero_vec

    ; Divide by length
    vdivsd xmm0, xmm0, xmm2
    vdivsd xmm1, xmm1, xmm2
    ret

.zero_vec:
    vxorpd xmm0, xmm0, xmm0
    vxorpd xmm1, xmm1, xmm1
    ret

; ============================================================================
; math_move_toward - Move point toward target at given speed
; xmm0 = current_x, xmm1 = current_y
; xmm2 = target_x, xmm3 = target_y
; xmm4 = speed (pixels per frame)
; Returns: xmm0 = new_x, xmm1 = new_y, eax = 1 if reached target
; ============================================================================
global math_move_toward
math_move_toward:
    ; Calculate direction
    vsubsd xmm5, xmm2, xmm0    ; dx = target_x - current_x
    vsubsd xmm6, xmm3, xmm1    ; dy = target_y - current_y

    ; Calculate distance
    vmulsd xmm7, xmm5, xmm5    ; dx^2
    vmulsd xmm8, xmm6, xmm6    ; dy^2
    vaddsd xmm7, xmm7, xmm8    ; dist^2
    vsqrtsd xmm7, xmm7, xmm7   ; dist

    ; Check if close enough to reach in this frame
    vucomisd xmm7, xmm4
    jbe .reached

    ; Normalize direction and apply speed
    vdivsd xmm5, xmm5, xmm7    ; dx / dist
    vdivsd xmm6, xmm6, xmm7    ; dy / dist
    vmulsd xmm5, xmm5, xmm4    ; dx * speed
    vmulsd xmm6, xmm6, xmm4    ; dy * speed

    vaddsd xmm0, xmm0, xmm5    ; new_x = current_x + dx * speed
    vaddsd xmm1, xmm1, xmm6    ; new_y = current_y + dy * speed
    xor eax, eax                ; not reached
    ret

.reached:
    vmovsd xmm0, xmm2, xmm2    ; new_x = target_x
    vmovsd xmm1, xmm3, xmm3    ; new_y = target_y
    mov eax, 1                  ; reached
    ret

; ============================================================================
; math_lerp - Linear interpolation
; xmm0 = a, xmm1 = b, xmm2 = t (0.0 to 1.0)
; Returns: xmm0 = a + (b - a) * t
; ============================================================================
global math_lerp
math_lerp:
    vsubsd xmm1, xmm1, xmm0    ; b - a
    vmulsd xmm1, xmm1, xmm2    ; (b - a) * t
    vaddsd xmm0, xmm0, xmm1    ; a + (b - a) * t
    ret

; ============================================================================
; math_clamp_double - Clamp double to [min, max]
; xmm0 = value, xmm1 = min, xmm2 = max
; Returns: xmm0 = clamped value
; ============================================================================
global math_clamp_double
math_clamp_double:
    vmaxsd xmm0, xmm0, xmm1    ; max(value, min)
    vminsd xmm0, xmm0, xmm2    ; min(result, max)
    ret

; ============================================================================
; math_int_to_double - Convert int to double
; edi = integer
; Returns: xmm0 = double
; ============================================================================
global math_int_to_double
math_int_to_double:
    vcvtsi2sd xmm0, xmm0, edi
    ret

; ============================================================================
; math_double_to_int - Convert double to int (truncate)
; xmm0 = double
; Returns: eax = integer
; ============================================================================
global math_double_to_int
math_double_to_int:
    vcvttsd2si eax, xmm0
    ret
