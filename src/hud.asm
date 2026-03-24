; ============================================================================
; hud.asm - Heads-Up Display rendering
; Health bars, mana, gold, minimap, game info
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern render_rect, render_circle, render_string, render_number, render_char
extern camera_x, camera_y
extern game_time, game_frame

; Entity data
extern ent_x, ent_y, ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_type, ent_team, ent_state, ent_active, ent_gold, ent_level
extern ent_count

; Data
extern str_hp, str_mana, str_gold, str_level, str_fps, str_time
extern str_slash, str_colon
extern entity_radius_table, entity_color_table

; Map
extern map_tiles

section .data

section .bss

; FPS tracking
global fps_counter, fps_display, fps_frame_count
fps_counter:        resd 1
fps_display:        resd 1
fps_frame_count:    resd 1

section .text

; ============================================================================
; hud_render_entity_bars - Render HP bars above all visible entities
; ============================================================================
global hud_render_entity_bars
hud_render_entity_bars:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r15d, [ent_count]
    xor ebx, ebx

.bar_loop:
    cmp ebx, r15d
    jge .bar_done

    ; Skip inactive/dead
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .bar_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .bar_next

    ; Get screen position
    lea rax, [rel ent_x]
    vcvttsd2si r12d, [rax + rbx * 8]
    sub r12d, [camera_x]        ; screen_x

    lea rax, [rel ent_y]
    vcvttsd2si r13d, [rax + rbx * 8]
    sub r13d, [camera_y]        ; screen_y

    ; Skip if off screen
    cmp r12d, -HP_BAR_WIDTH
    jl .bar_next
    cmp r12d, WINDOW_WIDTH + HP_BAR_WIDTH
    jg .bar_next
    cmp r13d, -HP_BAR_OFFSET
    jl .bar_next
    cmp r13d, HUD_Y
    jg .bar_next

    ; Calculate HP bar position (centered above entity)
    mov r14d, r12d
    sub r14d, HP_BAR_WIDTH / 2  ; bar_x

    mov eax, r13d
    sub eax, HP_BAR_OFFSET      ; bar_y

    ; Draw HP bar background (dark)
    mov edi, r14d
    mov esi, eax
    mov edx, HP_BAR_WIDTH
    mov ecx, HP_BAR_HEIGHT
    mov r8d, COLOR_BLACK
    push rax
    call render_rect
    pop rax

    ; Calculate HP fill width
    lea rcx, [rel ent_hp]
    mov ecx, [rcx + rbx * 4]
    lea rdx, [rel ent_max_hp]
    mov edx, [rdx + rbx * 4]
    test edx, edx
    jz .bar_next

    ; width = (hp * HP_BAR_WIDTH) / max_hp
    imul ecx, HP_BAR_WIDTH
    xor edx, edx
    push rax
    lea rax, [rel ent_max_hp]
    mov eax, [rax + rbx * 4]
    xchg eax, ecx
    div ecx                     ; eax = fill width
    pop rcx                     ; restore bar_y

    ; Clamp fill width
    cmp eax, HP_BAR_WIDTH
    jle .hp_no_clamp
    mov eax, HP_BAR_WIDTH
.hp_no_clamp:
    test eax, eax
    jz .bar_next

    ; Choose color based on team
    lea rdx, [rel ent_team]
    movzx edx, byte [rdx + rbx]
    cmp dl, TEAM_BLUE
    je .hp_blue
    mov r8d, COLOR_HP_RED
    jmp .hp_draw
.hp_blue:
    mov r8d, COLOR_HP_GREEN
.hp_draw:
    mov edi, r14d
    mov esi, ecx            ; bar_y
    mov edx, eax            ; fill width
    mov ecx, HP_BAR_HEIGHT
    call render_rect

.bar_next:
    inc ebx
    jmp .bar_loop

.bar_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; hud_render_entities - Render all visible entities as colored shapes
; ============================================================================
global hud_render_entities
hud_render_entities:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r15d, [ent_count]
    xor ebx, ebx

.ent_loop:
    cmp ebx, r15d
    jge .ent_done

    ; Skip inactive/dead
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .ent_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .ent_next

    ; Get screen position
    lea rax, [rel ent_x]
    vcvttsd2si r12d, [rax + rbx * 8]
    sub r12d, [camera_x]

    lea rax, [rel ent_y]
    vcvttsd2si r13d, [rax + rbx * 8]
    sub r13d, [camera_y]

    ; Skip if off screen (with margin)
    cmp r12d, -30
    jl .ent_next
    cmp r12d, WINDOW_WIDTH + 30
    jg .ent_next
    cmp r13d, -30
    jl .ent_next
    cmp r13d, HUD_Y + 30
    jg .ent_next

    ; Get entity type and team
    lea rax, [rel ent_type]
    movzx r14d, byte [rax + rbx]
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]

    ; Get radius
    lea rcx, [rel entity_radius_table]
    mov edx, [rcx + r14 * 4]

    ; Get color
    mov ecx, r14d
    shl ecx, 1
    add ecx, eax
    lea rax, [rel entity_color_table]
    mov ecx, [rax + rcx * 4]

    ; Draw entity as circle
    mov edi, r12d
    mov esi, r13d
    ; edx = radius (already set)
    ; ecx = color (already set)
    call render_circle

    ; Draw tower differently (square outline on top of circle)
    cmp r14d, ENT_TOWER
    jne .ent_next
    mov edi, r12d
    sub edi, TOWER_RADIUS + 2
    mov esi, r13d
    sub esi, TOWER_RADIUS + 2
    mov edx, (TOWER_RADIUS + 2) * 2
    mov ecx, 2              ; height = 2 (top line)
    mov r8d, COLOR_WHITE
    call render_rect

