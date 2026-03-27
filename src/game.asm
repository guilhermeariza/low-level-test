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
extern menu_set_victory, menu_set_defeat, game_state

; Input
extern mouse_x, mouse_y, mouse_clicked_left, mouse_clicked_right
extern mouse_click_x, mouse_click_y
extern key_pressed, key_state

; Math
extern math_distance, math_distance_sq, math_move_toward
extern math_int_to_double

; Abilities
extern abilities_cast, abilities_level_up

; Items
extern items_buy

; Summoner spells
extern summ_cast

; Combat
extern combat_apply_damage

; HUD stats
extern player_kills, player_deaths, player_assists, player_cs

; Effects
extern effects_spawn_attack_line, effects_spawn_death, effects_spawn_damage_num

; UI kill feed
extern ui_add_kill_feed

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
global wave_timer, wave_count
wave_timer:     resd 1          ; frames until next wave
wave_count:     resd 1          ; number of waves spawned

; Recall timer per entity
global ent_recall_timer
ent_recall_timer: resd MAX_ENTITIES

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

    ; --- Spawn Nexus ---
    call .spawn_blue_nexus
    call .spawn_red_nexus

    ; --- Spawn Inhibitors ---
    call .spawn_blue_inhib_top
    call .spawn_blue_inhib_mid
    call .spawn_blue_inhib_bot
    call .spawn_red_inhib_top
    call .spawn_red_inhib_mid
    call .spawn_red_inhib_bot

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

; Nexus spawn helpers
.spawn_blue_nexus:
    mov edi, ENT_NEXUS
    mov esi, TEAM_BLUE
    mov eax, 200
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 200
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, NEXUS_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_nexus:
    mov edi, ENT_NEXUS
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 200
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 200
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, NEXUS_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

; Inhibitor spawn helpers
.spawn_blue_inhib_top:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_BLUE
    mov eax, 300
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT / 2 - 500
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_blue_inhib_mid:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_BLUE
    mov eax, 800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_blue_inhib_bot:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_BLUE
    mov eax, MAP_PIXEL_WIDTH / 2 - 500
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 300
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_inhib_top:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH / 2 + 500
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 300
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_inhib_mid:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 800
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 800
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
    call entity_set_stats
    add rsp, 8
    ret

.spawn_red_inhib_bot:
    mov edi, ENT_INHIBITOR
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 300
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT / 2 + 500
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    mov edi, eax
    mov esi, INHIBITOR_HP
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    push qword 0
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

    ; --- Check win/loss condition ---
    call game_check_win_condition

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

    ; --- Ability keys Q/W/E/R ---
    lea rax, [rel key_pressed]

    ; Q ability (slot 1)
    cmp byte [rax + KEY_Q], 0
    je .no_key_q
    mov edi, PLAYER_ID
    mov esi, SLOT_Q
    mov edx, -1             ; no target for now (self/auto)
    call abilities_cast
.no_key_q:

    lea rax, [rel key_pressed]
    ; W ability (slot 2)
    cmp byte [rax + KEY_W], 0
    je .no_key_w
    mov edi, PLAYER_ID
    mov esi, SLOT_W
    mov edx, -1
    call abilities_cast
.no_key_w:

    lea rax, [rel key_pressed]
    ; E ability (slot 3)
    cmp byte [rax + KEY_E], 0
    je .no_key_e
    mov edi, PLAYER_ID
    mov esi, SLOT_E
    mov edx, -1
    call abilities_cast
.no_key_e:

    lea rax, [rel key_pressed]
    ; R ability (slot 4)
    cmp byte [rax + KEY_R], 0
    je .no_key_r
    mov edi, PLAYER_ID
    mov esi, SLOT_R
    mov edx, -1
    call abilities_cast
.no_key_r:

    ; --- Summoner spells D/F ---
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_D], 0
    je .no_key_d
    mov edi, PLAYER_ID
    mov esi, 0              ; spell slot 1
    mov edx, -1
    call summ_cast
.no_key_d:

    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_F], 0
    je .no_key_f
    mov edi, PLAYER_ID
    mov esi, 1              ; spell slot 2
    mov edx, -1
    call summ_cast
.no_key_f:

    ; --- Recall (B key) ---
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_B], 0
    je .no_key_b
    lea rax, [rel ent_state]
    mov byte [rax + PLAYER_ID], STATE_RECALLING
.no_key_b:

    ; --- Stop (S key) ---
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_S], 0
    je .no_key_s
    lea rax, [rel ent_state]
    mov byte [rax + PLAYER_ID], STATE_IDLE
    lea rax, [rel ent_atk_target]
    mov dword [rax + PLAYER_ID * 4], -1
.no_key_s:

    ; --- Ctrl+QWER: Level up abilities ---
    lea rax, [rel key_state]
    cmp byte [rax + KEY_CTRL_L], 0
    je .no_ctrl_skills

    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_Q], 0
    je .no_ctrl_q
    mov edi, PLAYER_ID
    mov esi, SLOT_Q
    call abilities_level_up
