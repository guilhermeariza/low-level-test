; ============================================================================
; render.asm - High-performance rendering engine
; AVX2 optimized framebuffer operations
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern framebuffer
extern x11_shm_put_image

section .data

; 8x8 bitmap font for digits 0-9 and some chars
; Each character is 8 bytes (8 rows of 8 bits)
align 64
font_data:
; 0
db 0x3C, 0x66, 0x6E, 0x7E, 0x76, 0x66, 0x3C, 0x00
; 1
db 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
; 2
db 0x3C, 0x66, 0x06, 0x1C, 0x30, 0x60, 0x7E, 0x00
; 3
db 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00
; 4
db 0x0C, 0x1C, 0x3C, 0x6C, 0x7E, 0x0C, 0x0C, 0x00
; 5
db 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00
; 6
db 0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00
; 7
db 0x7E, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x18, 0x00
; 8
db 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00
; 9
db 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00
; A (10)
db 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
; B (11)
db 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00
; C (12)
db 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00
; D (13)
db 0x7C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x7C, 0x00
; E (14)
db 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00
; F (15)
db 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00
; G (16)
db 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3E, 0x00
; H (17)
db 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
; I (18)
db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
; K (19)
db 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00
; L (20)
db 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00
; M (21)
db 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00
; N (22)
db 0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66, 0x00
; P (23)
db 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00
; S (24)
db 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00
; T (25)
db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
; V (26)
db 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00
; W (27)
db 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00
; / (28)
db 0x02, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x40, 0x00
; : (29)
db 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00
; space (30)
db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
; + (31)
db 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00

; Character lookup table: ASCII -> font index
; Maps printable ASCII chars to font_data indices
align 64
char_map:
    times 48 db 30         ; 0-47: space
    db 0,1,2,3,4,5,6,7,8,9 ; 48-57: '0'-'9'
    db 29                   ; 58: ':'
    times 6 db 30          ; 59-64: space
    db 10,11,12,13,14,15,16,17,18 ; 65-73: A-I
    db 30                   ; 74: J (space)
    db 19                   ; 75: K
    db 20                   ; 76: L
    db 21                   ; 77: M
    db 22                   ; 78: N
    db 30                   ; 79: O (use 0)
    db 23                   ; 80: P
    db 30                   ; 81: Q
    db 30                   ; 82: R
    db 24                   ; 83: S
    db 25                   ; 84: T
    db 30                   ; 85: U
    db 26                   ; 86: V
    db 27                   ; 87: W
    times 170 db 30        ; rest: space

section .bss

section .text

; ============================================================================
; render_clear - Clear framebuffer with solid color
; edi = color (BGRA)
; Uses AVX2: 8 pixels per store = 32 bytes per iteration
; ============================================================================
global render_clear
render_clear:
    mov rsi, [framebuffer]
    test rsi, rsi
    jz .done

    ; Broadcast color to ymm0
    vmovd xmm0, edi
    vpbroadcastd ymm0, xmm0

    ; Total pixels = 1280 * 720 = 921600
    ; Iterations = 921600 / 8 = 115200
    mov ecx, (WINDOW_WIDTH * WINDOW_HEIGHT) / 8

    align 16
.loop:
    vmovdqu [rsi], ymm0
    add rsi, 32
    dec ecx
    jnz .loop

    vzeroupper
.done:
    ret

; ============================================================================
; render_rect - Draw filled rectangle
; edi = x, esi = y, edx = width, ecx = height, r8d = color
; Clipped to screen bounds
; ============================================================================
global render_rect
render_rect:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; Save params
    mov r12d, edi           ; x
    mov r13d, esi           ; y
    mov r14d, edx           ; width
    mov r15d, ecx           ; height
    mov ebp, r8d            ; color

    ; Clip to screen bounds
    ; Clip left
    test r12d, r12d
    jns .no_clip_left
    add r14d, r12d          ; width -= abs(x)
    xor r12d, r12d          ; x = 0
.no_clip_left:
    ; Clip top
    test r13d, r13d
    jns .no_clip_top
    add r15d, r13d
    xor r13d, r13d
.no_clip_top:
    ; Clip right
    mov eax, r12d
    add eax, r14d
    cmp eax, WINDOW_WIDTH
    jle .no_clip_right
    mov r14d, WINDOW_WIDTH
    sub r14d, r12d