.ent_next:
    inc ebx
    jmp .ent_loop

.ent_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; hud_render_panel - Render the HUD panel at bottom of screen
; ============================================================================
global hud_render_panel
hud_render_panel:
    push rbx

    ; Draw HUD background
    mov edi, 0
    mov esi, HUD_Y
    mov edx, WINDOW_WIDTH
    mov ecx, HUD_HEIGHT
    mov r8d, COLOR_HUD_BG
    call render_rect

    ; Draw HUD top border
    mov edi, 0
    mov esi, HUD_Y
    mov edx, WINDOW_WIDTH
    mov ecx, 2
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; --- Player stats ---
    ; HP label
    lea rdi, [rel str_hp]
    mov esi, 20
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_string

    ; HP value
    lea rax, [rel ent_hp]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, 50
    mov edx, HUD_Y + 10
    mov ecx, COLOR_HP_GREEN
    call render_number

    ; HP separator "/"
    lea rdi, [rel str_slash]
    mov esi, 100
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_string

    ; Max HP value
    lea rax, [rel ent_max_hp]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, 110
    mov edx, HUD_Y + 10
    mov ecx, COLOR_HP_GREEN
    call render_number

    ; HP bar (wide bar on HUD)
    mov edi, 20
    mov esi, HUD_Y + 22
    mov edx, 200
    mov ecx, 10
    mov r8d, COLOR_BLACK
    call render_rect

    ; HP fill
    lea rax, [rel ent_hp]
    mov eax, [rax + PLAYER_ID * 4]
    lea rcx, [rel ent_max_hp]
    mov ecx, [rcx + PLAYER_ID * 4]
    test ecx, ecx
    jz .skip_hp_bar
    imul eax, 200
    xor edx, edx
    div ecx
    mov edi, 20
    mov esi, HUD_Y + 22
    mov edx, eax
    mov ecx, 10
    mov r8d, COLOR_HP_GREEN
    call render_rect
.skip_hp_bar:

    ; Mana label
    lea rdi, [rel str_mana]
    mov esi, 20
    mov edx, HUD_Y + 38
    mov ecx, COLOR_WHITE
    call render_string

    ; Mana value
    lea rax, [rel ent_mana]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, 60
    mov edx, HUD_Y + 38
    mov ecx, COLOR_MANA_BLUE
    call render_number

    ; Mana bar
    mov edi, 20
    mov esi, HUD_Y + 50
    mov edx, 200
    mov ecx, 10
    mov r8d, COLOR_BLACK
    call render_rect

    lea rax, [rel ent_mana]
    mov eax, [rax + PLAYER_ID * 4]
    lea rcx, [rel ent_max_mana]
    mov ecx, [rcx + PLAYER_ID * 4]
    test ecx, ecx
    jz .skip_mana_bar
    imul eax, 200
    xor edx, edx
    div ecx
    mov edi, 20
    mov esi, HUD_Y + 50
    mov edx, eax
    mov ecx, 10
    mov r8d, COLOR_MANA_BLUE
    call render_rect
.skip_mana_bar:

    ; Gold
    lea rdi, [rel str_gold]
    mov esi, 250
    mov edx, HUD_Y + 10
    mov ecx, COLOR_GOLD
    call render_string

    lea rax, [rel ent_gold]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, 300
    mov edx, HUD_Y + 10
    mov ecx, COLOR_GOLD
    call render_number

    ; Level
    lea rdi, [rel str_level]
    mov esi, 250
    mov edx, HUD_Y + 30
    mov ecx, COLOR_WHITE
    call render_string

    lea rax, [rel ent_level]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, 290
    mov edx, HUD_Y + 30
    mov ecx, COLOR_WHITE
    call render_number

    ; Game time
    lea rdi, [rel str_time]
    mov esi, 400
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_string

    ; Minutes
    mov eax, [game_time]
    xor edx, edx
    mov ecx, 60
    div ecx
    push rdx                ; save seconds
    mov edi, eax
    mov esi, 445
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_number

    lea rdi, [rel str_colon]
    mov esi, 465
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_string

    ; Seconds
    pop rdi
    mov esi, 475
    mov edx, HUD_Y + 10
    mov ecx, COLOR_WHITE
    call render_number

    ; --- Minimap ---
    call hud_render_minimap

    pop rbx
    ret