.no_ctrl_q:
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_W], 0
    je .no_ctrl_w
    mov edi, PLAYER_ID
    mov esi, SLOT_W
    call abilities_level_up
.no_ctrl_w:
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_E], 0
    je .no_ctrl_e
    mov edi, PLAYER_ID
    mov esi, SLOT_E
    call abilities_level_up
.no_ctrl_e:
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_R], 0
    je .no_ctrl_r
    mov edi, PLAYER_ID
    mov esi, SLOT_R
    call abilities_level_up
.no_ctrl_r:
.no_ctrl_skills:

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

    ; Increment wave count
    inc dword [wave_count]

    ; Spawn blue team minions (mid lane)
    mov r12d, 0             ; lane = mid
    call .spawn_wave_for_team_blue
    call .spawn_casters_for_team_blue
    call .spawn_wave_for_team_red
    call .spawn_casters_for_team_red

    ; Every 3rd wave, spawn cannon minions
    mov eax, [wave_count]
    xor edx, edx
    mov ecx, 3
    div ecx
    test edx, edx
    jnz .no_spawn

    call .spawn_cannon_blue
    call .spawn_cannon_red

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

.spawn_casters_for_team_blue:
    push r13
    mov r13d, 3             ; 3 caster minions
.blue_caster_loop:
    test r13d, r13d
    jz .blue_caster_done
    mov edi, ENT_MINION_CASTER
    mov esi, TEAM_BLUE
    mov eax, 560
    add eax, r13d
    shl eax, 4
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 520
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .blue_caster_done
    mov edi, eax
    mov esi, MINION_CASTER_HP
    xor edx, edx
    mov ecx, MINION_CASTER_AD
    mov r8d, MINION_CASTER_RANGE
    mov r9d, MINION_CASTER_SPEED
    push qword 70
    call entity_set_stats
    add rsp, 8
    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1
    dec r13d
    jmp .blue_caster_loop
.blue_caster_done:
    pop r13
    ret

.spawn_casters_for_team_red:
    push r13
    mov r13d, 3
.red_caster_loop:
    test r13d, r13d
    jz .red_caster_done
    mov edi, ENT_MINION_CASTER
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 560
    sub eax, r13d
    shl eax, 4
    shr eax, 4
    add eax, MAP_PIXEL_WIDTH - 620
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 520
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .red_caster_done
    mov edi, eax
    mov esi, MINION_CASTER_HP
    xor edx, edx
    mov ecx, MINION_CASTER_AD
    mov r8d, MINION_CASTER_RANGE
    mov r9d, MINION_CASTER_SPEED
    push qword 70
    call entity_set_stats
    add rsp, 8
    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1
    dec r13d
    jmp .red_caster_loop
.red_caster_done:
    pop r13
    ret

.spawn_cannon_blue:
    mov edi, ENT_MINION_CANNON
    mov esi, TEAM_BLUE
    mov eax, 530
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 540
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .cannon_blue_done
    mov edi, eax
    mov esi, MINION_CANNON_HP
    xor edx, edx
    mov ecx, MINION_CANNON_AD
    mov r8d, MINION_CANNON_RANGE
    mov r9d, MINION_CANNON_SPEED
    push qword 60
    call entity_set_stats
    add rsp, 8
    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1
.cannon_blue_done:
    ret

.spawn_cannon_red:
    mov edi, ENT_MINION_CANNON
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH - 530
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 540
    vcvtsi2sd xmm1, xmm1, eax
    call entity_spawn
    cmp eax, -1
    je .cannon_red_done
    mov edi, eax
    mov esi, MINION_CANNON_HP
    xor edx, edx
    mov ecx, MINION_CANNON_AD
    mov r8d, MINION_CANNON_RANGE
    mov r9d, MINION_CANNON_SPEED
    push qword 60
    call entity_set_stats
    add rsp, 8
    lea rax, [rel ent_lane]
    mov byte [rax + rdi], 1
.cannon_red_done:
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

    ; Handle recall channeling
    cmp al, STATE_RECALLING
    je .do_recall

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
    cmp al, ENT_MINION_CANNON
    je .minion_ai
    cmp al, ENT_MINION_SUPER
    je .minion_ai

    ; Handle tower AI
    cmp al, ENT_TOWER
    je .tower_ai

    jmp .entity_next

.do_recall:
    ; Increment recall timer
    lea rax, [rel ent_recall_timer]
    inc dword [rax + rbx * 4]
    cmp dword [rax + rbx * 4], RECALL_CHANNEL_TIME
    jl .entity_next

    ; Recall complete - teleport to base
    mov dword [rax + rbx * 4], 0
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]
    cmp al, TEAM_BLUE
    je .recall_blue
    ; Red base
    mov eax, MAP_PIXEL_WIDTH - 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, 400
    jmp .recall_set_pos
.recall_blue:
    mov eax, 400
    vcvtsi2sd xmm0, xmm0, eax
    mov eax, MAP_PIXEL_HEIGHT - 400
