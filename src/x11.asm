; ============================================================================
; x11.asm - Raw X11 protocol via Unix socket + MIT-SHM shared memory
; Zero-copy framebuffer rendering for maximum performance
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

section .data

x11_socket_path:
    dw AF_UNIX              ; sun_family
    db X11_SOCKET_PATH      ; sun_path
    times (SOCKADDR_UN_SIZE - 2 - X11_SOCKET_PATH_LEN) db 0

x11_conn_request:
    db X11_BYTE_ORDER_LSB   ; byte-order: LSB first
    db 0                    ; unused
    dw X11_PROTOCOL_MAJOR   ; protocol-major-version
    dw X11_PROTOCOL_MINOR   ; protocol-minor-version
    dw 0                    ; authorization-protocol-name length
    dw 0                    ; authorization-protocol-data length
    dw 0                    ; unused padding

shm_ext_name: db "MIT-SHM", 0
shm_ext_name_len equ 7

section .bss

; X11 connection state
global x11_fd
x11_fd:             resd 1          ; socket file descriptor
x11_rid_base:       resd 1          ; resource-id-base
x11_rid_mask:       resd 1          ; resource-id-mask
x11_rid_next:       resd 1          ; next resource id counter
x11_root_window:    resd 1          ; root window ID
x11_root_depth:     resb 1          ; root depth
x11_root_visual:    resd 1          ; root visual ID
x11_window_id:      resd 1          ; our window ID
x11_gc_id:          resd 1          ; graphics context ID
x11_shm_seg_id:     resd 1          ; SHM segment X11 ID
x11_sequence:       resd 1          ; current sequence number

; MIT-SHM
shm_major_opcode:   resb 1          ; MIT-SHM extension major opcode
shm_sysv_id:        resd 1          ; System V SHM ID
global framebuffer
framebuffer:        resq 1          ; pointer to shared memory framebuffer

; I/O buffer
alignb 64
x11_recv_buf:       resb 65536      ; receive buffer
x11_send_buf:       resb 4096       ; send buffer

section .text

; ============================================================================
; x11_alloc_id - Allocate a new X11 resource ID
; Returns: eax = new resource ID
; ============================================================================
x11_alloc_id:
    mov eax, [x11_rid_next]
    inc dword [x11_rid_next]
    and eax, [x11_rid_mask]
    or  eax, [x11_rid_base]
    ret

; ============================================================================
; x11_send - Send data to X server
; rdi = buffer ptr, rsi = length
; ============================================================================
x11_send:
    push rdi
    push rsi
    mov rdx, rsi            ; length
    mov rsi, rdi            ; buffer
    movsx rdi, dword [x11_fd]  ; fd
    mov rax, SYS_WRITE
    syscall
    inc dword [x11_sequence]
    pop rsi
    pop rdi
    ret

; ============================================================================
; x11_recv - Receive data from X server
; rdi = buffer ptr, rsi = max length
; Returns: rax = bytes read
; ============================================================================
x11_recv:
    mov rdx, rsi            ; max length
    mov rsi, rdi            ; buffer
    movsx rdi, dword [x11_fd]
    mov rax, SYS_READ
    syscall
    ret

; ============================================================================
; x11_recv_full - Receive exactly N bytes (blocking)
; rdi = buffer ptr, rsi = exact length needed
; ============================================================================
x11_recv_full:
    push rbx
    push r12
    push r13
    mov r12, rdi            ; buffer
    mov r13, rsi            ; total needed
    xor rbx, rbx            ; bytes received so far
.loop:
    lea rsi, [r12 + rbx]   ; current write position
    mov rdx, r13
    sub rdx, rbx            ; remaining bytes
    jz .done
    movsx rdi, dword [x11_fd]
    mov rax, SYS_READ
    syscall
    test rax, rax
    jle .done               ; error or EOF
    add rbx, rax
    cmp rbx, r13
    jl .loop
