; ============================================================================
; jungle.asm - Jungle Camp System
; Manages jungle monster spawning, respawn timers, dragon/baron tracking
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

; ---------------------------------------------------------------------------
; External symbols
; ---------------------------------------------------------------------------
extern ent_x, ent_y, ent_hp, ent_max_hp, ent_type, ent_team, ent_state, ent_active
extern ent_atk, ent_range, ent_speed, ent_atk_speed, ent_gold, ent_xp, ent_count
extern entity_spawn, entity_set_stats
extern game_frame

; ---------------------------------------------------------------------------
; Number of jungle camps
; ---------------------------------------------------------------------------
%define NUM_JUNGLE_CAMPS    14

; ============================================================================
; BSS - Jungle state
; ============================================================================
section .bss

alignb 64
global jungle_respawn_timers
jungle_respawn_timers:  resd 20          ; respawn timer for each camp slot

global jungle_camp_active
jungle_camp_active:     resb 20          ; 1=alive, 0=dead

global dragon_type
dragon_type:            resd 1           ; current dragon type 0-3

global dragon_kills_blue
dragon_kills_blue:      resd 1

global dragon_kills_red
dragon_kills_red:       resd 1

global baron_alive
baron_alive:            resd 1

; Entity indices for each camp (so we can check if they died)
jungle_camp_ent_id:     resd 20

; ============================================================================
; Data
; ============================================================================
section .data

; Camp spawn positions: pairs of dwords (x, y) for each camp
jungle_camp_positions:
    ; Blue side camps
    dd 1200, 6400       ; camp 0:  Blue Gromp
    dd 1600, 5800       ; camp 1:  Blue Wolves
    dd 2400, 6800       ; camp 2:  Blue Raptors
    dd 3000, 7200       ; camp 3:  Blue Krugs
    dd 1400, 6000       ; camp 4:  Blue Buff (Blue sentinel)
    dd 2800, 7000       ; camp 5:  Red Buff (Blue side)
    ; Red side camps
    dd 7200, 2000       ; camp 6:  Red Gromp
    dd 6800, 2600       ; camp 7:  Red Wolves
    dd 6000, 1600       ; camp 8:  Red Raptors
    dd 5400, 1200       ; camp 9:  Red Krugs
    dd 7000, 2400       ; camp 10: Blue Buff (Red side)
    dd 5600, 1400       ; camp 11: Red Buff (Red side)
    ; Epic monsters
    dd 4480, 3200       ; camp 12: Dragon
    dd 4000, 2800       ; camp 13: Baron/Herald

; Camp type table (byte per camp, matching entity type)
jungle_camp_types:
    db ENT_JUNGLE_CAMP  ; 0
    db ENT_JUNGLE_CAMP  ; 1
    db ENT_JUNGLE_CAMP  ; 2
    db ENT_JUNGLE_CAMP  ; 3
    db ENT_JUNGLE_CAMP  ; 4
    db ENT_JUNGLE_CAMP  ; 5
    db ENT_JUNGLE_CAMP  ; 6
    db ENT_JUNGLE_CAMP  ; 7
    db ENT_JUNGLE_CAMP  ; 8
    db ENT_JUNGLE_CAMP  ; 9
    db ENT_JUNGLE_CAMP  ; 10
    db ENT_JUNGLE_CAMP  ; 11
    db ENT_DRAGON        ; 12
    db ENT_BARON         ; 13

; HP table: dword per camp
jungle_camp_hp:
    dd GROMP_HP          ; 0
    dd WOLVES_HP         ; 1
    dd RAPTORS_HP        ; 2
    dd KRUGS_HP          ; 3
    dd BLUE_BUFF_HP      ; 4
    dd RED_BUFF_HP       ; 5
    dd GROMP_HP          ; 6
    dd WOLVES_HP         ; 7
    dd RAPTORS_HP        ; 8
    dd KRUGS_HP          ; 9
    dd BLUE_BUFF_HP      ; 10
    dd RED_BUFF_HP       ; 11
    dd DRAGON_HP         ; 12
    dd BARON_HP          ; 13

