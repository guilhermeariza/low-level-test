; ============================================================================
; game.asm - Core game logic
; Movement, combat, AI, spawning, camera
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

; Entity arrays
extern ent_x, ent_y, ent_target_x, ent_target_y
extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_range, ent_speed, ent_atk_speed
extern ent_atk_cooldown, ent_atk_target
extern ent_type, ent_team, ent_state, ent_active
extern ent_respawn_timer, ent_lane, ent_waypoint_idx
extern ent_gold, ent_level, ent_xp, ent_count

extern entity_spawn, entity_set_stats, entity_kill, entity_deactivate

; Input
extern mouse_x, mouse_y, mouse_clicked_left, mouse_clicked_right
extern mouse_click_x, mouse_click_y

; Math
extern math_distance, math_distance_sq, math_move_toward
extern math_int_to_double

; Map
extern map_waypoints_top_blue, map_waypoints_top_red
extern map_waypoints_mid_blue, map_waypoints_mid_red
extern map_waypoints_bot_blue, map_waypoints_bot_red
extern map_waypoint_counts

section .data

align 8
speed_scale:    dq 0.0833333   ; speed / 60fps (per frame movement factor)
frame_speed:    dq 0.0          ; computed per-frame speed

section .bss

; Camera position (world coordinates of top-left corner)
global camera_x, camera_y
camera_x:       resd 1
camera_y:       resd 1

; Game state
global game_frame, game_time
game_frame:     resd 1          ; frame counter
game_time:      resd 1          ; game time in seconds

; Wave spawning
global wave_timer
wave_timer:     resd 1          ; frames until next wave

; Temp storage for function calls
alignb 8
temp_double:    resq 4

section .text

; ============================================================================
; game_init - Initialize game state, spawn initial entities
; ============================================================================
global game_init
game_init:
    push rbx
    push r12

    ; Initialize camera at blue base
    mov dword [camera_x], 100
    mov dword [camera_y], (MAP_PIXEL_HEIGHT - WINDOW_HEIGHT + 100)

    ; Initialize game state
    mov dword [game_frame], 0
    mov dword [game_time], 0
    mov dword [wave_timer], 180     ; first wave at 3 seconds

    ; --- Spawn player champion (entity 0) ---
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE

    ; Blue base spawn position (bottom-left area)
    mov eax, 400
    vcvtsi2sd xmm0, xmm0, eax      ; x = 400
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 400
    vcvtsi2sd xmm1, xmm1, eax      ; y = map_height - 400
    call entity_spawn
    mov r12d, eax                    ; save player index

    ; Set player stats
    mov edi, r12d
    mov esi, CHAMPION_HP
    mov edx, CHAMPION_MANA
    mov ecx, CHAMPION_AD
    mov r8d, CHAMPION_RANGE
    mov r9d, CHAMPION_SPEED
    push qword CHAMPION_ATK_SPD
    call entity_set_stats
    add rsp, 8

    ; Give starting gold
    lea rax, [rel ent_gold]
    mov dword [rax + r12 * 4], STARTING_GOLD

    ; --- Spawn towers ---
    ; Blue towers - mid lane
    call .spawn_blue_tower_mid1
    call .spawn_blue_tower_mid2

    ; Red towers - mid lane
    call .spawn_red_tower_mid1
    call .spawn_red_tower_mid2

    ; Blue towers - top lane
    call .spawn_blue_tower_top

    ; Red towers - top lane
    call .spawn_red_tower_top

    ; Blue towers - bot lane
    call .spawn_blue_tower_bot

    ; Red towers - bot lane
    call .spawn_red_tower_bot

    pop r12
    pop rbx
    ret

; Tower spawn helpers
.spawn_blue_tower_mid1:
    mov edi, ENT_TOWER
    mov esi, TEAM_BLUE
    mov eax, 1800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 1800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_blue_tower_mid2:
    mov edi, ENT_TOWER
    mov esi, TEAM_BLUE
    mov eax, 2800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 2800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_tower_mid1:
    mov edi, ENT_TOWER
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 1800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 1800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_tower_mid2:
    mov edi, ENT_TOWER
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 2800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 2800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_blue_tower_top:
    mov edi, ENT_TOWER
    mov esi, TEAM_BLUE
    mov eax, 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT / 2
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_tower_top:
    mov edi, ENT_TOWER
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH / 2
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 400
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_blue_tower_bot:
    mov edi, ENT_TOWER
    mov esi, TEAM_BLUE
    mov eax, MAP_PIXEL_WIDTH / 2
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 400
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_tower_bot:
    mov edi, ENT_TOWER
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT / 2
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, TOWER_HP
    xor edx, edx
    mov ecx, TOWER_AD
    mov r8d, TOWER_RANGE
    xor r9d, r9d
    push qword TOWER_ATK_SPD
    call entity_set_stats
    add rsp, 8
    ret

