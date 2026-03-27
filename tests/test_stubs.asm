; ============================================================================
; test_stubs.asm - Stubs for symbols needed by test linking
; Provides dummy symbols that tests don't actually call
; ============================================================================

%include "constants.inc"

section .bss

; Camera stubs (needed by map.asm)
global camera_x, camera_y
camera_x:   resd 1
camera_y:   resd 1

; Framebuffer stub (needed by render.asm)
global framebuffer
framebuffer: resq 1

; X11 stubs (needed by render.asm / x11.asm)
global x11_fd
x11_fd:     resd 1

section .text

; x11_shm_put_image stub
global x11_shm_put_image
x11_shm_put_image:
    ret