; AD table: dword per camp
jungle_camp_ad:
    dd GROMP_AD          ; 0
    dd WOLVES_AD         ; 1
    dd RAPTORS_AD        ; 2
    dd KRUGS_AD          ; 3
    dd BLUE_BUFF_AD      ; 4
    dd RED_BUFF_AD       ; 5
    dd GROMP_AD          ; 6
    dd WOLVES_AD         ; 7
    dd RAPTORS_AD        ; 8
    dd KRUGS_AD          ; 9
    dd BLUE_BUFF_AD      ; 10
    dd RED_BUFF_AD       ; 11
    dd DRAGON_AD         ; 12
    dd BARON_AD          ; 13

; ============================================================================
; Text section
; ============================================================================
section .text

; ============================================================================
; jungle_init - Initialize jungle system
; Zeroes all timers/flags, sets all camps active, spawns all camps
; ============================================================================
global jungle_init
jungle_init:
    push rbx

    ; Zero respawn timers (20 dwords = 80 bytes)
    lea rdi, [rel jungle_respawn_timers]
    xor eax, eax
    mov ecx, 20
    rep stosd

    ; Zero camp active flags (20 bytes, clear 20 as dwords = 5)
    lea rdi, [rel jungle_camp_active]
    xor eax, eax
    mov ecx, 5
    rep stosd

    ; Set all 14 camps active
    lea rdi, [rel jungle_camp_active]
    mov ecx, NUM_JUNGLE_CAMPS
.init_active:
    mov byte [rdi], 1
    inc rdi
    dec ecx
    jnz .init_active

    ; Zero entity id tracking
    lea rdi, [rel jungle_camp_ent_id]
    xor eax, eax
    mov ecx, 20
    rep stosd

    ; Set dragon_type to DRAGON_INFERNAL (0)
    mov dword [rel dragon_type], 0

    ; Zero dragon kill counts
    mov dword [rel dragon_kills_blue], 0
    mov dword [rel dragon_kills_red], 0

    ; Baron not alive initially
    mov dword [rel baron_alive], 0

    ; Spawn all camps
    call jungle_spawn_all_camps

    pop rbx
    ret

; ============================================================================
; jungle_spawn_all_camps - Spawn entities for all 14 camps
; ============================================================================
jungle_spawn_all_camps:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                  ; align stack to 16 bytes

    xor ebx, ebx               ; camp index