; ============================================================================
; game_update - Main game update (called once per frame)
; ============================================================================
global game_update
game_update:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    inc dword [game_frame]

    ; Update game time (every 60 frames = 1 second)
    mov eax, [game_frame]
    xor edx, edx
    mov ecx, 60
    div ecx
    test edx, edx
    jnz .no_time_inc
    inc dword [game_time]
.no_time_inc:

    ; --- Handle player input ---
    call game_handle_input

    ; --- Update camera ---
    call game_update_camera

    ; --- Spawn waves ---
    call game_spawn_waves

    ; --- Update all entities ---
    call game_update_entities

    ; --- Process combat ---
    call game_process_combat

    ; --- Process respawns ---
    call game_process_respawns

    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; game_handle_input - Process player input
; ============================================================================
game_handle_input:
    push rbx

    ; Right click = move command
    cmp dword [mouse_clicked_right], 0
    je .no_right_click

    ; Convert screen click to world coordinates
    mov eax, [mouse_click_x]
    add eax, [camera_x]
    vcvtsi2sd xmm0, xmm0, eax      ; world_x

    mov eax, [mouse_click_y]
    add eax, [camera_y]
    vcvtsi2sd xmm1, xmm1, eax      ; world_y

    ; Set player target
    lea rax, [rel ent_target_x]
    movsd [rax + PLAYER_ID * 8], xmm0
    lea rax, [rel ent_target_y]
    movsd [rax + PLAYER_ID * 8], xmm1

    ; Set player state to moving
    lea rax, [rel ent_state]
    mov byte [rax + PLAYER_ID], STATE_MOVING

    ; Clear attack target when moving
    lea rax, [rel ent_atk_target]
    mov dword [rax + PLAYER_ID * 4], -1

.no_right_click:

    ; Left click = attack/select target
    cmp dword [mouse_clicked_left], 0
    je .no_left_click

    ; Find entity under mouse cursor
    mov eax, [mouse_click_x]
    add eax, [camera_x]
    mov r8d, eax                    ; world click X

    mov eax, [mouse_click_y]
    add eax, [camera_y]
    mov r9d, eax                    ; world click Y

    ; Search entities for click hit
    xor ebx, ebx
    mov ecx, [ent_count]
.click_search:
    cmp ebx, ecx
    jge .no_target_found

    ; Skip player, inactive, dead
    cmp ebx, PLAYER_ID
    je .click_next
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .click_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .click_next

    ; Check distance to click point
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rbx * 8]
    sub eax, r8d
    imul eax, eax                   ; dx^2

    push rax
    lea rax, [rel ent_y]
    vcvttsd2si edx, [rax + rbx * 8]
    sub edx, r9d
    imul edx, edx                   ; dy^2
    pop rax
    add eax, edx                    ; dist^2

    cmp eax, 900                    ; within 30 pixel radius?
    jg .click_next

    ; Found target - check if enemy
    lea rax, [rel ent_team]
    movzx edx, byte [rax + PLAYER_ID]
    cmp dl, byte [rax + rbx]
    je .click_next                  ; same team, skip

    ; Set attack target
    lea rax, [rel ent_atk_target]
    mov [rax + PLAYER_ID * 4], ebx
    lea rax, [rel ent_state]
    mov byte [rax + PLAYER_ID], STATE_ATTACKING
    jmp .no_left_click

.click_next:
    inc ebx
    jmp .click_search

.no_target_found:
.no_left_click:
    pop rbx
    ret

; ============================================================================
; game_update_camera - Update camera position (edge scrolling + follow)
; ============================================================================
game_update_camera:
    ; Edge scrolling
    mov eax, [mouse_x]

    ; Scroll left
    cmp eax, CAMERA_EDGE_SCROLL
    jg .no_scroll_left
    sub dword [camera_x], CAMERA_SCROLL_SPEED
