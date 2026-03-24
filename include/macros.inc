; ============================================================================
; macros.inc - Utility macros for SIMD operations and common patterns
; ============================================================================

%ifndef MACROS_INC
%define MACROS_INC

; Align data to N bytes
%macro ALIGNDATA 1
    align %1
%endmacro

; Push/pop multiple registers
%macro PUSHREGS 1-*
    %rep %0
        push %1
        %rotate 1
    %endrep
%endmacro

%macro POPREGS 1-*
    %rep %0
        %rotate -1
        pop %1
    %endrep
%endmacro

; Fast function prologue/epilogue (no frame pointer for speed)
%macro FUNC_START 0
%endmacro

%macro FUNC_END 0
    ret
%endmacro

; Broadcast a 32-bit color to YMM register (8 pixels)
%macro BROADCAST_COLOR_YMM 2    ; %1=ymm reg, %2=color value
    mov eax, %2
    vmovd xmm0, eax
    vpbroadcastd %1, xmm0
%endmacro

; Broadcast a 32-bit color to ZMM register (16 pixels) - AVX-512
%macro BROADCAST_COLOR_ZMM 2    ; %1=zmm reg, %2=color value
    mov eax, %2
    vmovd xmm0, eax
    vpbroadcastd %1, xmm0
%endmacro

; Fill memory with 32-bit value using AVX2 (256-bit, 8 pixels per iteration)
; %1=dest ptr reg, %2=ymm with color, %3=count in pixels (must be multiple of 8)
%macro FILL_PIXELS_YMM 3
    mov rcx, %3
    shr rcx, 3                  ; divide by 8
%%loop:
    vmovdqu [%1], %2
    add %1, 32
    dec rcx
    jnz %%loop
%endmacro

; Convert world coordinates to screen coordinates
; screen_x = world_x - camera_x
; screen_y = world_y - camera_y
%macro WORLD_TO_SCREEN 4    ; %1=out_x, %2=out_y, %3=world_x, %4=world_y
    mov %1, %3
    sub %1, [camera_x]
    mov %2, %4
    sub %2, [camera_y]
%endmacro

; Check if point is on screen
%macro POINT_ON_SCREEN 2    ; %1=screen_x, %2=screen_y (result in flags, jl=off)
    cmp %1, 0
    jl %%off
    cmp %1, WINDOW_WIDTH
    jge %%off
    cmp %2, 0
    jl %%off
    cmp %2, HUD_Y
    jge %%off
    stc     ; set carry = on screen
    jmp %%done
%%off:
    clc     ; clear carry = off screen
%%done:
%endmacro

; Clamp value to range [min, max]
%macro CLAMP 3  ; %1=value reg, %2=min, %3=max
    cmp %1, %2
    cmovl %1, %2
    cmp %1, %3
    cmovg %1, %3
%endmacro

; Min of two values
%macro MIN_REG 2    ; %1=dest/a, %2=b (result in %1)
    cmp %1, %2
    cmovg %1, %2
%endmacro

; Max of two values
%macro MAX_REG 2    ; %1=dest/a, %2=b (result in %1)
    cmp %1, %2
    cmovl %1, %2
%endmacro

; Calculate framebuffer offset: (y * WIDTH + x) * 4
%macro FB_OFFSET 3  ; %1=dest reg, %2=x reg/imm, %3=y reg
    imul %1, %3, WINDOW_WIDTH
    add %1, %2
    shl %1, 2       ; * 4 bytes per pixel
%endmacro

%endif
