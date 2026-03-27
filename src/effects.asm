; ============================================================================
; effects.asm - Particle/animation/effects system (Phase 8)
; Particles, floating damage numbers, death animations, attack indicators,
; range indicators, and spell effect visuals
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

; External entity data
extern ent_x, ent_y, ent_hp, ent_max_hp, ent_type, ent_team
extern ent_state, ent_active, ent_count

; External camera
extern camera_x, camera_y

; External render functions
extern render_rect, render_circle, render_string, render_number
extern framebuffer

; ============================================================================
; BSS - Effect data arrays
; ============================================================================
section .bss
    align 64

; Particle arrays
global particle_x, particle_y, particle_vx, particle_vy
global particle_color, particle_life, particle_size
particle_x:     resd MAX_PARTICLES
particle_y:     resd MAX_PARTICLES
particle_vx:    resd MAX_PARTICLES
particle_vy:    resd MAX_PARTICLES
particle_color: resd MAX_PARTICLES
particle_life:  resd MAX_PARTICLES
particle_size:  resd MAX_PARTICLES

; Damage number arrays
global dmg_num_x, dmg_num_y, dmg_num_val, dmg_num_color, dmg_num_life
dmg_num_x:      resd 32
dmg_num_y:      resd 32
dmg_num_val:    resd 32
dmg_num_color:  resd 32
dmg_num_life:   resd 32

; ============================================================================
section .text
; ============================================================================

; ============================================================================
; effects_init - Zero all particle and damage number arrays
; ============================================================================
global effects_init
effects_init:
    push rdi

    ; Zero particle arrays (MAX_PARTICLES * 4 bytes each, 7 arrays)
    lea rdi, [particle_x]
    xor eax, eax
    mov ecx, MAX_PARTICLES * 7
    rep stosd

    ; Zero damage number arrays (32 * 4 bytes each, 5 arrays)
    lea rdi, [dmg_num_x]
    xor eax, eax
    mov ecx, 32 * 5
    rep stosd

    pop rdi
    ret

; ============================================================================
; effects_spawn_particle - Spawn one particle
; edi=x, esi=y, edx=vx, ecx=vy, r8d=color, r9d=lifetime
; ============================================================================
global effects_spawn_particle
effects_spawn_particle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; Save parameters
    mov r10d, edi           ; x
    mov r11d, esi           ; y
    mov r12d, edx           ; vx
    mov r13d, ecx           ; vy
    mov r14d, r8d           ; color
    mov r15d, r9d           ; lifetime

    ; Find first inactive particle (life == 0)
    xor ebx, ebx
.find_slot:
    cmp ebx, MAX_PARTICLES
    jge .no_slot
    cmp dword [particle_life + rbx*4], 0
    je .found_slot
    inc ebx
    jmp .find_slot

.found_slot:
    mov [particle_x + rbx*4], r10d
    mov [particle_y + rbx*4], r11d
    mov [particle_vx + rbx*4], r12d
    mov [particle_vy + rbx*4], r13d
    mov [particle_color + rbx*4], r14d
    mov [particle_life + rbx*4], r15d
    mov dword [particle_size + rbx*4], 2    ; default size

.no_slot:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; effects_spawn_damage_num - Spawn floating damage number
; edi=world_x, esi=world_y, edx=damage_value, ecx=color
; ============================================================================
global effects_spawn_damage_num
effects_spawn_damage_num:
    push rbx

    ; Find first inactive damage number slot (life == 0)
    xor ebx, ebx
.find_slot:
    cmp ebx, 32
    jge .no_slot
    cmp dword [dmg_num_life + rbx*4], 0
    je .found_slot
    inc ebx
    jmp .find_slot

.found_slot:
    mov [dmg_num_x + rbx*4], edi
    mov [dmg_num_y + rbx*4], esi
    mov [dmg_num_val + rbx*4], edx
    mov [dmg_num_color + rbx*4], ecx
    mov dword [dmg_num_life + rbx*4], DAMAGE_NUM_LIFETIME

.no_slot:
    pop rbx
    ret

; ============================================================================
; effects_update - Update all active particles and damage numbers each frame
; ============================================================================
global effects_update
effects_update:
    push rbx

    ; --- Update particles ---
    xor ebx, ebx
.update_particles:
    cmp ebx, MAX_PARTICLES
    jge .update_dmg_nums

    cmp dword [particle_life + rbx*4], 0
    je .next_particle

    ; Decrement lifetime
    dec dword [particle_life + rbx*4]

    ; Add velocity to position
    mov eax, [particle_vx + rbx*4]
    add [particle_x + rbx*4], eax
    mov eax, [particle_vy + rbx*4]
    add [particle_y + rbx*4], eax