.no_scroll_left:

    ; Scroll right
    cmp eax, WINDOW_WIDTH - CAMERA_EDGE_SCROLL
    jl .no_scroll_right
    add dword [camera_x], CAMERA_SCROLL_SPEED
.no_scroll_right:

    mov eax, [mouse_y]

    ; Scroll up
    cmp eax, CAMERA_EDGE_SCROLL
    jg .no_scroll_up
    sub dword [camera_y], CAMERA_SCROLL_SPEED
.no_scroll_up:

    ; Scroll down
    cmp eax, WINDOW_HEIGHT - CAMERA_EDGE_SCROLL
    jl .no_scroll_down
    add dword [camera_y], CAMERA_SCROLL_SPEED
.no_scroll_down:

    ; Clamp camera to map bounds
    cmp dword [camera_x], 0
    jge .cam_no_clamp_left
    mov dword [camera_x], 0
.cam_no_clamp_left:
    mov eax, MAP_PIXEL_WIDTH - WINDOW_WIDTH
    cmp [camera_x], eax
    jle .cam_no_clamp_right
    mov [camera_x], eax
.cam_no_clamp_right:
    cmp dword [camera_y], 0
    jge .cam_no_clamp_top
    mov dword [camera_y], 0
.cam_no_clamp_top:
    mov eax, MAP_PIXEL_HEIGHT - WINDOW_HEIGHT
    cmp [camera_y], eax
    jle .cam_no_clamp_bot
    mov [camera_y], eax
.cam_no_clamp_bot:
    ret

; ============================================================================
; game_spawn_waves - Spawn minion waves periodically
; ============================================================================
game_spawn_waves:
    push rbx
    push r12

    dec dword [wave_timer]
    cmp dword [wave_timer], 0
    jg .no_spawn

    ; Reset timer
    mov dword [wave_timer], MINION_WAVE_INTERVAL

    ; Spawn blue team minions (mid lane)
    mov r12d, 0             ; lane = mid
    call .spawn_wave_for_team_blue
    call .spawn_wave_for_team_red

.no_spawn:
    pop r12
    pop rbx
    ret

.spawn_wave_for_team_blue:
    push r13
    mov r13d, MINIONS_PER_WAVE
.blue_melee_loop:
    test r13d, r13d
    jz .blue_melee_done

    mov edi, ENT_MINION_MELEE
    mov esi, TEAM_BLUE

    ; Spawn at blue base with slight offset
    mov eax, 500
    add eax, r13d
    shl eax, 4              ; spread minions a bit
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 500
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .blue_melee_done

    ; Set stats
    mov edi, eax
    mov esi, MINION_MELEE_HP
    xor edx, edx
    mov ecx, MINION_MELEE_AD
    mov r8d, MINION_MELEE_RANGE
    mov r9d, MINION_MELEE_SPEED
    push qword 80           ; atk_speed
    call entity_set_stats
    add rsp, 8

    ; Set lane
    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1         ; mid lane

    dec r13d
    jmp .blue_melee_loop
.blue_melee_done:
    pop r13
    ret

.spawn_wave_for_team_red:
    push r13
    mov r13d, MINIONS_PER_WAVE
.red_melee_loop:
    test r13d, r13d
    jz .red_melee_done

    mov edi, ENT_MINION_MELEE
    mov esi, TEAM_RED

    ; Spawn at red base
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 500
    sub eax, r13d
    shl eax, 4
    shr eax, 4
    add eax, MAP_PIXEL_WIDTH - 600
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 500
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .red_melee_done

    mov edi, eax
    mov esi, MINION_MELEE_HP
    xor edx, edx
    mov ecx, MINION_MELEE_AD
    mov r8d, MINION_MELEE_RANGE
    mov r9d, MINION_MELEE_SPEED
    push qword 80
    call entity_set_stats
    add rsp, 8

    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1         ; mid lane

    dec r13d
    jmp .red_melee_loop
.red_melee_done:
    pop r13
    ret

; ============================================================================
; game_update_entities - Update movement for all entities
; ============================================================================
game_update_entities:
    push rbx
    push r12
    push r13
    push r14

    mov r14d, [ent_count]
    xor ebx, ebx