.recall_set_pos:
    vcvtsi2sd xmm1, xmm1, eax
    lea rax, [rel ent_x]
    movsd [rax + rbx * 8], xmm0
    lea rax, [rel ent_y]
    movsd [rax + rbx * 8], xmm1
    lea rax, [rel ent_target_x]
    movsd [rax + rbx * 8], xmm0
    lea rax, [rel ent_target_y]
    movsd [rax + rbx * 8], xmm1
    ; Heal to full
    lea rax, [rel ent_max_hp]
    mov ecx, [rax + rbx * 4]
    lea rax, [rel ent_hp]
    mov [rax + rbx * 4], ecx
    lea rax, [rel ent_max_mana]
    mov ecx, [rax + rbx * 4]
    lea rax, [rel ent_mana]
    mov [rax + rbx * 4], ecx
    lea rax, [rel ent_state]
    mov byte [rax + rbx], STATE_IDLE
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

    ; Spawn attack line effect: attacker pos → target pos
    push rbx
    push rcx
    push rdx
    lea rax, [rel ent_x]
    vcvtsd2si edi, [rax + rbx * 8]     ; attacker x (int)
    lea rax, [rel ent_y]
    vcvtsd2si esi, [rax + rbx * 8]     ; attacker y
    lea rax, [rel ent_x]
    vcvtsd2si edx, [rax + rcx * 8]     ; target x
    lea rax, [rel ent_y]
    vcvtsd2si ecx, [rax + rcx * 8]     ; target y
    mov r8d, 0xFFFF00                  ; yellow color
    call effects_spawn_attack_line
    pop rdx
    pop rcx
    pop rbx

    ; Spawn floating damage number at target position
    push rbx
    push rcx
    push rdx
    lea rax, [rel ent_x]
    vcvtsd2si edi, [rax + rcx * 8]
    lea rax, [rel ent_y]
    vcvtsd2si esi, [rax + rcx * 8]
    mov edx, [rsp + 8]                 ; damage value (original edx on stack)
    mov ecx, 0xFFFFFF                  ; white
    call effects_spawn_damage_num
    pop rdx
    pop rcx
    pop rbx

    ; Check if target died
    lea rax, [rel ent_hp]
    cmp dword [rax + rcx * 4], 0
    jg .set_cooldown

    ; Target died!
    mov dword [rax + rcx * 4], 0

    ; Spawn death particles at target position
    push rbx
    push rcx
    lea rax, [rel ent_x]
    vcvtsd2si edi, [rax + rcx * 8]
    lea rax, [rel ent_y]
    vcvtsd2si esi, [rax + rcx * 8]
    mov edx, 0xFF4400                  ; orange-red death color
    call effects_spawn_death
    pop rcx
    pop rbx

    ; Add kill feed entry (killer=rbx, victim=rcx)
    push rbx
    push rcx
    mov edi, ebx
    mov esi, ecx
    call ui_add_kill_feed
    pop rcx
    pop rbx

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
    je .award_caster_gold
    cmp al, ENT_MINION_CANNON
    je .award_cannon_gold
    cmp al, ENT_TOWER
    je .award_tower_gold
    cmp al, ENT_CHAMPION
    je .award_champion_gold
    jmp .stop_attacking

.award_minion_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_MINION
    inc dword [player_cs]
    jmp .stop_attacking
.award_caster_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_MINION_CASTER
    inc dword [player_cs]
    jmp .stop_attacking
.award_cannon_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_MINION_CANNON
    inc dword [player_cs]
    jmp .stop_attacking
.award_tower_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_TOWER
    jmp .stop_attacking
.award_champion_gold:
    lea rax, [rel ent_gold]
    add dword [rax + PLAYER_ID * 4], GOLD_PER_CHAMPION
    inc dword [player_kills]
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
    cmp al, ENT_MINION_CANNON
    je .respawn_minion
    cmp al, ENT_MINION_SUPER
    je .respawn_minion
    jmp .respawn_next       ; towers/nexus/inhib don't respawn via timer

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

; ============================================================================
; game_check_win_condition - Check if a Nexus has been destroyed
; ============================================================================
game_check_win_condition:
    push rbx
    push r12

    mov r12d, [ent_count]
    xor ebx, ebx

.win_loop:
    cmp ebx, r12d
    jge .win_done

    ; Only check Nexus entities
    lea rax, [rel ent_type]
    cmp byte [rax + rbx], ENT_NEXUS
    jne .win_next

    ; Check if dead or inactive
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .nexus_dead
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .nexus_dead
    jmp .win_next

.nexus_dead:
    ; Which team's nexus died?
    lea rax, [rel ent_team]
    cmp byte [rax + rbx], TEAM_BLUE
    je .blue_nexus_dead
    cmp byte [rax + rbx], TEAM_RED
    je .red_nexus_dead
    jmp .win_next

.blue_nexus_dead:
    ; Blue nexus destroyed = defeat
    call menu_set_defeat
    mov dword [game_state], GAMESTATE_DEFEAT
    jmp .win_done

.red_nexus_dead:
    ; Red nexus destroyed = victory
    call menu_set_victory
    mov dword [game_state], GAMESTATE_VICTORY
    jmp .win_done

.win_next:
    inc ebx
    jmp .win_loop

.win_done:
    pop r12
    pop rbx
    ret
