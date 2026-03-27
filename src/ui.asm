; ============================================================================
; ui.asm - Advanced UI system (Phase 9)
; Ability bar, inventory, scoreboard, kill feed, ping system
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

; External entity data
extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_count
extern ent_armor, ent_mr, ent_ap, ent_cdr

; External systems
extern camera_x, camera_y
extern render_rect, render_string, render_number, render_char
extern key_pressed, key_state
extern framebuffer
extern game_time

; ============================================================================
; Data section
; ============================================================================
section .data

str_kills:          db "K:", 0
str_deaths:         db "D:", 0
str_assists:        db "A:", 0
str_gold_label:     db "Gold:", 0
str_level_label:    db "Lvl:", 0
str_ad_label:       db "AD:", 0
str_ap_label:       db "AP:", 0
str_armor_label:    db "Arm:", 0
str_mr_label:       db "MR:", 0
str_shop_title:     db "SHOP", 0
str_scoreboard:     db "SCOREBOARD", 0

; Ability key labels (single chars)
ui_ability_keys:    db "Q", 0, "W", 0, "E", 0, "R", 0

; Item slot number labels
ui_slot_nums:       db "1", 0, "2", 0, "3", 0, "4", 0, "5", 0, "6", 0

; Kill feed format
str_killed:         db "->", 0

; ============================================================================
; BSS section
; ============================================================================
section .bss

global scoreboard_visible
global kill_feed_entries, kill_feed_count

extern shop_open

scoreboard_visible: resd 1

; Kill feed: 4 entries x 4 dwords each (killer, victim, time, type)
kill_feed_entries:   resd 16
kill_feed_count:     resd 1

; ============================================================================
; Text section
; ============================================================================
section .text

; ============================================================================
; ui_init - Initialize UI state
; ============================================================================
global ui_init
ui_init:
    xor eax, eax
    mov [scoreboard_visible], eax
    mov [shop_open], eax
    mov [kill_feed_count], eax

    ; Zero kill feed entries
    lea rdi, [rel kill_feed_entries]
    mov ecx, 16
.ui_init_zero:
    mov dword [rdi], 0
    add rdi, 4
    dec ecx
    jnz .ui_init_zero

    ret

; ============================================================================
; ui_update - Process UI-related key inputs
; ============================================================================
global ui_update
ui_update:
    ; Check KEY_TAB held state for scoreboard
    lea rax, [rel key_state]
    movzx ecx, byte [rax + KEY_TAB]
    mov [scoreboard_visible], ecx

    ; Check KEY_P pressed for shop toggle
    lea rax, [rel key_pressed]
    cmp byte [rax + KEY_P], 0
    je .ui_update_done

    ; Toggle shop_open
    mov eax, [shop_open]
    xor eax, 1
    mov [shop_open], eax

.ui_update_done:
    ret

; ============================================================================
; ui_render_ability_bar - Render 4 ability slots (Q/W/E/R)
; ============================================================================
global ui_render_ability_bar
ui_render_ability_bar:
    push rbx
    push r12
    push r13

    xor ebx, ebx               ; slot index 0..3

.ability_slot_loop:
    cmp ebx, 4
    jge .ability_slot_done

    ; Calculate X position: ABILITY_ICON_X + slot * (ABILITY_ICON_SIZE + ABILITY_ICON_GAP)
    mov r12d, ebx
    imul r12d, (ABILITY_ICON_SIZE + ABILITY_ICON_GAP)
    add r12d, ABILITY_ICON_X

    ; Draw filled background rect
    mov edi, r12d
    mov esi, ABILITY_ICON_Y
    mov edx, ABILITY_ICON_SIZE
    mov ecx, ABILITY_ICON_SIZE
    mov r8d, COLOR_DARK_GRAY
    call render_rect

    ; Draw top border
    mov edi, r12d
    mov esi, ABILITY_ICON_Y
    mov edx, ABILITY_ICON_SIZE
    mov ecx, 1
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw bottom border
    mov edi, r12d
    mov esi, ABILITY_ICON_Y + ABILITY_ICON_SIZE - 1
    mov edx, ABILITY_ICON_SIZE
    mov ecx, 1
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw left border
    mov edi, r12d
    mov esi, ABILITY_ICON_Y
    mov edx, 1
    mov ecx, ABILITY_ICON_SIZE
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw right border
    lea edi, [r12d + ABILITY_ICON_SIZE - 1]
    mov esi, ABILITY_ICON_Y
    mov edx, 1
    mov ecx, ABILITY_ICON_SIZE
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw key label (Q/W/E/R) at top-left of icon
    lea rdi, [rel ui_ability_keys]
    lea rdi, [rdi + rbx * 2]   ; each label is 2 bytes ("X\0")
    lea esi, [r12d + 2]        ; x + 2 padding
    mov edx, ABILITY_ICON_Y + 2
    mov ecx, COLOR_WHITE
    call render_string

    inc ebx
    jmp .ability_slot_loop

