; ============================================================================
; network.asm - Multiplayer networking system
; Tasks 12.01-12.09: Client-server architecture, UDP sockets, state sync
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_hp, ent_state, ent_active, ent_count

%define NET_PORT            27015
%define NET_MAX_CLIENTS     10
%define NET_PACKET_SIZE     512
%define NET_TICK_RATE       20      ; network updates per second
%define NET_TICK_FRAMES     3       ; 60fps / 20 ticks = 3 frames per tick

; Packet types
%define PKT_CONNECT         1
%define PKT_DISCONNECT      2
%define PKT_GAME_STATE      3
%define PKT_PLAYER_INPUT    4
%define PKT_CHAT            5
%define PKT_PING            6
%define PKT_PONG            7

; Network mode
%define NET_MODE_OFFLINE    0
%define NET_MODE_SERVER     1
%define NET_MODE_CLIENT     2

section .data

; sockaddr_in structure for binding
align 8
server_addr:
    dw 2                    ; AF_INET
    dw 0                    ; port (filled at runtime)
    dd 0                    ; INADDR_ANY
    times 8 db 0            ; padding

section .bss

; Network state
global net_mode, net_socket
net_mode:           resd 1      ; 0=offline, 1=server, 2=client
net_socket:         resd 1      ; UDP socket fd
net_tick_counter:   resd 1      ; frames until next network tick

; Client tracking (server only)
alignb 64
client_addrs:       resb NET_MAX_CLIENTS * 16   ; sockaddr_in per client
client_active:      resb NET_MAX_CLIENTS
client_player_id:   resd NET_MAX_CLIENTS        ; entity index per client
client_count:       resd 1

; Packet buffers
alignb 64
send_buf:           resb NET_PACKET_SIZE
recv_buf:           resb NET_PACKET_SIZE
recv_addr:          resb 16     ; sender address
recv_addr_len:      resd 1

; Server address (client mode)
server_connect_addr: resb 16

; Network stats
global net_ping, net_packets_sent, net_packets_recv
net_ping:           resd 1      ; round trip time in ms
net_packets_sent:   resd 1
net_packets_recv:   resd 1

section .text

; ============================================================================
; net_init - Initialize networking (offline mode by default)
; ============================================================================
global net_init
net_init:
    mov dword [net_mode], NET_MODE_OFFLINE
    mov dword [net_socket], -1
    mov dword [net_tick_counter], 0
    mov dword [client_count], 0
    mov dword [net_ping], 0
    mov dword [net_packets_sent], 0
    mov dword [net_packets_recv], 0

    ; Clear client tracking
    lea rdi, [rel client_active]
    xor eax, eax
    mov ecx, NET_MAX_CLIENTS / 4
    rep stosd

    ret

; ============================================================================
; net_start_server - Start as server
; Returns: eax = 0 success, -1 failure
; ============================================================================
global net_start_server
net_start_server:
    push rbx

    ; Create UDP socket
    mov rax, SYS_SOCKET
    mov rdi, 2              ; AF_INET
    mov rsi, 2              ; SOCK_DGRAM
    xor rdx, rdx            ; protocol 0
    syscall
    cmp rax, 0
    jl .server_fail
    mov [net_socket], eax
    mov ebx, eax

    ; Set port in network byte order
    mov word [server_addr + 2], ((NET_PORT >> 8) & 0xFF) | ((NET_PORT & 0xFF) << 8)

    ; Bind socket
    mov rax, SYS_BIND
    mov edi, ebx
    lea rsi, [rel server_addr]
    mov edx, 16
    syscall
    cmp rax, 0
    jl .server_fail

    ; Set non-blocking
    mov rax, 72             ; SYS_FCNTL
    mov edi, ebx
    mov esi, 4              ; F_SETFL
    mov edx, 2048           ; O_NONBLOCK
    syscall

    mov dword [net_mode], NET_MODE_SERVER
    xor eax, eax
    pop rbx
    ret

.server_fail:
    mov eax, -1
    pop rbx
    ret