.no_clip_right:
    ; Clip bottom
    mov eax, r13d
    add eax, r15d
    cmp eax, WINDOW_HEIGHT
    jle .no_clip_bottom
    mov r15d, WINDOW_HEIGHT
    sub r15d, r13d
.no_clip_bottom:

    ; Check if anything to draw
    test r14d, r14d
    jle .rect_done
    test r15d, r15d
    jle .rect_done

    ; Calculate starting framebuffer offset
    mov rax, [framebuffer]
    imul ebx, r13d, WINDOW_WIDTH
    add ebx, r12d
    shl ebx, 2
    add rax, rbx           ; rax = start pixel pointer

    ; Broadcast color for SIMD fill
    vmovd xmm0, ebp
    vpbroadcastd ymm0, xmm0

    mov ecx, r15d           ; row counter
.row_loop:
    ; Fill one row
    mov rdi, rax
    mov edx, r14d           ; pixels to fill

    ; AVX2 fill (8 pixels at a time)
.fill_8:
    cmp edx, 8
    jl .fill_1
    vmovdqu [rdi], ymm0
    add rdi, 32
    sub edx, 8
    jmp .fill_8

    ; Scalar fill for remainder
.fill_1:
    test edx, edx
    jz .row_done
    mov [rdi], ebp
    add rdi, 4
    dec edx
    jnz .fill_1

.row_done:
    add rax, WINDOW_WIDTH * 4   ; next row
    dec ecx
    jnz .row_loop

    vzeroupper

.rect_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_circle - Draw filled circle (for champions/entities)
; edi = center_x, esi = center_y, edx = radius, ecx = color
; Midpoint circle algorithm with horizontal line fills
; ============================================================================
global render_circle
render_circle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    mov r12d, edi           ; cx
    mov r13d, esi           ; cy
    mov r14d, edx           ; radius
    mov r15d, ecx           ; color

    ; Draw filled circle using horizontal scan lines
    ; For each y from -radius to +radius, calculate x extent
    mov ebp, r14d
    neg ebp                 ; y = -radius