.entity_loop:
    cmp ebx, r14d
    jge .entity_done

    ; Skip inactive
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .entity_next

    ; Skip dead
    lea rax, [rel ent_state]
    movzx eax, byte [rax + rbx]
    cmp al, STATE_DEAD
    je .entity_next

    ; Handle movement
    cmp al, STATE_MOVING
    je .do_movement

    ; Handle minion AI
    lea rax, [rel ent_type]
    movzx eax, byte [rax + rbx]
    cmp al, ENT_MINION_MELEE
    je .minion_ai
    cmp al, ENT_MINION_CASTER
    je .minion_ai

    ; Handle tower AI
    cmp al, ENT_TOWER
    je .tower_ai

    jmp .entity_next

.do_movement:
    ; Load current position
    lea rax, [rel ent_x]
    movsd xmm0, [rax + rbx * 8]
    lea rax, [rel ent_y]
    movsd xmm1, [rax + rbx * 8]

    ; Load target
    lea rax, [rel ent_target_x]
    movsd xmm2, [rax + rbx * 8]
    lea rax, [rel ent_target_y]
    movsd xmm3, [rax + rbx * 8]

    ; Calculate speed per frame
    lea rax, [rel ent_speed]
    vcvtsi2sd xmm4, xmm4, dword [rax + rbx * 4]
    vmulsd xmm4, xmm4, [rel speed_scale]   ; speed * (1/60)

    call math_move_toward

    ; Store new position
    lea rcx, [rel ent_x]
    movsd [rcx + rbx * 8], xmm0
    lea rcx, [rel ent_y]
    movsd [rcx + rbx * 8], xmm1

    ; Check if reached target
    test eax, eax
    jz .entity_next
    ; Reached - set to idle
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_IDLE
    jmp .entity_next

.minion_ai:
    ; Simple minion AI: move toward enemy base via waypoints
    ; Find nearest enemy and attack if in range, otherwise keep moving

    ; Check for nearby enemies first
    call .find_nearest_enemy        ; returns r12d = enemy index or -1
    cmp r12d, -1
    je .minion_move_lane

    ; Check if in attack range
    lea rax, [rel ent_x]
    movsd xmm0, [rax + rbx * 8]
    lea rax, [rel ent_y]
    movsd xmm1, [rax + rbx * 8]
    lea rax, [rel ent_x]
    movsd xmm2, [rax + r12 * 8]
    lea rax, [rel ent_y]
    movsd xmm3, [rax + r12 * 8]
    call math_distance

    lea rax, [rel ent_range]
    vcvtsi2sd xmm1, xmm1, dword [rax + rbx * 4]
    vucomisd xmm0, xmm1
    ja .minion_chase_enemy

    ; In range - set attack target
    lea rax, [rel ent_atk_target]
    mov [rax + rbx * 4], r12d
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_ATTACKING
    jmp .entity_next

.minion_chase_enemy:
    ; Move toward enemy
    lea rax, [rel ent_x]
    movsd xmm0, [rax + r12 * 8]
    lea rcx, [rel ent_target_x]
    movsd [rcx + rbx * 8], xmm0
    lea rax, [rel ent_y]
    movsd xmm0, [rax + r12 * 8]
    lea rcx, [rel ent_target_y]
    movsd [rcx + rbx * 8], xmm0
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_MOVING
    jmp .entity_next

.minion_move_lane:
    ; Move toward enemy base along mid lane
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]

    ; Simple: blue minions move toward top-right, red toward bottom-left
    cmp al, TEAM_BLUE
    je .blue_minion_target
    ; Red minion target
    mov eax, 500
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 500
    vcvtsi2sd xmm1, xmm1, eax
    jmp .set_minion_target
.blue_minion_target:
    mov eax, MAP_PIXEL_WIDTH - 500
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 500
    vcvtsi2sd xmm1, xmm1, eax
.set_minion_target:
    lea rcx, [rel ent_target_x]
    movsd [rcx + rbx * 8], xmm0
    lea rcx, [rel ent_target_y]
    movsd [rcx + rbx * 8], xmm1
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_MOVING
    jmp .entity_next