.ability_slot_done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; ui_render_inventory - Render 6 item slots
; ============================================================================
global ui_render_inventory
ui_render_inventory:
    push rbx
    push r12

    xor ebx, ebx               ; slot index 0..5

.inv_slot_loop:
    cmp ebx, MAX_ITEMS_PER_ENT
    jge .inv_slot_done

    ; Calculate X position: ITEM_SLOT_X + slot * (ITEM_SLOT_SIZE + ITEM_SLOT_GAP)
    mov r12d, ebx
    imul r12d, (ITEM_SLOT_SIZE + ITEM_SLOT_GAP)
    add r12d, ITEM_SLOT_X

    ; Draw filled background
    mov edi, r12d
    mov esi, ITEM_SLOT_Y
    mov edx, ITEM_SLOT_SIZE
    mov ecx, ITEM_SLOT_SIZE
    mov r8d, COLOR_DARK_GRAY
    call render_rect

    ; Draw border - top
    mov edi, r12d
    mov esi, ITEM_SLOT_Y
    mov edx, ITEM_SLOT_SIZE
    mov ecx, 1
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - bottom
    mov edi, r12d
    mov esi, ITEM_SLOT_Y + ITEM_SLOT_SIZE - 1
    mov edx, ITEM_SLOT_SIZE
    mov ecx, 1
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - left
    mov edi, r12d
    mov esi, ITEM_SLOT_Y
    mov edx, 1
    mov ecx, ITEM_SLOT_SIZE
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - right
    lea edi, [r12d + ITEM_SLOT_SIZE - 1]
    mov esi, ITEM_SLOT_Y
    mov edx, 1
    mov ecx, ITEM_SLOT_SIZE
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw slot number (1-6) in center of box
    lea rdi, [rel ui_slot_nums]
    lea rdi, [rdi + rbx * 2]   ; each label is 2 bytes ("N\0")
    lea esi, [r12d + 8]        ; roughly centered
    mov edx, ITEM_SLOT_Y + 8
    mov ecx, COLOR_WHITE
    call render_string

    inc ebx
    jmp .inv_slot_loop

.inv_slot_done:
    pop r12
    pop rbx
    ret

; ============================================================================
; ui_render_stats_panel - Render player stats (AD, AP, Armor, MR)
; ============================================================================
global ui_render_stats_panel
ui_render_stats_panel:
    push rbx

    ; --- AD ---
    lea rdi, [rel str_ad_label]
    mov esi, STATS_X
    mov edx, STATS_Y
    mov ecx, COLOR_WHITE
    call render_string

    lea rax, [rel ent_atk]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, STATS_X + 30
    mov edx, STATS_Y
    mov ecx, COLOR_WHITE
    call render_number

    ; --- AP ---
    lea rdi, [rel str_ap_label]
    mov esi, STATS_X
    mov edx, STATS_Y + 10
    mov ecx, COLOR_WHITE
    call render_string

    lea rax, [rel ent_ap]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, STATS_X + 30
    mov edx, STATS_Y + 10
    mov ecx, COLOR_WHITE
    call render_number

    ; --- Armor ---
    lea rdi, [rel str_armor_label]
    mov esi, STATS_X
    mov edx, STATS_Y + 20
    mov ecx, COLOR_WHITE
    call render_string

    lea rax, [rel ent_armor]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, STATS_X + 36
    mov edx, STATS_Y + 20
    mov ecx, COLOR_WHITE
    call render_number

    ; --- MR ---
    lea rdi, [rel str_mr_label]
    mov esi, STATS_X
    mov edx, STATS_Y + 30
    mov ecx, COLOR_WHITE
    call render_string

    lea rax, [rel ent_mr]
    mov edi, [rax + PLAYER_ID * 4]
    mov esi, STATS_X + 30
    mov edx, STATS_Y + 30
    mov ecx, COLOR_WHITE
    call render_number

    pop rbx
    ret