.circle_y_loop:
    cmp ebp, r14d
    jg .circle_done

    ; Calculate x extent: x = sqrt(r^2 - y^2)
    mov eax, r14d
    imul eax, eax           ; r^2
    mov ecx, ebp
    imul ecx, ecx           ; y^2
    sub eax, ecx            ; r^2 - y^2
    js .circle_next_y       ; skip if negative (shouldn't happen)

    ; Integer sqrt using FPU
    cvtsi2sd xmm0, eax
    vsqrtsd xmm0, xmm0, xmm0
    cvttsd2si ebx, xmm0    ; ebx = x extent

    ; Draw horizontal line from (cx-x, cy+y) to (cx+x, cy+y)
    mov edi, r12d
    sub edi, ebx            ; x = cx - extent
    mov esi, r13d
    add esi, ebp            ; y = cy + y_offset
    lea edx, [ebx * 2 + 1] ; width = 2*extent + 1
    mov ecx, 1              ; height = 1
    mov r8d, r15d           ; color
    call render_rect

.circle_next_y:
    inc ebp
    jmp .circle_y_loop

.circle_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_char - Draw a single 8x8 character
; edi = x, esi = y, dl = ASCII char, ecx = color
; ============================================================================
global render_char
render_char:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi           ; x
    mov r13d, esi           ; y
    mov r14d, ecx           ; color

    ; Lookup character in font
    movzx eax, dl
    lea rbx, [rel char_map]
    movzx eax, byte [rbx + rax]
    ; eax = font index
    shl eax, 3              ; * 8 bytes per char
    lea rbx, [rel font_data]
    add rbx, rax            ; rbx = pointer to char bitmap

    ; Bounds check
    cmp r12d, WINDOW_WIDTH - 8
    jg .char_done
    cmp r13d, WINDOW_HEIGHT - 8
    jg .char_done
    cmp r12d, 0
    jl .char_done
    cmp r13d, 0
    jl .char_done

    ; Draw 8 rows
    mov rdi, [framebuffer]
    imul eax, r13d, WINDOW_WIDTH
    add eax, r12d
    shl eax, 2
    add rdi, rax            ; rdi = framebuffer at (x, y)

    mov ecx, 8              ; 8 rows
.char_row:
    movzx eax, byte [rbx]  ; get bitmap row
    inc rbx

    ; Draw 8 pixels from bitmap
    mov edx, 8
.char_pixel:
    test al, 0x80           ; check leftmost bit
    jz .char_skip
    mov [rdi], r14d         ; write pixel color
.char_skip:
    shl al, 1               ; next bit
    add rdi, 4              ; next pixel
    dec edx
    jnz .char_pixel

    ; Move to next row
    add rdi, (WINDOW_WIDTH - 8) * 4
    dec ecx
    jnz .char_row

.char_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_string - Draw a null-terminated string
; rdi = string ptr, esi = x, edx = y, ecx = color
; ============================================================================
global render_string
render_string:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi            ; string pointer
    mov r12d, esi           ; x
    mov r13d, edx           ; y
    mov r14d, ecx           ; color

.str_loop:
    movzx eax, byte [rbx]
    test al, al
    jz .str_done

    ; Draw character
    mov edi, r12d
    mov esi, r13d
    mov dl, al
    mov ecx, r14d
    call render_char

    add r12d, 8             ; advance x by 8 pixels (char width)
    inc rbx
    jmp .str_loop

.str_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_number - Draw an integer number
; edi = number, esi = x, edx = y, ecx = color
; ============================================================================
global render_number
render_number:
    push rbx
    push r12
    push r13
    push r14
    push rbp
    sub rsp, 16             ; local buffer for digits

    mov ebx, edi            ; number
    mov r12d, esi           ; x
    mov r13d, edx           ; y
    mov r14d, ecx           ; color

    ; Convert number to string (reversed)
    lea rbp, [rsp + 15]
    mov byte [rbp], 0       ; null terminator

    test ebx, ebx
    jnz .convert
    ; Handle zero
    dec rbp
    mov byte [rbp], '0'
    jmp .draw_num

.convert:
    ; Handle negative (shouldn't happen but safety)
    test ebx, ebx
    jns .conv_loop
    neg ebx

.conv_loop:
    test ebx, ebx
    jz .draw_num
    xor edx, edx
    mov eax, ebx
    mov ecx, 10
    div ecx                 ; eax = quotient, edx = remainder
    mov ebx, eax
    add dl, '0'
    dec rbp
    mov [rbp], dl
    jmp .conv_loop

.draw_num:
    mov rdi, rbp
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call render_string

    add rsp, 16
    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_hline - Draw horizontal line (1 pixel thick)
; edi = x, esi = y, edx = length, ecx = color
; ============================================================================
global render_hline
render_hline:
    ; Delegate to rect with height=1
    mov r8d, ecx            ; color
    mov ecx, 1              ; height = 1
    jmp render_rect          ; tail call

; ============================================================================
; render_vline - Draw vertical line (1 pixel thick)
; edi = x, esi = y, edx = height, ecx = color
; ============================================================================
global render_vline
render_vline:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi           ; x
    mov r13d, esi           ; y
    mov r14d, edx           ; height
    mov ebx, ecx            ; color

    ; Clip
    cmp r12d, 0
    jl .vline_done
    cmp r12d, WINDOW_WIDTH
    jge .vline_done
    cmp r13d, WINDOW_HEIGHT
    jge .vline_done
    test r14d, r14d
    jle .vline_done

    ; Clip top
    test r13d, r13d
    jns .vl_no_clip_top
    add r14d, r13d
    xor r13d, r13d
.vl_no_clip_top:
    ; Clip bottom
    mov eax, r13d
    add eax, r14d
    cmp eax, WINDOW_HEIGHT
    jle .vl_no_clip_bot
    mov r14d, WINDOW_HEIGHT
    sub r14d, r13d
.vl_no_clip_bot:

    ; Calculate start offset
    mov rax, [framebuffer]
    imul ecx, r13d, WINDOW_WIDTH
    add ecx, r12d
    shl ecx, 2
    add rax, rcx

    mov ecx, r14d
.vline_loop:
    mov [rax], ebx
    add rax, WINDOW_WIDTH * 4
    dec ecx
    jnz .vline_loop

.vline_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; render_flush - Send framebuffer to X11 display
; ============================================================================
global render_flush
render_flush:
    jmp x11_shm_put_image   ; tail call