.spawn_loop:
    cmp ebx, NUM_JUNGLE_CAMPS
    jge .spawn_done

    ; Load entity type for this camp
    lea rax, [rel jungle_camp_types]
    movzx edi, byte [rax + rbx]     ; edi = entity type

    ; Team = TEAM_NEUTRAL
    mov esi, TEAM_NEUTRAL

    ; Load position from table
    lea rax, [rel jungle_camp_positions]
    mov r12d, [rax + rbx * 8]       ; x (dword)
    mov r13d, [rax + rbx * 8 + 4]   ; y (dword)

    ; Convert x to double in xmm0
    cvtsi2sd xmm0, r12d
    ; Convert y to double in xmm1
    cvtsi2sd xmm1, r13d

    ; Save camp index across call
    mov r14d, ebx

    ; entity_spawn(type, team, x_double, y_double) -> eax = entity index
    call entity_spawn
    mov r15d, eax               ; r15d = spawned entity index

    mov ebx, r14d               ; restore camp index

    ; Store entity index for this camp
    lea rcx, [rel jungle_camp_ent_id]
    mov [rcx + rbx * 4], r15d

    ; Skip set_stats if spawn failed
    cmp r15d, -1
    je .spawn_next

    ; entity_set_stats(index, hp, mana, atk, range, speed, [stack] atk_speed)
    mov edi, r15d               ; entity index

    ; Load HP for this camp
    lea rax, [rel jungle_camp_hp]
    mov esi, [rax + rbx * 4]    ; hp

    ; Mana = 0 for jungle monsters
    xor edx, edx               ; mana = 0

    ; Load AD for this camp
    lea rax, [rel jungle_camp_ad]
    mov ecx, [rax + rbx * 4]   ; atk

    ; Range = 100
    mov r8d, 100                ; range

    ; Speed = 0 (jungle camps don't move)
    xor r9d, r9d               ; speed = 0

    ; atk_speed = 60 (passed on stack)
    push qword 60
    call entity_set_stats
    add rsp, 8

.spawn_next:
    mov ebx, r14d
    inc ebx
    jmp .spawn_loop

.spawn_done:
    add rsp, 8                  ; remove alignment padding
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; jungle_spawn_camp - Spawn a single camp by index
; edi = camp index (0-13)
; ============================================================================
jungle_spawn_camp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                  ; align stack

    mov r14d, edi               ; save camp index

    ; Load entity type
    lea rax, [rel jungle_camp_types]
    movzx edi, byte [rax + r14]

    ; Team = TEAM_NEUTRAL
    mov esi, TEAM_NEUTRAL

    ; Load position
    lea rax, [rel jungle_camp_positions]
    mov r12d, [rax + r14 * 8]
    mov r13d, [rax + r14 * 8 + 4]

    cvtsi2sd xmm0, r12d
    cvtsi2sd xmm1, r13d

    call entity_spawn
    mov r15d, eax

    ; Store entity index
    lea rcx, [rel jungle_camp_ent_id]
    mov [rcx + r14 * 4], r15d

    cmp r15d, -1
    je .single_spawn_done

    ; Set stats
    mov edi, r15d

    lea rax, [rel jungle_camp_hp]
    mov esi, [rax + r14 * 4]

    xor edx, edx               ; mana = 0

    lea rax, [rel jungle_camp_ad]
    mov ecx, [rax + r14 * 4]

    mov r8d, 100                ; range
    xor r9d, r9d               ; speed = 0

    push qword 60              ; atk_speed
    call entity_set_stats
    add rsp, 8

    ; Mark camp as active
    lea rax, [rel jungle_camp_active]
    mov byte [rax + r14], 1

.single_spawn_done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; jungle_update - Called each frame. Checks for dead camps and manages respawns
; ============================================================================
global jungle_update
jungle_update:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8                  ; align stack

    xor ebx, ebx               ; camp index

.update_loop:
    cmp ebx, NUM_JUNGLE_CAMPS
    jge .update_done

    ; Check if camp is marked active
    lea rax, [rel jungle_camp_active]
    cmp byte [rax + rbx], 1
    jne .check_respawn

    ; Camp is active -- check if its entity is still alive
    lea rax, [rel jungle_camp_ent_id]
    mov r12d, [rax + rbx * 4]       ; entity index

    ; Validate entity index
    cmp r12d, 0
    jl .update_next
    cmp r12d, MAX_ENTITIES
    jge .update_next

    ; Check if entity is dead (hp <= 0 or state == STATE_DEAD or inactive)
    lea rax, [rel ent_active]
    cmp byte [rax + r12], 0
    je .camp_died

    lea rax, [rel ent_state]
    cmp byte [rax + r12], STATE_DEAD
    je .camp_died

    lea rax, [rel ent_hp]
    cmp dword [rax + r12 * 4], 0
    jle .camp_died

    jmp .update_next

.camp_died:
    ; Mark camp as dead
    lea rax, [rel jungle_camp_active]
    mov byte [rax + rbx], 0

    ; Set respawn timer based on camp type
    cmp ebx, 12
    je .set_dragon_timer
    cmp ebx, 13
    je .set_baron_timer

    ; Normal camp respawn
    lea rax, [rel jungle_respawn_timers]
    mov dword [rax + rbx * 4], JUNGLE_RESPAWN
    jmp .update_next

.set_dragon_timer:
    lea rax, [rel jungle_respawn_timers]
    mov dword [rax + rbx * 4], DRAGON_RESPAWN
    jmp .update_next

.set_baron_timer:
    lea rax, [rel jungle_respawn_timers]
    mov dword [rax + rbx * 4], BARON_RESPAWN
    mov dword [rel baron_alive], 0
    jmp .update_next

.check_respawn:
    ; Camp is dead -- decrement respawn timer
    lea rax, [rel jungle_respawn_timers]
    mov r12d, [rax + rbx * 4]
    test r12d, r12d
    jz .update_next             ; timer already at 0, do nothing

    dec r12d
    mov [rax + rbx * 4], r12d
    test r12d, r12d
    jnz .update_next            ; timer not yet zero

    ; Timer reached 0 -- respawn this camp
    mov r14d, ebx               ; save camp index
    mov edi, ebx
    call jungle_spawn_camp
    mov ebx, r14d               ; restore camp index

    ; For baron, mark alive
    cmp ebx, 13
    jne .update_next
    mov dword [rel baron_alive], 1

.update_next:
    inc ebx
    jmp .update_loop

.update_done:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