; ============================================================================
; ui_render_scoreboard - Render full scoreboard overlay (when Tab held)
; ============================================================================
global ui_render_scoreboard
ui_render_scoreboard:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Only render if visible
    cmp dword [scoreboard_visible], 1
    jne .scoreboard_done

    ; Draw background
    mov edi, SCOREBOARD_X
    mov esi, SCOREBOARD_Y
    mov edx, SCOREBOARD_W
    mov ecx, SCOREBOARD_H
    mov r8d, COLOR_HUD_BG
    call render_rect

    ; Draw border - top
    mov edi, SCOREBOARD_X
    mov esi, SCOREBOARD_Y
    mov edx, SCOREBOARD_W
    mov ecx, 2
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - bottom
    mov edi, SCOREBOARD_X
    mov esi, SCOREBOARD_Y + SCOREBOARD_H - 2
    mov edx, SCOREBOARD_W
    mov ecx, 2
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - left
    mov edi, SCOREBOARD_X
    mov esi, SCOREBOARD_Y
    mov edx, 2
    mov ecx, SCOREBOARD_H
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw border - right
    mov edi, SCOREBOARD_X + SCOREBOARD_W - 2
    mov esi, SCOREBOARD_Y
    mov edx, 2
    mov ecx, SCOREBOARD_H
    mov r8d, COLOR_HUD_BORDER
    call render_rect

    ; Draw title "SCOREBOARD" centered at top
    lea rdi, [rel str_scoreboard]
    mov esi, SCOREBOARD_X + (SCOREBOARD_W / 2) - 40
    mov edx, SCOREBOARD_Y + 8
    mov ecx, COLOR_WHITE
    call render_string

    ; Draw column headers
    lea rdi, [rel str_level_label]
    mov esi, SCOREBOARD_X + 60
    mov edx, SCOREBOARD_Y + 28
    mov ecx, COLOR_WHITE
    call render_string

    lea rdi, [rel str_gold_label]
    mov esi, SCOREBOARD_X + 140
    mov edx, SCOREBOARD_Y + 28
    mov ecx, COLOR_GOLD
    call render_string

    ; List champion entities
    mov r15d, [ent_count]
    xor ebx, ebx               ; entity index
    mov r13d, 0                 ; row counter

.sb_entity_loop:
    cmp ebx, r15d
    jge .scoreboard_done

    ; Only show champions
    lea rax, [rel ent_type]
    cmp byte [rax + rbx], ENT_CHAMPION
    jne .sb_entity_next

    ; Only show active entities
    lea rax, [rel ent_active]
    cmp byte [rax + rbx], 0
    je .sb_entity_next

    ; Calculate row Y position
    mov r14d, r13d
    imul r14d, SCOREBOARD_ROW_H
    add r14d, SCOREBOARD_Y + 48  ; offset past title + headers

    ; Determine team color
    lea rax, [rel ent_team]
    movzx eax, byte [rax + rbx]
    cmp al, 0                  ; TEAM_BLUE = 0
    je .sb_blue_team
    mov r12d, 0xFF5555FF       ; red tint
    jmp .sb_draw_row
.sb_blue_team:
    mov r12d, 0xFFFF8855       ; blue tint
.sb_draw_row:

    ; Draw team color indicator bar
    mov edi, SCOREBOARD_X + 10
    mov esi, r14d
    mov edx, 4
    mov ecx, SCOREBOARD_ROW_H - 4
    mov r8d, r12d
    call render_rect

    ; Draw entity number as identifier
    mov edi, ebx
    mov esi, SCOREBOARD_X + 24
    lea edx, [r14d + 4]
    mov ecx, COLOR_WHITE
    call render_number

    ; Draw level
    lea rax, [rel ent_level]
    mov edi, [rax + rbx * 4]
    mov esi, SCOREBOARD_X + 70
    lea edx, [r14d + 4]
    mov ecx, COLOR_WHITE
    call render_number

    ; Draw gold
    lea rax, [rel ent_gold]
    mov edi, [rax + rbx * 4]
    mov esi, SCOREBOARD_X + 150
    lea edx, [r14d + 4]
    mov ecx, COLOR_GOLD
    call render_number

    inc r13d                    ; next row