.done:
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; x11_init - Initialize X11 connection
; Opens socket, connects, creates window, sets up MIT-SHM
; Returns: 0 on success, -1 on failure
; ============================================================================
global x11_init
x11_init:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Initialize sequence counter
    mov dword [x11_sequence], 1

    ; --- Create Unix socket ---
    mov rax, SYS_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    test eax, eax
    js .fail
    mov [x11_fd], eax

    ; --- Connect to X server ---
    mov rax, SYS_CONNECT
    movsx rdi, dword [x11_fd]
    lea rsi, [rel x11_socket_path]
    mov rdx, SOCKADDR_UN_SIZE
    syscall
    test eax, eax
    js .fail

    ; --- Send connection request ---
    lea rdi, [rel x11_conn_request]
    mov rsi, 12
    call x11_send

    ; --- Receive connection reply ---
    ; First read 8 bytes to get header
    lea rdi, [rel x11_recv_buf]
    mov rsi, 8
    call x11_recv_full

    ; Check status byte
    lea r12, [rel x11_recv_buf]
    movzx eax, byte [r12]
    cmp al, 1              ; 1 = Success
    jne .fail

    ; Read additional length from bytes 6-7 (in 4-byte units)
    movzx eax, word [r12 + 6]
    shl eax, 2             ; convert to bytes
    mov r13d, eax          ; save additional data length

    ; Read the rest of the setup info
    lea rdi, [r12 + 8]
    mov rsi, r13
    call x11_recv_full

    ; Parse connection setup reply
    ; Offset 4-7 in additional data: resource-id-base
    mov eax, [r12 + 8 + 4]
    mov [x11_rid_base], eax
    ; Offset 8-11: resource-id-mask
    mov eax, [r12 + 8 + 8]
    mov [x11_rid_mask], eax

    mov dword [x11_rid_next], 1

    ; Find root window info
    ; Skip vendor and pixmap formats to get to screens
    ; Offset 16-17 in additional data: vendor length
    movzx eax, word [r12 + 8 + 16]
    mov r14d, eax           ; vendor length

    ; Offset 21: number of pixmap formats
    movzx ecx, byte [r12 + 8 + 21]
    imul ecx, 8            ; each format is 8 bytes

    ; Calculate offset to screen data
    ; Header (8) + fixed part (32) + vendor (padded to 4) + formats
    mov r15d, r14d
    add r15d, 3
    and r15d, ~3           ; pad vendor to multiple of 4
    add r15d, ecx          ; add formats size
    add r15d, 32           ; add fixed header size
    lea r15, [r12 + 8 + r15]  ; pointer to first screen

    ; Parse screen info
    ; Offset 0: root window
    mov eax, [r15]
    mov [x11_root_window], eax

    ; Offset 20: width in pixels (skip for now)
    ; Offset 22: height in pixels

    ; Offset 32: root-depth
    movzx eax, byte [r15 + 38]
    mov [x11_root_depth], al

    ; Offset 32: root-visual (need to find it)
    mov eax, [r15 + 32]
    mov [x11_root_visual], eax

    ; --- Query MIT-SHM extension ---
    call x11_query_shm_extension

    ; --- Setup MIT-SHM shared memory ---
    call x11_setup_shm

    ; --- Create window ---
    call x11_create_window

    ; --- Create GC ---
    call x11_create_gc

    ; --- Attach SHM to X server ---
    call x11_shm_attach

    ; --- Map window ---
    call x11_map_window

    ; --- Wait for MapNotify ---
    call x11_wait_map_notify

    xor eax, eax           ; success
    jmp .done

.fail:
    mov eax, -1
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; x11_query_shm_extension - Query MIT-SHM extension opcode
; ============================================================================
x11_query_shm_extension:
    push rbx
    lea rbx, [rel x11_send_buf]

    ; QueryExtension request
    mov byte [rbx], X11_QUERY_EXTENSION  ; opcode
    mov byte [rbx + 1], 0               ; unused
    mov word [rbx + 2], 5               ; request length in 4-byte units: (8 + 7 + pad) / 4 = 5
    mov word [rbx + 4], shm_ext_name_len ; name length = 7
    mov word [rbx + 6], 0               ; unused

    ; Copy extension name
    lea rsi, [rel shm_ext_name]
    lea rdi, [rbx + 8]
    mov ecx, shm_ext_name_len
    rep movsb
    ; Pad to 4-byte boundary
    mov byte [rbx + 15], 0

    lea rdi, [rbx]
    mov rsi, 20             ; 5 * 4 = 20 bytes
    call x11_send

    ; Read reply (32 bytes)
    lea rdi, [rel x11_recv_buf]
    mov rsi, 32
    call x11_recv_full

    ; Parse: byte 1 = reply type, byte 8 = present, byte 9 = major opcode
    lea rdi, [rel x11_recv_buf]
    movzx eax, byte [rdi + 9]  ; major opcode
    mov [shm_major_opcode], al

    pop rbx
    ret

