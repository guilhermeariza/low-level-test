; ============================================================================
; input.asm - X11 event processing (mouse, keyboard)
; Non-blocking event polling from X11 socket
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern x11_fd

section .data

section .bss

; Input state
global mouse_x, mouse_y, mouse_buttons
global key_state, key_pressed
global quit_flag
global mouse_clicked_left, mouse_clicked_right
global mouse_click_x, mouse_click_y

mouse_x:            resd 1      ; current mouse X on screen
mouse_y:            resd 1      ; current mouse Y on screen
mouse_buttons:      resd 1      ; bitmask of held buttons
mouse_clicked_left: resd 1      ; left click this frame (consumed after read)
mouse_clicked_right: resd 1     ; right click this frame
mouse_click_x:      resd 1      ; X position of last click
mouse_click_y:      resd 1      ; Y position of last click
key_state:          resb 256    ; key held state (indexed by X11 keycode)
key_pressed:        resb 256    ; key just pressed this frame
quit_flag:          resd 1      ; set to 1 to exit game

; Poll structure for non-blocking read
alignb 8
poll_fd:
    resd 1                  ; fd
    resw 1                  ; events
    resw 1                  ; revents

; Event buffer
alignb 64
event_buf:          resb 256    ; buffer for X11 events

section .text

; ============================================================================
; input_init - Initialize input state
; ============================================================================
global input_init
input_init:
    ; Clear all state
    xor eax, eax
    mov [mouse_x], eax
    mov [mouse_y], eax
    mov [mouse_buttons], eax
    mov [mouse_clicked_left], eax
    mov [mouse_clicked_right], eax
    mov [quit_flag], eax

    ; Clear key state
    lea rdi, [rel key_state]
    mov ecx, 64             ; 256 / 4
    rep stosd

    lea rdi, [rel key_pressed]
    mov ecx, 64
    rep stosd

    ret

; ============================================================================
; input_clear_frame - Clear per-frame input state (call at start of frame)
; ============================================================================
global input_clear_frame
input_clear_frame:
    mov dword [mouse_clicked_left], 0
    mov dword [mouse_clicked_right], 0

    ; Clear key_pressed array
    lea rdi, [rel key_pressed]
    xor eax, eax
    mov ecx, 64
    rep stosd

    ret

; ============================================================================
; input_poll - Poll and process all pending X11 events (non-blocking)
; ============================================================================
global input_poll
input_poll:
    push rbx
    push r12

.poll_loop:
    ; Setup poll structure
    mov eax, [x11_fd]
    lea rbx, [rel poll_fd]
    mov [rbx], eax           ; fd
    mov word [rbx + 4], POLLIN  ; events = POLLIN
    mov word [rbx + 6], 0    ; revents = 0

    ; poll(fds, 1, 0) - timeout 0 = non-blocking
    mov rax, SYS_POLL
    lea rdi, [rbx]
    mov rsi, 1               ; nfds = 1
    xor rdx, rdx             ; timeout = 0 (non-blocking)
    syscall

    ; Check if data available
    test eax, eax
    jle .poll_done           ; no events or error

    movzx eax, word [rbx + 6]  ; revents
    test eax, POLLIN
    jz .poll_done

    ; Read one event (32 bytes)
    mov rax, SYS_READ
    movsx rdi, dword [x11_fd]
    lea rsi, [rel event_buf]
    mov rdx, 32
    syscall

    cmp rax, 32
    jl .poll_done           ; incomplete event

    ; Process event
    lea r12, [rel event_buf]
    movzx eax, byte [r12]
    and al, 0x7F            ; mask high bit (send_event flag)

    ; Dispatch based on event type
    cmp al, EVENT_TYPE_MOTION
    je .handle_motion
    cmp al, EVENT_TYPE_BUTTON_PRESS
    je .handle_button_press
    cmp al, EVENT_TYPE_BUTTON_RELEASE
    je .handle_button_release
    cmp al, EVENT_TYPE_KEY_PRESS
    je .handle_key_press
    cmp al, EVENT_TYPE_KEY_RELEASE
    je .handle_key_release

    ; Unknown event, continue polling
    jmp .poll_loop

.handle_motion:
    ; MotionNotify: event_x at offset 24, event_y at offset 26
    movzx eax, word [r12 + 24]
    mov [mouse_x], eax
    movzx eax, word [r12 + 26]
    mov [mouse_y], eax
    jmp .poll_loop

.handle_button_press:
    ; ButtonPress: detail (button) at offset 1, event_x/y at 24/26
    movzx eax, byte [r12 + 1]  ; button number

    ; Update mouse position
    movzx ecx, word [r12 + 24]
    mov [mouse_x], ecx
    mov [mouse_click_x], ecx
    movzx ecx, word [r12 + 26]
    mov [mouse_y], ecx
    mov [mouse_click_y], ecx

    cmp al, MOUSE_LEFT
    je .btn_left
    cmp al, MOUSE_RIGHT
    je .btn_right
    jmp .poll_loop

.btn_left:
    or dword [mouse_buttons], 1
    mov dword [mouse_clicked_left], 1
    jmp .poll_loop

.btn_right:
    or dword [mouse_buttons], 2
    mov dword [mouse_clicked_right], 1
    jmp .poll_loop

.handle_button_release:
    movzx eax, byte [r12 + 1]
    cmp al, MOUSE_LEFT
    je .btn_rel_left
    cmp al, MOUSE_RIGHT
    je .btn_rel_right
    jmp .poll_loop

.btn_rel_left:
    and dword [mouse_buttons], ~1
    jmp .poll_loop

.btn_rel_right:
    and dword [mouse_buttons], ~2
    jmp .poll_loop

.handle_key_press:
    ; KeyPress: detail (keycode) at offset 1
    movzx eax, byte [r12 + 1]
    cmp eax, 255
    ja .poll_loop

    lea rbx, [rel key_state]
    mov byte [rbx + rax], 1
    lea rbx, [rel key_pressed]
    mov byte [rbx + rax], 1

    ; Check for quit (Escape or Q)
    cmp al, KEY_ESCAPE
    je .set_quit
    jmp .poll_loop

.set_quit:
    mov dword [quit_flag], 1
    jmp .poll_loop

.handle_key_release:
    movzx eax, byte [r12 + 1]
    cmp eax, 255
    ja .poll_loop
    lea rbx, [rel key_state]
    mov byte [rbx + rax], 0
    jmp .poll_loop

.poll_done:
    pop r12
    pop rbx
    ret
