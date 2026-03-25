; ============================================================================
; menu.asm - Menu system, champion select, game state management
; Tasks 13.01-13.10: Main menu, champion select, pause, settings, replay
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern render_rect, render_string, render_number
extern mouse_x, mouse_y, mouse_clicked_left
extern key_pressed
extern framebuffer

; Game states
%define GAMESTATE_MENU          0
%define GAMESTATE_CHAMP_SELECT  1
%define GAMESTATE_LOADING       2
%define GAMESTATE_PLAYING       3
%define GAMESTATE_PAUSED        4
%define GAMESTATE_VICTORY       5
%define GAMESTATE_DEFEAT        6

; Menu items
%define MENU_PLAY       0
%define MENU_SETTINGS   1
%define MENU_QUIT       2
%define MENU_ITEM_COUNT 3

section .data

; Menu strings
align 8
str_title:      db "LEAGUE OF LEGENDS", 0
str_subtitle:   db "Assembly Edition", 0
str_play:       db "PLAY", 0
str_settings:   db "SETTINGS", 0
str_quit:       db "QUIT", 0
str_loading:    db "LOADING...", 0
str_victory:    db "VICTORY!", 0
str_defeat:     db "DEFEAT", 0
str_press_enter: db "Press ENTER", 0
str_champ_sel:  db "SELECT CHAMPION", 0
str_paused:     db "PAUSED", 0

; Champion names for select screen
champ_names:
    dq str_garen, str_ashe, str_annie, str_zed, str_soraka
    dq str_jinx, str_darius, str_lux, str_yi, str_blitz

str_garen:      db "GAREN", 0
str_ashe:       db "ASHE", 0
str_annie:      db "ANNIE", 0
str_zed:        db "ZED", 0
str_soraka:     db "SORAKA", 0
str_jinx:       db "JINX", 0
str_darius:     db "DARIUS", 0
str_lux:        db "LUX", 0
str_yi:         db "MASTER YI", 0
str_blitz:      db "BLITZCRANK", 0

; Champion select colors
champ_colors:
    dd COLOR_YELLOW         ; Garen
    dd COLOR_CYAN           ; Ashe
    dd COLOR_RED            ; Annie
    dd COLOR_DARK_GRAY      ; Zed
    dd COLOR_GREEN          ; Soraka
    dd COLOR_PINK           ; Jinx
    dd COLOR_DARK_RED       ; Darius
    dd COLOR_LIGHT_GRAY     ; Lux
    dd COLOR_ORANGE         ; Yi
    dd COLOR_YELLOW         ; Blitzcrank

section .bss

; Game state
global game_state, selected_champion, menu_selection
game_state:         resd 1
selected_champion:  resd 1      ; CHAMP_* ID
menu_selection:     resd 1      ; current highlighted menu item

; Loading screen
loading_progress:   resd 1      ; 0-100
loading_timer:      resd 1

; Victory/defeat timer
endgame_timer:      resd 1

section .text

; ============================================================================
; menu_init - Initialize menu system
; ============================================================================
global menu_init
menu_init:
    mov dword [game_state], GAMESTATE_MENU
    mov dword [selected_champion], CHAMP_GAREN
    mov dword [menu_selection], 0
    mov dword [loading_progress], 0
    mov dword [loading_timer], 0
    mov dword [endgame_timer], 0
    ret

; ============================================================================
; menu_update - Update menu logic based on current game state
; Returns: eax = 1 if game should run update, 0 if menu/paused
; ============================================================================
global menu_update
menu_update:
    mov eax, [game_state]

    cmp eax, GAMESTATE_MENU
    je .update_menu
    cmp eax, GAMESTATE_CHAMP_SELECT
    je .update_champ_select
    cmp eax, GAMESTATE_LOADING
    je .update_loading
    cmp eax, GAMESTATE_PLAYING
    je .update_playing
    cmp eax, GAMESTATE_PAUSED
    je .update_paused
    cmp eax, GAMESTATE_VICTORY
    je .update_endgame
    cmp eax, GAMESTATE_DEFEAT
    je .update_endgame

    ; Default: allow game update
    mov eax, 1
    ret

.update_menu:
    ; Up/Down arrow or W/S to navigate (using key codes)
    lea rax, [rel key_pressed]

    ; W = up
    cmp byte [rax + KEY_W], 0
    je .menu_no_up
    cmp dword [menu_selection], 0
    jle .menu_no_up
    dec dword [menu_selection]
.menu_no_up:

    ; S = down
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_S], 0
    je .menu_no_down
    cmp dword [menu_selection], MENU_ITEM_COUNT - 1
    jge .menu_no_down
    inc dword [menu_selection]
.menu_no_down:

    ; Enter = select
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_ENTER], 0
    je .menu_no_enter

    mov eax, [menu_selection]
    cmp eax, MENU_PLAY
    je .menu_goto_champ_select
    cmp eax, MENU_QUIT
    je .menu_goto_quit
    jmp .menu_no_enter

.menu_goto_champ_select:
    mov dword [game_state], GAMESTATE_CHAMP_SELECT
    jmp .menu_no_enter