; ============================================================================
; x11_setup_shm - Create System V shared memory segment
; ============================================================================
x11_setup_shm:
    ; shmget(IPC_PRIVATE, FRAMEBUFFER_SIZE, IPC_CREAT | 0600)
    mov rax, SYS_SHMGET
    mov rdi, IPC_PRIVATE
    mov rsi, FRAMEBUFFER_SIZE
    mov rdx, IPC_CREAT | SHM_R | SHM_W
    syscall
    test eax, eax
    js .shm_fail
    mov [shm_sysv_id], eax

    ; shmat(shmid, NULL, 0)
    mov rax, SYS_SHMAT
    movsx rdi, dword [shm_sysv_id]
    xor rsi, rsi            ; NULL = let kernel choose address
    xor rdx, rdx            ; flags = 0
    syscall
    cmp rax, -1
    je .shm_fail
    mov [framebuffer], rax

    ; Mark segment for deletion after last detach
    mov rax, SYS_SHMCTL
    movsx rdi, dword [shm_sysv_id]
    mov rsi, IPC_RMID
    xor rdx, rdx
    syscall

    ret
.shm_fail:
    ; Fall back - mmap anonymous memory (no SHM acceleration but still works)
    mov rax, SYS_MMAP
    xor rdi, rdi
    mov rsi, FRAMEBUFFER_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall
    mov [framebuffer], rax
    mov dword [shm_sysv_id], 0  ; mark as non-SHM
    ret

; ============================================================================
; x11_create_window - Create X11 window
; ============================================================================
x11_create_window:
    push rbx
    call x11_alloc_id
    mov [x11_window_id], eax
    mov r8d, eax            ; window id

    lea rbx, [rel x11_send_buf]

    ; CreateWindow request
    mov byte [rbx], X11_CREATE_WINDOW    ; opcode
    movzx eax, byte [x11_root_depth]
    mov byte [rbx + 1], al               ; depth
    mov word [rbx + 2], 12              ; request length (12 * 4 = 48 bytes)
    mov eax, [x11_window_id]
    mov [rbx + 4], eax                   ; window id
    mov eax, [x11_root_window]
    mov [rbx + 8], eax                   ; parent = root
    mov word [rbx + 12], 0              ; x
    mov word [rbx + 14], 0              ; y
    mov word [rbx + 16], WINDOW_WIDTH   ; width
    mov word [rbx + 18], WINDOW_HEIGHT  ; height
    mov word [rbx + 20], 0              ; border-width
    mov word [rbx + 22], INPUT_OUTPUT   ; class
    mov eax, [x11_root_visual]
    mov [rbx + 24], eax                  ; visual
    ; value-mask: BackPixel | EventMask
    mov dword [rbx + 28], CW_BACK_PIXEL | CW_EVENT_MASK
    ; BackPixel value
    mov dword [rbx + 32], COLOR_BLACK
    ; EventMask value
    mov dword [rbx + 36], EVENT_KEY_PRESS | EVENT_KEY_RELEASE | EVENT_BUTTON_PRESS | EVENT_BUTTON_RELEASE | EVENT_POINTER_MOTION | EVENT_EXPOSURE | EVENT_STRUCTURE_NOTIFY
    ; Pad remaining
    mov dword [rbx + 40], 0
    mov dword [rbx + 44], 0

    lea rdi, [rbx]
    mov rsi, 48
    call x11_send

    ; Set window title via ChangeProperty
    ; WM_NAME = "LoL Assembly"
    lea rbx, [rel x11_send_buf]
    mov byte [rbx], X11_CHANGE_PROPERTY  ; opcode
    mov byte [rbx + 1], 0               ; mode = Replace
    mov word [rbx + 2], 9               ; length = (24 + 12 + pad) / 4 = 9
    mov eax, [x11_window_id]
    mov [rbx + 4], eax                   ; window
    mov dword [rbx + 8], 39             ; property = WM_NAME (atom 39)
    mov dword [rbx + 12], 31            ; type = STRING (atom 31)
    mov byte [rbx + 16], 8              ; format = 8 (bytes)
    mov byte [rbx + 17], 0
    mov word [rbx + 18], 0
    mov dword [rbx + 20], 12            ; data length = 12 bytes

    ; "LoL Assembly"
    mov byte [rbx + 24], 'L'
    mov byte [rbx + 25], 'o'
    mov byte [rbx + 26], 'L'
    mov byte [rbx + 27], ' '
    mov byte [rbx + 28], 'A'
    mov byte [rbx + 29], 's'
    mov byte [rbx + 30], 's'
    mov byte [rbx + 31], 'e'
    mov byte [rbx + 32], 'm'
    mov byte [rbx + 33], 'b'
    mov byte [rbx + 34], 'l'
    mov byte [rbx + 35], 'y'

    lea rdi, [rbx]
    mov rsi, 36
    call x11_send

    pop rbx
    ret

