; ============================================================================
; collision.asm - Collision detection
; Optimized distance checks for entity interactions
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_active, ent_state, ent_team, ent_type
extern ent_count
extern entity_radius_table

section .data

section .bss

section .text

; ============================================================================
; collision_check_point - Check if a world point hits any entity
; edi = world_x, esi = world_y
; Returns: eax = entity index hit, or -1 if none
; ============================================================================
global collision_check_point
collision_check_point:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi           ; world_x
    mov r13d, esi           ; world_y
    mov r14d, [ent_count]
    xor ebx, ebx

.check_loop:
    cmp ebx, r14d
    jge .not_found

    ; Skip inactive/dead
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .check_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .check_next

    ; Get entity position (integer approximation)
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rbx * 8]
    sub eax, r12d
    imul eax, eax           ; dx^2

    push rax
    lea rax, [rel ent_y]
    vcvttsd2si ecx, [rax + rbx * 8]
    sub ecx, r13d
    imul ecx, ecx           ; dy^2
    pop rax
    add eax, ecx            ; dist^2

    ; Get entity radius
    lea rcx, [rel ent_type]
    movzx ecx, byte [rcx + rbx]
    lea rdx, [rel entity_radius_table]
    mov edx, [rdx + rcx * 4]
    add edx, 5              ; add click tolerance
    imul edx, edx           ; radius^2

    cmp eax, edx
    jle .found

.check_next:
    inc ebx
    jmp .check_loop

.found:
    mov eax, ebx
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.not_found:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; collision_find_nearest - Find nearest entity of given team within range
; edi = source entity index, esi = target team, edx = max range
; Returns: eax = nearest entity index, or -1
; ============================================================================
global collision_find_nearest
collision_find_nearest:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi           ; source index
    mov r13d, esi           ; target team
    mov r14d, edx
    imul r14d, edx          ; max range squared
    mov r15d, -1            ; best index
    mov ebp, 0x7FFFFFFF     ; best dist^2

    ; Get source position
    lea rax, [rel ent_x]
    vcvttsd2si r8d, [rax + r12 * 8]
    lea rax, [rel ent_y]
    vcvttsd2si r9d, [rax + r12 * 8]

    xor ebx, ebx
    mov ecx, [ent_count]

.find_loop:
    cmp ebx, ecx
    jge .find_done

    cmp ebx, r12d
    je .find_next

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .find_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .find_next
    lea rax, [rel ent_team]
    cmp byte [rax + rbx], r13b
    jne .find_next

    ; Calculate distance
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rbx * 8]
    sub eax, r8d
    imul eax, eax

    push rax
    lea rax, [rel ent_y]
    vcvttsd2si edx, [rax + rbx * 8]
    sub edx, r9d
    imul edx, edx
    pop rax
    add eax, edx

    cmp eax, r14d
    jg .find_next
    cmp eax, ebp
    jge .find_next

    mov ebp, eax
    mov r15d, ebx

.find_next:
    inc ebx
    jmp .find_loop

.find_done:
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