.tower_ai:
    ; Tower AI: attack nearest enemy in range
    call .find_nearest_enemy
    cmp r12d, -1
    je .entity_next

    ; Check range
    lea rax, [rel ent_x]
    movsd xmm0, [rax + rbx * 8]
    lea rax, [rel ent_y]
    movsd xmm1, [rax + rbx * 8]
    lea rax, [rel ent_x]
    movsd xmm2, [rax + r12 * 8]
    lea rax, [rel ent_y]
    movsd xmm3, [rax + r12 * 8]
    call math_distance

    lea rax, [rel ent_range]
    vcvtsi2sd xmm1, xmm1, dword [rax + rbx * 4]
    vucomisd xmm0, xmm1
    ja .entity_next         ; out of range

    ; Set attack target
    lea rax, [rel ent_atk_target]
    mov [rax + rbx * 4], r12d
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_ATTACKING

.entity_next:
    inc ebx
    jmp .entity_loop

.entity_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Helper: find nearest enemy to entity ebx ---
; Returns: r12d = nearest enemy index, -1 if none found
.find_nearest_enemy:
    push r13
    push r14
    push r15

    mov r12d, -1            ; best index
    mov r15d, 0x7FFFFFFF    ; best distance squared (max int)

    lea rax, [rel ent_team]
    movzx r13d, byte [rax + rbx]    ; my team

    xor r14d, r14d          ; search index
    mov ecx, [ent_count]

.search_enemy:
    cmp r14d, ecx
    jge .search_done

    ; Skip self
    cmp r14d, ebx
    je .search_next

    ; Skip inactive
    lea rax, [rel ent_active]
    cmp byte [rax + r14], 0
    je .search_next

    ; Skip dead
    lea rax, [rel ent_state]
    cmp byte [rax + r14], STATE_DEAD
    je .search_next

    ; Skip same team
    lea rax, [rel ent_team]
    cmp byte [rax + r14], r13b
    je .search_next

    ; Calculate distance squared (integer approximation for speed)
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + rbx * 8]
    lea rdx, [rel ent_x]
    vcvttsd2si edx, [rdx + r14 * 8]
    sub eax, edx
    imul eax, eax

    push rax
    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + rbx * 8]
    lea rdx, [rel ent_y]
    vcvttsd2si edx, [rdx + r14 * 8]
    sub eax, edx
    imul eax, eax
    mov edx, eax
    pop rax
    add eax, edx            ; dist^2

    ; Only consider within 600 pixel radius
    cmp eax, 360000         ; 600^2
    jg .search_next

    cmp eax, r15d
    jge .search_next
    mov r15d, eax
    mov r12d, r14d

.search_next:
    inc r14d
    jmp .search_enemy

.search_done:
    pop r15
    pop r14
    pop r13
    ret

; ============================================================================
; game_process_combat - Process attacks for all attacking entities
; ============================================================================
game_process_combat:
    push rbx
    push r12

    mov r12d, [ent_count]
    xor ebx, ebx

.combat_loop:
    cmp ebx, r12d
    jge .combat_done

    ; Only process attacking entities
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_ATTACKING
    jne .combat_next

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .combat_next

    ; Decrease cooldown
    lea rax, [rel ent_atk_cooldown]
    mov ecx, [rax + rbx * 4]
    test ecx, ecx
    jz .can_attack
    dec ecx
    mov [rax + rbx * 4], ecx
    jmp .combat_next

.can_attack:
    ; Get attack target
    lea rax, [rel ent_atk_target]
    mov ecx, [rax + rbx * 4]
    cmp ecx, -1
    je .stop_attacking
    cmp ecx, MAX_ENTITIES
    jge .stop_attacking

    ; Check target is still alive
    lea rax, [rel ent_active]
    cmp byte [rax + rcx], 0
    je .stop_attacking
    lea rax, [rel ent_state]
    cmp byte [rax + rcx], STATE_DEAD
    je .stop_attacking

    ; Deal damage
    lea rax, [rel ent_atk]
    mov edx, [rax + rbx * 4]   ; my attack damage

    lea rax, [rel ent_hp]
    sub [rax + rcx * 4], edx    ; target_hp -= my_damage

    ; Check if target died
    cmp dword [rax + rcx * 4], 0
    jg .set_cooldown

    ; Target died!
    mov dword [rax + rcx * 4], 0
    push rcx
    mov edi, ecx
    call entity_kill
    pop rcx

    ; Award gold to player if player killed it or it's a minion
    cmp ebx, PLAYER_ID
    jne .no_gold_award
    lea rax, [rel ent_type]
    movzx eax, byte [rax + rcx]
    cmp al, ENT_MINION_MELEE
    je .award_minion_gold
    cmp al, ENT_MINION_CASTER
    je .award_minion_gold
    cmp al, ENT_TOWER
    je .award_tower_gold
    cmp al, ENT_CHAMPION
    je .award_champion_gold
    jmp .stop_attacking