; ============================================================================
; x11_create_gc - Create Graphics Context
; ============================================================================
x11_create_gc:
    push rbx
    call x11_alloc_id
    mov [x11_gc_id], eax

    lea rbx, [rel x11_send_buf]

    mov byte [rbx], X11_CREATE_GC       ; opcode
    mov byte [rbx + 1], 0
    mov word [rbx + 2], 5               ; length = 5 words (20 bytes)
    mov eax, [x11_gc_id]
    mov [rbx + 4], eax                   ; GC id
    mov eax, [x11_root_window]
    mov [rbx + 8], eax                   ; drawable = root
    mov dword [rbx + 12], GC_GRAPHICS_EXPOSURES ; value-mask
    mov dword [rbx + 16], 0             ; graphics-exposures = false

    lea rdi, [rbx]
    mov rsi, 20
    call x11_send

    pop rbx
    ret

; ============================================================================
; x11_shm_attach - Attach SHM segment to X server
; ============================================================================
x11_shm_attach:
    push rbx

    ; Allocate X11 SHM segment ID
    call x11_alloc_id
    mov [x11_shm_seg_id], eax

    ; Check if we have a real SHM segment
    cmp dword [shm_sysv_id], 0
    je .skip                ; no SHM, skip attach

    lea rbx, [rel x11_send_buf]

    movzx eax, byte [shm_major_opcode]
    mov byte [rbx], al                  ; MIT-SHM major opcode
    mov byte [rbx + 1], SHM_ATTACH      ; minor opcode
    mov word [rbx + 2], 4               ; length = 4 words
    mov eax, [x11_shm_seg_id]
    mov [rbx + 4], eax                   ; SHM segment ID
    mov eax, [shm_sysv_id]
    mov [rbx + 8], eax                   ; System V SHM ID
    mov byte [rbx + 12], 0              ; read-only = false
    mov byte [rbx + 13], 0
    mov word [rbx + 14], 0

    lea rdi, [rbx]
    mov rsi, 16
    call x11_send

.skip:
    pop rbx
    ret

; ============================================================================
; x11_map_window - Make window visible
; ============================================================================
x11_map_window:
    push rbx
    lea rbx, [rel x11_send_buf]

    mov byte [rbx], X11_MAP_WINDOW
    mov byte [rbx + 1], 0
    mov word [rbx + 2], 2               ; length = 2 words
    mov eax, [x11_window_id]
    mov [rbx + 4], eax

    lea rdi, [rbx]
    mov rsi, 8
    call x11_send

    pop rbx
    ret

; ============================================================================
; x11_wait_map_notify - Wait until window is mapped
; ============================================================================
x11_wait_map_notify:
    push rbx
.wait_loop:
    lea rdi, [rel x11_recv_buf]
    mov rsi, 32             ; X11 events are 32 bytes
    call x11_recv_full

    lea rdi, [rel x11_recv_buf]
    movzx eax, byte [rdi]
    and al, 0x7F            ; mask out high bit
    cmp al, EVENT_TYPE_MAP_NOTIFY
    je .done
    cmp al, EVENT_TYPE_EXPOSE
    je .done
    jmp .wait_loop
.done:
    pop rbx
    ret