.sb_entity_next:
    inc ebx
    jmp .sb_entity_loop

.scoreboard_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; ui_render_kill_feed - Render kill feed at top-right of screen
; Up to 4 most recent entries, each 12px apart vertically
; ============================================================================
global ui_render_kill_feed
ui_render_kill_feed:
    push rbx
    push r12
    push r13

    mov r12d, [kill_feed_count]
    test r12d, r12d
    jz .kf_done

    ; Clamp to 4 entries max displayed
    cmp r12d, 4
    jle .kf_count_ok
    mov r12d, 4
.kf_count_ok:

    xor ebx, ebx               ; entry index

.kf_entry_loop:
    cmp ebx, r12d
    jge .kf_done

    ; Get entry base offset: entry_index * 4 dwords * 4 bytes = index * 16
    mov eax, ebx
    shl eax, 4                 ; * 16
    lea rcx, [rel kill_feed_entries]

    ; Check if entry has expired (game_time > entry_time + 300)
    mov r13d, [rcx + rax + 8]  ; entry time
    add r13d, 300
    cmp [game_time], r13d
    jg .kf_next_entry

    ; Calculate Y position: 10 + entry_index * 12
    mov edx, ebx
    imul edx, 12
    add edx, 10
    push rdx                   ; save Y

    ; Render killer entity number
    mov edi, [rcx + rax]        ; killer ID
    mov esi, WINDOW_WIDTH - 120
    pop rdx
    push rdx
    mov ecx, COLOR_WHITE
    call render_number

    ; Render "->" separator
    lea rdi, [rel str_killed]
    mov esi, WINDOW_WIDTH - 90
    pop rdx
    push rdx
    mov ecx, COLOR_WHITE
    call render_string

    ; Render victim entity number
    mov eax, ebx
    shl eax, 4
    lea rcx, [rel kill_feed_entries]
    mov edi, [rcx + rax + 4]   ; victim ID
    mov esi, WINDOW_WIDTH - 70
    pop rdx
    mov ecx, COLOR_WHITE
    call render_number

    jmp .kf_continue

.kf_next_entry:
.kf_continue:
    inc ebx
    jmp .kf_entry_loop

.kf_done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; ui_add_kill_feed - Add an entry to the kill feed
; edi = killer entity index, esi = victim entity index
; ============================================================================
global ui_add_kill_feed
ui_add_kill_feed:
    push rbx
    push r12
    push r13

    mov r12d, edi               ; killer
    mov r13d, esi               ; victim

    ; If feed is full (4 entries), shift entries down to make room
    mov eax, [kill_feed_count]
    cmp eax, 4
    jl .kf_add_no_shift

    ; Shift entries 1->0, 2->1, 3->2 (each entry is 16 bytes)
    lea rdi, [rel kill_feed_entries]
    ; Entry 0 = Entry 1
    mov rax, [rdi + 16]
    mov [rdi], rax
    mov rax, [rdi + 24]
    mov [rdi + 8], rax
    ; Entry 1 = Entry 2
    mov rax, [rdi + 32]
    mov [rdi + 16], rax
    mov rax, [rdi + 40]
    mov [rdi + 24], rax
    ; Entry 2 = Entry 3
    mov rax, [rdi + 48]
    mov [rdi + 32], rax
    mov rax, [rdi + 56]
    mov [rdi + 40], rax

    ; New entry goes at index 3
    mov dword [rdi + 48], r12d  ; killer
    mov dword [rdi + 52], r13d  ; victim
    mov eax, [game_time]
    mov [rdi + 56], eax         ; time
    mov dword [rdi + 60], 0     ; type

    jmp .kf_add_done

.kf_add_no_shift:
    ; Add at current count position
    mov ecx, eax                ; count
    shl ecx, 4                  ; * 16 for offset
    lea rdi, [rel kill_feed_entries]

    mov [rdi + rcx], r12d       ; killer
    mov [rdi + rcx + 4], r13d   ; victim
    mov eax, [game_time]
    mov [rdi + rcx + 8], eax    ; time
    mov dword [rdi + rcx + 12], 0 ; type

    inc dword [kill_feed_count]

.kf_add_done:
    pop r13
    pop r12
    pop rbx
    ret