.award_minion_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_MINION
    jmp .stop_attacking
.award_tower_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_TOWER
    jmp .stop_attacking
.award_champion_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_CHAMPION
    jmp .stop_attacking

.no_gold_award:
.stop_attacking:
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_IDLE
    lea rax, [rel ent_atk_target]
    mov dword [rax + rbx * 4], -1
    jmp .combat_next

.set_cooldown:
    ; Set attack cooldown: 60 / (atk_speed / 100)
    lea rax, [rel ent_atk_speed]
    mov ecx, [rax + rbx * 4]
    test ecx, ecx
    jz .combat_next
    mov eax, 6000           ; 60 * 100
    xor edx, edx
    div ecx                 ; 6000 / atk_speed
    lea rcx, [rel ent_atk_cooldown]
    mov [rcx + rbx * 4], eax

.combat_next:
    inc ebx
    jmp .combat_loop

.combat_done:
    pop r12
    pop rbx
    ret

; ============================================================================
; game_process_respawns - Handle dead entity respawns
; ============================================================================
game_process_respawns:
    push rbx
    push r12

    mov r12d, [ent_count]
    xor ebx, ebx

.respawn_loop:
    cmp ebx, r12d
    jge .respawn_done

    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    jne .respawn_next

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .respawn_next

    ; Increment respawn timer
    lea rax, [rel ent_respawn_timer]
    inc dword [rax + rbx * 4]

    ; Check entity type for respawn behavior
    lea rax, [rel ent_type]
    movzx eax, byte [rax + rbx]

    cmp al, ENT_CHAMPION
    je .respawn_champion
    cmp al, ENT_MINION_MELEE
    je .respawn_minion
    cmp al, ENT_MINION_CASTER
    je .respawn_minion
    jmp .respawn_next       ; towers don't respawn

.respawn_champion:
    lea rax, [rel ent_respawn_timer]
    cmp dword [rax + rbx * 4], CHAMPION_RESPAWN
    jl .respawn_next

    ; Respawn at base
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]
    cmp al, TEAM_BLUE
    je .respawn_blue_base
    ; Red base
    mov eax, MAP_PIXEL_WIDTH - 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 400
    jmp .do_respawn
.respawn_blue_base:
    mov eax, 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 400
.do_respawn:
    vcvtsi2sd xmm1, xmm1, eax
    lea rax, [rel ent_x]
    movsd [rax + rbx * 8], xmm0
    lea rax, [rel ent_y]
    movsd [rax + rbx * 8], xmm1
    lea rax, [rel ent_target_x]
    movsd [rax + rbx * 8], xmm0
    lea rax, [rel ent_target_y]
    movsd [rax + rbx * 8], xmm1

    ; Restore HP/mana
    lea rax, [rel ent_max_hp]
    mov ecx, [rax + rbx * 4]
    lea rax, [rel ent_hp]
    mov [rax + rbx * 4], ecx
    lea rax, [rel ent_max_mana]
    mov ecx, [rax + rbx * 4]
    lea rax, [rel ent_mana]
    mov [rax + rbx * 4], ecx

    ; Reset state
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_IDLE
    lea rax, [rel ent_respawn_timer]
    mov dword [rax + rbx * 4], 0
    lea rax, [rel ent_atk_target]
    mov dword [rax + rbx * 4], -1
    jmp .respawn_next

.respawn_minion:
    ; Minions don't respawn, just deactivate after a delay
    lea rax, [rel ent_respawn_timer]
    cmp dword [rax + rbx * 4], 120  ; 2 seconds
    jl .respawn_next
    mov edi, ebx
    call entity_deactivate

.respawn_next:
    inc ebx
    jmp .respawn_loop

.respawn_done:
    pop r12
    pop rbx
    ret