; ============================================================================
; x11_shm_put_image - Blit framebuffer to window via MIT-SHM
; This is the main rendering flush - zero copy!
; ============================================================================
global x11_shm_put_image
x11_shm_put_image:
    push rbx

    ; Check if SHM is available
    cmp dword [shm_sysv_id], 0
    je .fallback_putimage

    lea rbx, [rel x11_send_buf]

    movzx eax, byte [shm_major_opcode]
    mov byte [rbx], al                   ; MIT-SHM major opcode
    mov byte [rbx + 1], SHM_PUT_IMAGE    ; minor opcode = PutImage
    mov word [rbx + 2], 10              ; length = 10 words (40 bytes)
    mov eax, [x11_window_id]
    mov [rbx + 4], eax                   ; drawable
    mov eax, [x11_gc_id]
    mov [rbx + 8], eax                   ; gc
    mov word [rbx + 12], WINDOW_WIDTH   ; total-width
    mov word [rbx + 14], WINDOW_HEIGHT  ; total-height
    mov word [rbx + 16], 0              ; src-x
    mov word [rbx + 18], 0              ; src-y
    mov word [rbx + 20], WINDOW_WIDTH   ; src-width
    mov word [rbx + 22], WINDOW_HEIGHT  ; src-height
    mov word [rbx + 24], 0              ; dst-x
    mov word [rbx + 26], 0              ; dst-y
    movzx eax, byte [x11_root_depth]
    mov byte [rbx + 28], al             ; depth
    mov byte [rbx + 29], ZIMAGE_FORMAT  ; format = ZPixmap
    mov byte [rbx + 30], 0              ; send-event
    mov byte [rbx + 31], 0              ; pad
    mov eax, [x11_shm_seg_id]
    mov [rbx + 32], eax                  ; SHM segment
    mov dword [rbx + 36], 0             ; offset = 0

    lea rdi, [rbx]
    mov rsi, 40
    call x11_send

    pop rbx
    ret

.fallback_putimage:
    ; Fallback: PutImage without SHM (slower but works)
    ; Send in chunks because X11 has request size limits
    call x11_putimage_chunked
    pop rbx
    ret

; ============================================================================
; x11_putimage_chunked - Fallback PutImage without SHM
; Sends the framebuffer in horizontal strips
; ============================================================================
x11_putimage_chunked:
    push rbx
    push r12
    push r13
    push r14

    ; Send 60 rows at a time (60 * 1280 * 4 = 307200 bytes per chunk)
    %define CHUNK_ROWS 60
    %define CHUNK_PIXELS (WINDOW_WIDTH * CHUNK_ROWS * BYTES_PER_PIXEL)
    %define PUTIMAGE_HDR 24

    xor r12d, r12d          ; current y offset
.chunk_loop:
    cmp r12d, WINDOW_HEIGHT
    jge .chunk_done

    ; Calculate rows for this chunk
    mov r13d, CHUNK_ROWS
    mov eax, WINDOW_HEIGHT
    sub eax, r12d
    cmp r13d, eax
    cmovg r13d, eax         ; min(CHUNK_ROWS, remaining)

    ; Calculate data size
    imul r14d, r13d, WINDOW_WIDTH * BYTES_PER_PIXEL

    ; Build PutImage header
    lea rbx, [rel x11_send_buf]
    mov byte [rbx], X11_PUT_IMAGE        ; opcode
    mov byte [rbx + 1], ZIMAGE_FORMAT    ; format = ZPixmap
    ; Request length in 4-byte units
    mov eax, r14d
    add eax, PUTIMAGE_HDR
    add eax, 3
    shr eax, 2
    mov [rbx + 2], ax                    ; length
    mov eax, [x11_window_id]
    mov [rbx + 4], eax                    ; drawable
    mov eax, [x11_gc_id]
    mov [rbx + 8], eax                    ; gc
    mov word [rbx + 12], WINDOW_WIDTH    ; width
    mov [rbx + 14], r13w                  ; height
    mov word [rbx + 16], 0               ; dst-x
    mov [rbx + 18], r12w                  ; dst-y
    mov byte [rbx + 20], 0               ; left-pad
    movzx eax, byte [x11_root_depth]
    mov byte [rbx + 21], al              ; depth
    mov word [rbx + 22], 0               ; padding

    ; Send header
    lea rdi, [rbx]
    mov rsi, PUTIMAGE_HDR
    call x11_send

    ; Send pixel data directly from framebuffer
    mov rax, [framebuffer]
    imul ecx, r12d, WINDOW_WIDTH * BYTES_PER_PIXEL
    lea rdi, [rax + rcx]
    movsx rsi, r14d
    ; Direct write syscall for pixel data (don't increment sequence)
    mov rdx, rsi
    mov rsi, rdi
    movsx rdi, dword [x11_fd]
    mov rax, SYS_WRITE
    syscall

    add r12d, r13d
    jmp .chunk_loop

.chunk_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; x11_cleanup - Clean up X11 resources
; ============================================================================
global x11_cleanup
x11_cleanup:
    ; Close socket
    mov rax, SYS_CLOSE
    movsx rdi, dword [x11_fd]
    syscall
    ret