.menu_goto_quit:
    ; Signal quit via return value (caller checks)
    mov eax, -1
    ret

.menu_no_enter:
    xor eax, eax           ; don't run game update
    ret

.update_champ_select:
    lea rax, [rel key_pressed]

    ; A = prev champion
    cmp byte [rax + KEY_A], 0
    je .cs_no_prev
    cmp dword [selected_champion], 1
    jle .cs_no_prev
    dec dword [selected_champion]
.cs_no_prev:

    ; D = next champion
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_D], 0
    je .cs_no_next
    cmp dword [selected_champion], NUM_CHAMPIONS
    jge .cs_no_next
    inc dword [selected_champion]
.cs_no_next:

    ; Enter = lock in
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_ENTER], 0
    je .cs_no_enter
    mov dword [game_state], GAMESTATE_LOADING
    mov dword [loading_progress], 0
    mov dword [loading_timer], 0
.cs_no_enter:
    xor eax, eax
    ret

.update_loading:
    inc dword [loading_timer]
    cmp dword [loading_timer], 3
    jl .loading_wait
    mov dword [loading_timer], 0
    inc dword [loading_progress]
    cmp dword [loading_progress], 100
    jl .loading_wait
    mov dword [game_state], GAMESTATE_PLAYING
.loading_wait:
    xor eax, eax
    ret

.update_playing:
    ; Check for pause (Escape key)
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_ESCAPE], 0
    je .playing_no_pause
    mov dword [game_state], GAMESTATE_PAUSED
    xor eax, eax
    ret
.playing_no_pause:
    mov eax, 1              ; run game update
    ret

.update_paused:
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_ESCAPE], 0
    je .pause_no_resume
    mov dword [game_state], GAMESTATE_PLAYING
.pause_no_resume:
    xor eax, eax
    ret

.update_endgame:
    inc dword [endgame_timer]
    ; Enter to go back to menu
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_ENTER], 0
    je .endgame_wait
    mov dword [game_state], GAMESTATE_MENU
    mov dword [endgame_timer], 0
.endgame_wait:
    xor eax, eax
    ret

; ============================================================================
; menu_render - Render current menu/overlay screen
; ============================================================================
global menu_render
menu_render:
    mov eax, [game_state]

    cmp eax, GAMESTATE_MENU
    je .render_menu
    cmp eax, GAMESTATE_CHAMP_SELECT
    je .render_champ_select
    cmp eax, GAMESTATE_LOADING
    je .render_loading
    cmp eax, GAMESTATE_PAUSED
    je .render_paused
    cmp eax, GAMESTATE_VICTORY
    je .render_victory
    cmp eax, GAMESTATE_DEFEAT
    je .render_defeat
    ret

.render_menu:
    ; Dark background
    mov edi, 200
    mov esi, 150
    mov edx, 880
    mov ecx, 420
    mov r8d, COLOR_HUD_BG
    call render_rect

    ; Border
    mov edi, 198
    mov esi, 148
    mov edx, 884
    mov ecx, 2
    mov r8d, COLOR_GOLD
    call render_rect
    mov edi, 198
    mov esi, 568
    mov edx, 884
    mov ecx, 2
    mov r8d, COLOR_GOLD
    call render_rect

    ; Title
    lea rdi, [rel str_title]
    mov esi, 500
    mov edx, 200
    mov ecx, COLOR_GOLD
    call render_string

    ; Subtitle
    lea rdi, [rel str_subtitle]
    mov esi, 520
    mov edx, 230
    mov ecx, COLOR_LIGHT_GRAY
    call render_string

    ; Menu items
    push rbx
    xor ebx, ebx
.menu_item_loop:
    cmp ebx, MENU_ITEM_COUNT
    jge .menu_items_done

    ; Calculate Y position
    imul ecx, ebx, 40
    add ecx, 320           ; base Y
    push rcx

    ; Highlight selected item
    cmp ebx, [menu_selection]
    jne .not_selected
    mov edi, 500
    pop rcx
    push rcx
    sub ecx, 5
    mov edx, 280
    mov r8d, COLOR_DARK_BLUE
    push rbx
    mov ebx, 30
    push rbx
    pop rcx
    pop rbx
    ; Actually just draw highlight rect
    mov r8d, COLOR_DARK_BLUE
    mov ecx, 30
    call render_rect
.not_selected:

    ; Get string for this menu item
    cmp ebx, 0
    je .item_play
    cmp ebx, 1
    je .item_settings
    lea rdi, [rel str_quit]
    jmp .draw_item
.item_play:
    lea rdi, [rel str_play]
    jmp .draw_item
.item_settings:
    lea rdi, [rel str_settings]
.draw_item:
    mov esi, 580
    pop rcx                ; Y position
    mov edx, ecx
    ; Color
    cmp ebx, [menu_selection]
    jne .item_normal_color
    mov ecx, COLOR_GOLD
    jmp .item_draw
.item_normal_color:
    mov ecx, COLOR_WHITE
.item_draw:
    call render_string

    inc ebx
    jmp .menu_item_loop

.menu_items_done:
    pop rbx
    ret