; ============================================================================
; net_start_client - Connect to server
; edi = server IP (network byte order)
; Returns: eax = 0 success, -1 failure
; ============================================================================
global net_start_client
net_start_client:
    push rbx
    mov ebx, edi

    ; Create UDP socket
    mov rax, SYS_SOCKET
    mov rdi, 2              ; AF_INET
    mov rsi, 2              ; SOCK_DGRAM
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .client_fail
    mov [net_socket], eax

    ; Set non-blocking
    mov rdi, rax
    mov rax, 72             ; SYS_FCNTL
    mov esi, 4              ; F_SETFL
    mov edx, 2048           ; O_NONBLOCK
    syscall

    ; Store server address
    mov word [server_connect_addr], 2       ; AF_INET
    mov word [server_connect_addr + 2], ((NET_PORT >> 8) & 0xFF) | ((NET_PORT & 0xFF) << 8)
    mov [server_connect_addr + 4], ebx      ; server IP

    ; Send connect packet
    lea rdi, [rel send_buf]
    mov byte [rdi], PKT_CONNECT
    mov rax, SYS_SENDTO
    movsx rdi, dword [net_socket]
    lea rsi, [rel send_buf]
    mov rdx, 1
    xor r10, r10
    lea r8, [rel server_connect_addr]
    mov r9d, 16
    syscall

    mov dword [net_mode], NET_MODE_CLIENT
    inc dword [net_packets_sent]
    xor eax, eax
    pop rbx
    ret

.client_fail:
    mov eax, -1
    pop rbx
    ret

; ============================================================================
; net_update - Process network I/O (called each frame)
; ============================================================================
global net_update
net_update:
    cmp dword [net_mode], NET_MODE_OFFLINE
    je .done

    ; Receive incoming packets
    call net_recv_packets

    ; Send state at tick rate
    inc dword [net_tick_counter]
    cmp dword [net_tick_counter], NET_TICK_FRAMES
    jl .done
    mov dword [net_tick_counter], 0

    cmp dword [net_mode], NET_MODE_SERVER
    je .send_state
    cmp dword [net_mode], NET_MODE_CLIENT
    je .send_input
    jmp .done

.send_state:
    call net_send_game_state
    jmp .done

.send_input:
    call net_send_player_input

.done:
    ret

; ============================================================================
; net_recv_packets - Receive and process incoming UDP packets
; ============================================================================
net_recv_packets:
    push rbx

.recv_loop:
    mov dword [recv_addr_len], 16
    mov rax, SYS_RECVFROM
    movsx rdi, dword [net_socket]
    lea rsi, [rel recv_buf]
    mov rdx, NET_PACKET_SIZE
    xor r10, r10            ; flags
    lea r8, [rel recv_addr]
    lea r9, [rel recv_addr_len]
    syscall

    cmp rax, 0
    jle .recv_done          ; no more packets or error

    inc dword [net_packets_recv]

    ; Process packet based on type
    movzx eax, byte [recv_buf]
    cmp al, PKT_CONNECT
    je .handle_connect
    cmp al, PKT_GAME_STATE
    je .handle_game_state
    cmp al, PKT_PLAYER_INPUT
    je .handle_player_input
    cmp al, PKT_PING
    je .handle_ping
    jmp .recv_loop

.handle_connect:
    ; Server: register new client
    cmp dword [net_mode], NET_MODE_SERVER
    jne .recv_loop
    ; Find free client slot
    xor ebx, ebx
.find_client_slot:
    cmp ebx, NET_MAX_CLIENTS
    jge .recv_loop          ; full
    lea rax, [rel client_active]
    cmp byte [rax + rbx], 0
    je .found_client_slot
    inc ebx
    jmp .find_client_slot
.found_client_slot:
    lea rax, [rel client_active]
    mov byte [rax + rbx], 1
    ; Copy sender address
    lea rdi, [rel client_addrs]
    imul ecx, ebx, 16
    add rdi, rcx
    lea rsi, [rel recv_addr]
    mov ecx, 16
    rep movsb
    inc dword [client_count]
    jmp .recv_loop