.next_particle:
    inc ebx
    jmp .update_particles

    ; --- Update damage numbers ---
.update_dmg_nums:
    xor ebx, ebx
.update_dmg_loop:
    cmp ebx, 32
    jge .update_done

    cmp dword [dmg_num_life + rbx*4], 0
    je .next_dmg

    ; Decrement lifetime
    dec dword [dmg_num_life + rbx*4]

    ; Float upward (subtract DAMAGE_NUM_SPEED from y)
    sub dword [dmg_num_y + rbx*4], DAMAGE_NUM_SPEED

.next_dmg:
    inc ebx
    jmp .update_dmg_loop

.update_done:
    pop rbx
    ret

; ============================================================================
; effects_render - Render all active particles and damage numbers
; ============================================================================
global effects_render
effects_render:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; --- Render particles ---
    xor ebx, ebx
.render_particles:
    cmp ebx, MAX_PARTICLES
    jge .render_dmg_nums

    cmp dword [particle_life + rbx*4], 0
    je .next_render_particle

    ; Convert to screen coords
    mov eax, [particle_x + rbx*4]
    sub eax, [camera_x]
    mov r12d, eax               ; screen x

    mov eax, [particle_y + rbx*4]
    sub eax, [camera_y]
    mov r13d, eax               ; screen y

    ; Skip if off screen
    cmp r12d, 0
    jl .next_render_particle
    cmp r12d, WINDOW_WIDTH
    jge .next_render_particle
    cmp r13d, 0
    jl .next_render_particle
    cmp r13d, WINDOW_HEIGHT
    jge .next_render_particle

    ; Save rbx across call
    mov r14d, ebx

    ; Get particle size
    mov eax, [particle_size + rbx*4]
    mov r15d, eax               ; save size

    ; render_rect(x, y, width, height, color)
    ; Adjust x,y so particle is centered
    mov edi, r12d
    sub edi, r15d               ; x - size (center)
    mov esi, r13d
    sub esi, r15d               ; y - size (center)
    lea edx, [r15d + r15d]     ; width = size * 2
    mov ecx, edx                ; height = size * 2
    mov r8d, [particle_color + rbx*4]
    call render_rect

    mov ebx, r14d

.next_render_particle:
    inc ebx
    jmp .render_particles

    ; --- Render damage numbers ---
.render_dmg_nums:
    xor ebx, ebx
.render_dmg_loop:
    cmp ebx, 32
    jge .render_done

    cmp dword [dmg_num_life + rbx*4], 0
    je .next_render_dmg

    ; Convert world coords to screen coords
    mov eax, [dmg_num_x + rbx*4]
    sub eax, [camera_x]
    mov r12d, eax               ; screen x

    mov eax, [dmg_num_y + rbx*4]
    sub eax, [camera_y]
    mov r13d, eax               ; screen y

    ; Skip if off screen
    cmp r12d, 0
    jl .next_render_dmg
    cmp r12d, WINDOW_WIDTH
    jge .next_render_dmg
    cmp r13d, 0
    jl .next_render_dmg
    cmp r13d, WINDOW_HEIGHT
    jge .next_render_dmg

    ; Save rbx across call
    mov r14d, ebx

    ; render_number(number, x, y, color)
    mov edi, [dmg_num_val + rbx*4]
    mov esi, r12d
    mov edx, r13d
    mov ecx, [dmg_num_color + rbx*4]
    call render_number

    mov ebx, r14d

.next_render_dmg:
    inc ebx
    jmp .render_dmg_loop