; ============================================================================
; hud_render_minimap - Render minimap in bottom-right corner
; ============================================================================
hud_render_minimap:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Minimap background
    mov edi, MINIMAP_X - 2
    mov esi, MINIMAP_Y - 2
    mov edx, MINIMAP_SIZE + 4
    mov ecx, MINIMAP_SIZE + 4
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    mov edi, MINIMAP_X
    mov esi, MINIMAP_Y
    mov edx, MINIMAP_SIZE
    mov ecx, MINIMAP_SIZE
    mov r8d, COLOR_MINIMAP_BG
    call render_rect

    ; Scale factor: MINIMAP_SIZE / MAP_PIXEL_SIZE
    ; We'll use integer arithmetic: pos * MINIMAP_SIZE / MAP_PIXEL_WIDTH

    ; Draw entities on minimap
    mov r15d, [ent_count]
    xor ebx, ebx

.mini_loop:
    cmp ebx, r15d
    jge .mini_done

    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .mini_next
    lea rax, [rel ent_state]
    cmp byte [rax + rbx], STATE_DEAD
    je .mini_next

    ; Convert world pos to minimap pos
    lea rax, [rel ent_x]
    vcvttsd2si r12d, [rax + rbx * 8]
    imul r12d, MINIMAP_SIZE
    mov eax, r12d
    xor edx, edx
    mov ecx, MAP_PIXEL_WIDTH
    div ecx
    add eax, MINIMAP_X
    mov r12d, eax           ; minimap_x

    lea rax, [rel ent_y]
    vcvttsd2si r13d, [rax + rbx * 8]
    imul r13d, MINIMAP_SIZE
    mov eax, r13d
    xor edx, edx
    mov ecx, MAP_PIXEL_HEIGHT
    div ecx
    add eax, MINIMAP_Y
    mov r13d, eax           ; minimap_y

    ; Get color based on team
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]
    cmp al, TEAM_BLUE
    je .mini_blue
    mov r8d, COLOR_RED_TEAM
    jmp .mini_draw
.mini_blue:
    mov r8d, COLOR_BLUE_TEAM
.mini_draw:
    ; Draw as small rect (3x3 for champions/towers, 2x2 for minions)
    lea rax, [rel ent_type]
    movzx eax, byte [rax + rbx]
    cmp al, ENT_MINION_MELEE
    je .mini_small
    cmp al, ENT_MINION_CASTER
    je .mini_small
    ; Large dot
    mov edi, r12d
    sub edi, 1
    mov esi, r13d
    sub esi, 1
    mov edx, 3
    mov ecx, 3
    call render_rect
    jmp .mini_next
.mini_small:
    mov edi, r12d
    mov esi, r13d
    mov edx, 2
    mov ecx, 2
    call render_rect

.mini_next:
    inc ebx
    jmp .mini_loop

.mini_done:
    ; Draw camera viewport indicator on minimap
    mov eax, [camera_x]
    imul eax, MINIMAP_SIZE
    xor edx, edx
    mov ecx, MAP_PIXEL_WIDTH
    div ecx
    add eax, MINIMAP_X
    mov r12d, eax           ; viewport_x

    mov eax, [camera_y]
    imul eax, MINIMAP_SIZE
    xor edx, edx
    mov ecx, MAP_PIXEL_HEIGHT
    div ecx
    add eax, MINIMAP_Y
    mov r13d, eax           ; viewport_y

    ; Viewport size on minimap
    mov eax, WINDOW_WIDTH
    imul eax, MINIMAP_SIZE
    xor edx, edx
    mov ecx, MAP_PIXEL_WIDTH
    div ecx
    mov r14d, eax           ; viewport_w

    mov eax, WINDOW_HEIGHT
    imul eax, MINIMAP_SIZE
    xor edx, edx
    mov ecx, MAP_PIXEL_HEIGHT
    div ecx
    mov r15d, eax           ; viewport_h

    ; Draw viewport rectangle (outline only - 4 lines)
    ; Top
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, 1
    mov r8d, COLOR_WHITE
    call render_rect
    ; Bottom
    mov edi, r12d
    mov esi, r13d
    add esi, r15d
    mov edx, r14d
    mov ecx, 1
    mov r8d, COLOR_WHITE
    call render_rect
    ; Left
    mov edi, r12d
    mov esi, r13d
    mov edx, 1
    mov ecx, r15d
    mov r8d, COLOR_WHITE
    call render_rect
    ; Right
    mov edi, r12d
    add edi, r14d
    mov esi, r13d
    mov edx, 1
    mov ecx, r15d
    mov r8d, COLOR_WHITE
    call render_rect

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; hud_update_fps - Track FPS (call once per frame)
; ============================================================================
global hud_update_fps
hud_update_fps:
    inc dword [fps_frame_count]
    inc dword [fps_counter]

    ; Update display every 60 frames
    cmp dword [fps_counter], 60
    jl .no_fps_update

    mov eax, [fps_counter]
    mov [fps_display], eax
    mov dword [fps_counter], 0
.no_fps_update:
    ret