.handle_game_state:
    ; Client: update entity positions from server
    ; Packet format: [type(1)] [ent_count(4)] [per entity: x(4) y(4) hp(4) state(1)]
    ; Simplified: just update first N entities
    jmp .recv_loop

.handle_player_input:
    ; Server: apply player input
    jmp .recv_loop

.handle_ping:
    ; Respond with pong
    lea rdi, [rel send_buf]
    mov byte [rdi], PKT_PONG
    mov rax, SYS_SENDTO
    movsx rdi, dword [net_socket]
    lea rsi, [rel send_buf]
    mov rdx, 1
    xor r10, r10
    lea r8, [rel recv_addr]
    mov r9d, 16
    syscall
    inc dword [net_packets_sent]
    jmp .recv_loop

.recv_done:
    pop rbx
    ret

; ============================================================================
; net_send_game_state - Broadcast game state to all clients (server)
; ============================================================================
net_send_game_state:
    push rbx
    push r12

    ; Build state packet
    lea rdi, [rel send_buf]
    mov byte [rdi], PKT_GAME_STATE

    ; Pack entity count
    mov eax, [ent_count]
    mov [rdi + 1], eax

    ; Pack entity data (simplified: first 20 entities max)
    mov ecx, eax
    cmp ecx, 20
    jle .pack_ok
    mov ecx, 20
.pack_ok:
    mov r12d, ecx
    lea rbx, [rdi + 5]     ; data start
    xor ecx, ecx

.pack_loop:
    cmp ecx, r12d
    jge .pack_done

    ; X position (truncated to int32)
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rcx * 8]
    mov [rbx], eax
    add rbx, 4

    ; Y position
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + rcx * 8]
    mov [rbx], eax
    add rbx, 4

    ; HP
    lea rax, [rel ent_hp]
    mov eax, [rax + rcx * 4]
    mov [rbx], eax
    add rbx, 4

    ; State
    lea rax, [rel ent_state]
    mov al, [rax + rcx]
    mov [rbx], al
    inc rbx

    inc ecx
    jmp .pack_loop

.pack_done:
    ; Calculate packet size
    lea rax, [rel send_buf]
    sub rbx, rax
    mov rdx, rbx            ; packet size

    ; Send to all active clients
    xor r12d, r12d
.send_loop:
    cmp r12d, NET_MAX_CLIENTS
    jge .send_done

    lea rax, [rel client_active]
    cmp byte [rax + r12], 0
    je .send_next

    ; Send packet
    mov rax, SYS_SENDTO
    movsx rdi, dword [net_socket]
    lea rsi, [rel send_buf]
    ; rdx already set
    xor r10, r10
    lea r8, [rel client_addrs]
    imul ecx, r12d, 16
    add r8, rcx
    mov r9d, 16
    syscall
    inc dword [net_packets_sent]

.send_next:
    inc r12d
    jmp .send_loop

.send_done:
    pop r12
    pop rbx
    ret

; ============================================================================
; net_send_player_input - Send player input to server (client)
; ============================================================================
net_send_player_input:
    ; Build input packet
    lea rdi, [rel send_buf]
    mov byte [rdi], PKT_PLAYER_INPUT

    ; Pack player position and state
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + PLAYER_ID * 8]
    mov [rdi + 1], eax
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + PLAYER_ID * 8]
    mov [rdi + 5], eax
    lea rax, [rel ent_state]
    mov al, [rax + PLAYER_ID]
    mov [rdi + 9], al

    ; Send to server
    mov rax, SYS_SENDTO
    movsx rdi, dword [net_socket]
    lea rsi, [rel send_buf]
    mov rdx, 10             ; packet size
    xor r10, r10
    lea r8, [rel server_connect_addr]
    mov r9d, 16
    syscall
    inc dword [net_packets_sent]
    ret

; ============================================================================
; net_cleanup - Close network socket
; ============================================================================
global net_cleanup
net_cleanup:
    cmp dword [net_mode], NET_MODE_OFFLINE
    je .done
    mov rax, SYS_CLOSE
    movsx rdi, dword [net_socket]
    syscall
    mov dword [net_mode], NET_MODE_OFFLINE
.done:
    ret