.render_champ_select:
    ; Background
    mov edi, 100
    mov esi, 100
    mov edx, 1080
    mov ecx, 520
    mov r8d, COLOR_HUD_BG
    call render_rect

    ; Title
    lea rdi, [rel str_champ_sel]
    mov esi, 500
    mov edx, 130
    mov ecx, COLOR_GOLD
    call render_string

    ; Draw champion portraits (colored rectangles)
    push rbx
    xor ebx, ebx
.champ_loop:
    cmp ebx, NUM_CHAMPIONS
    jge .champ_done

    ; Calculate position
    mov eax, ebx
    xor edx, edx
    mov ecx, 5
    div ecx                 ; eax=row, edx=col

    imul edi, edx, 160
    add edi, 220            ; X
    imul esi, eax, 160
    add esi, 200            ; Y

    push rdi
    push rsi

    ; Draw portrait box
    mov edx, 120
    mov ecx, 120
    lea rax, [rel champ_colors]
    mov r8d, [rax + rbx * 4]

    ; Highlight if selected
    lea r9, [rbx + 1]      ; champion ID is 1-based
    cmp r9d, [selected_champion]
    jne .champ_no_highlight
    ; Draw selection border
    push rdi
    push rsi
    sub edi, 3
    sub esi, 3
    mov edx, 126
    mov ecx, 126
    mov r8d, COLOR_GOLD
    call render_rect
    pop rsi
    pop rdi
    mov edx, 120
    mov ecx, 120
    lea rax, [rel champ_colors]
    mov r8d, [rax + rbx * 4]
.champ_no_highlight:
    call render_rect

    ; Draw champion name
    pop rsi
    pop rdi
    push rbx
    lea rax, [rel champ_names]
    mov rdi, [rax + rbx * 8]
    ; esi = portrait_x (already popped into rdi...)
    ; Need to recalculate
    mov eax, ebx
    xor edx, edx
    mov ecx, 5
    div ecx
    imul esi, edx, 160
    add esi, 240
    imul edx, eax, 160
    add edx, 330
    mov ecx, COLOR_WHITE
    call render_string
    pop rbx

    inc ebx
    jmp .champ_loop

.champ_done:
    ; "Press ENTER" text
    lea rdi, [rel str_press_enter]
    mov esi, 520
    mov edx, 550
    mov ecx, COLOR_LIGHT_GRAY
    call render_string

    pop rbx
    ret

.render_loading:
    ; Loading bar
    mov edi, 300
    mov esi, 340
    mov edx, 680
    mov ecx, 40
    mov r8d, COLOR_DARK_GRAY
    call render_rect

    ; Progress fill
    mov eax, [loading_progress]
    imul eax, 680
    xor edx, edx
    mov ecx, 100
    div ecx
    mov edi, 300
    mov esi, 340
    mov edx, eax
    mov ecx, 40
    mov r8d, COLOR_BLUE_TEAM
    call render_rect

    ; "LOADING..." text
    lea rdi, [rel str_loading]
    mov esi, 570
    mov edx, 300
    mov ecx, COLOR_WHITE
    call render_string

    ; Progress number
    mov edi, [loading_progress]
    mov esi, 640
    mov edx, 365
    mov ecx, COLOR_WHITE
    call render_number
    ret

.render_paused:
    ; Semi-transparent overlay (just dark rect)
    mov edi, 400
    mov esi, 280
    mov edx, 480
    mov ecx, 160
    mov r8d, COLOR_HUD_BG
    call render_rect

    lea rdi, [rel str_paused]
    mov esi, 580
    mov edx, 340
    mov ecx, COLOR_WHITE
    call render_string
    ret

.render_victory:
    mov edi, 300
    mov esi, 250
    mov edx, 680
    mov ecx, 220
    mov r8d, COLOR_HUD_BG
    call render_rect

    lea rdi, [rel str_victory]
    mov esi, 560
    mov edx, 320
    mov ecx, COLOR_GOLD
    call render_string

    lea rdi, [rel str_press_enter]
    mov esi, 520
    mov edx, 400
    mov ecx, COLOR_LIGHT_GRAY
    call render_string
    ret

.render_defeat:
    mov edi, 300
    mov esi, 250
    mov edx, 680
    mov ecx, 220
    mov r8d, COLOR_HUD_BG
    call render_rect

    lea rdi, [rel str_defeat]
    mov esi, 570
    mov edx, 320
    mov ecx, COLOR_RED
    call render_string

    lea rdi, [rel str_press_enter]
    mov esi, 520
    mov edx, 400
    mov ecx, COLOR_LIGHT_GRAY
    call render_string
    ret

; ============================================================================
; menu_set_victory - Called when player team wins
; ============================================================================
global menu_set_victory
menu_set_victory:
    mov dword [game_state], GAMESTATE_VICTORY
    mov dword [endgame_timer], 0
    ret

; ============================================================================
; menu_set_defeat - Called when enemy team wins
; ============================================================================
global menu_set_defeat
menu_set_defeat:
    mov dword [game_state], GAMESTATE_DEFEAT
    mov dword [endgame_timer], 0
    ret