.render_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; effects_spawn_death - Spawn 8 particles in circle pattern on entity death
; edi=world_x, esi=world_y, edx=color
; ============================================================================
global effects_spawn_death
effects_spawn_death:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi               ; world_x
    mov r13d, esi               ; world_y
    mov r14d, edx               ; color

    ; Spawn 8 particles at fixed offsets (up, down, left, right, diagonals)
    ; Velocity table: 8 directions with (vx, vy) pairs
    ; Each velocity is in 1/10 px per frame units

    ; Particle 0: Up (vx=0, vy=-3)
    mov edi, r12d
    mov esi, r13d
    xor edx, edx               ; vx = 0
    mov ecx, -3                 ; vy = -3
    mov r8d, r14d               ; color
    mov r9d, 20                 ; lifetime
    call effects_spawn_particle
    ; Set size to 2 for last spawned particle
    call .set_last_size

    ; Particle 1: Down (vx=0, vy=3)
    mov edi, r12d
    mov esi, r13d
    xor edx, edx
    mov ecx, 3
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 2: Left (vx=-3, vy=0)
    mov edi, r12d
    mov esi, r13d
    mov edx, -3
    xor ecx, ecx
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 3: Right (vx=3, vy=0)
    mov edi, r12d
    mov esi, r13d
    mov edx, 3
    xor ecx, ecx
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 4: Up-Left (vx=-2, vy=-2)
    mov edi, r12d
    mov esi, r13d
    mov edx, -2
    mov ecx, -2
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 5: Up-Right (vx=2, vy=-2)
    mov edi, r12d
    mov esi, r13d
    mov edx, 2
    mov ecx, -2
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 6: Down-Left (vx=-2, vy=2)
    mov edi, r12d
    mov esi, r13d
    mov edx, -2
    mov ecx, 2
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    ; Particle 7: Down-Right (vx=2, vy=2)
    mov edi, r12d
    mov esi, r13d
    mov edx, 2
    mov ecx, 2
    mov r8d, r14d
    mov r9d, 20
    call effects_spawn_particle
    call .set_last_size

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Helper: find the particle we just spawned and set its size to 2
; (scans backwards from end to find first active particle with life=20)
.set_last_size:
    push rbx
    mov ebx, MAX_PARTICLES - 1
.find_last:
    cmp ebx, 0
    jl .set_done
    cmp dword [particle_life + rbx*4], 20
    je .set_it
    dec ebx
    jmp .find_last
.set_it:
    mov dword [particle_size + rbx*4], 2
.set_done:
    pop rbx
    ret

; ============================================================================
; effects_spawn_attack_line - Spawn particles along attack line
; edi=x1, esi=y1, edx=x2, ecx=y2, r8d=color
; Spawns 3 particles evenly along line, life=10, size=1
; ============================================================================
global effects_spawn_attack_line
effects_spawn_attack_line:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    mov r12d, edi               ; x1
    mov r13d, esi               ; y1
    mov r14d, edx               ; x2
    mov r15d, ecx               ; y2
    mov ebp, r8d                ; color

    ; Calculate deltas
    ; dx = x2 - x1, dy = y2 - y1
    sub r14d, r12d              ; dx = x2 - x1
    sub r15d, r13d              ; dy = y2 - y1

    ; Spawn 3 particles at 25%, 50%, 75% along the line
    ; Particle at t: x = x1 + dx*t, y = y1 + dy*t

    ; Particle 0: t = 1/4
    mov eax, r14d
    sar eax, 2                  ; dx / 4
    add eax, r12d               ; x1 + dx/4
    mov edi, eax
    mov eax, r15d
    sar eax, 2                  ; dy / 4
    add eax, r13d               ; y1 + dy/4
    mov esi, eax
    xor edx, edx               ; vx = 0
    xor ecx, ecx               ; vy = 0
    mov r8d, ebp                ; color
    mov r9d, 10                 ; lifetime
    call effects_spawn_particle
    ; Set size to 1
    call .set_size_1

    ; Particle 1: t = 1/2
    mov eax, r14d
    sar eax, 1                  ; dx / 2
    add eax, r12d
    mov edi, eax
    mov eax, r15d
    sar eax, 1                  ; dy / 2
    add eax, r13d
    mov esi, eax
    xor edx, edx
    xor ecx, ecx
    mov r8d, ebp
    mov r9d, 10
    call effects_spawn_particle
    call .set_size_1

    ; Particle 2: t = 3/4
    mov eax, r14d
    imul eax, 3
    sar eax, 2                  ; dx * 3 / 4
    add eax, r12d
    mov edi, eax
    mov eax, r15d
    imul eax, 3
    sar eax, 2                  ; dy * 3 / 4
    add eax, r13d
    mov esi, eax
    xor edx, edx
    xor ecx, ecx
    mov r8d, ebp
    mov r9d, 10
    call effects_spawn_particle
    call .set_size_1

    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Helper: find last spawned particle (life=10) and set size to 1
.set_size_1:
    push rbx
    mov ebx, MAX_PARTICLES - 1
.find_last_atk:
    cmp ebx, 0
    jl .set_done_atk
    cmp dword [particle_life + rbx*4], 10
    je .set_it_atk
    dec ebx
    jmp .find_last_atk
.set_it_atk:
    mov dword [particle_size + rbx*4], 1
.set_done_atk:
    pop rbx
    ret
