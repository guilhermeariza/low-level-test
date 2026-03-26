; ============================================================================
; main.asm - Entry point and main game loop
; LoL Assembly - League of Legends clone in pure x86-64 assembly
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

; X11
extern x11_init, x11_cleanup

; Rendering
extern render_clear, render_rect, render_flush, render_string, render_number

; Input
extern input_init, input_clear_frame, input_poll
extern quit_flag

; Entities
extern entities_init

; Game
extern game_init, game_update

; Map
extern map_init, map_render

; HUD
extern hud_render_entity_bars, hud_render_entities, hud_render_panel
extern hud_update_fps, fps_display

; New subsystems
extern collision_map_init
extern combat_init
extern level_init, level_update
extern abilities_init, abilities_tick_cooldowns
extern items_init
extern vision_init, vision_update, vision_render_fog
extern summ_init, summ_tick_cooldowns
extern jungle_init, jungle_update

; UI
extern ui_init, ui_update
extern ui_render_ability_bar, ui_render_inventory
extern ui_render_stats_panel, ui_render_scoreboard, ui_render_kill_feed

; AI
extern ai_init, ai_update

; Effects
extern effects_init, effects_update, effects_render

; Audio
extern audio_init, audio_update, audio_cleanup

; Menu
extern menu_init, menu_update, menu_render
extern game_state

; Data
extern str_fps, str_game_title

section .data

align 8
frame_timespec:
    dq 0                    ; tv_sec
    dq FRAME_TIME_NS        ; tv_nsec

section .bss

alignb 8
time_before:    resq 2      ; timespec for frame timing
time_after:     resq 2
time_remain:    resq 2      ; remaining sleep time

section .text

global _start

; ============================================================================
; _start - Program entry point
; ============================================================================
_start:
    ; --- Initialize X11 ---
    call x11_init
    test eax, eax
    js .fatal_exit

    ; --- Initialize subsystems ---
    call input_init
    call entities_init
    call map_init
    call collision_map_init
    call combat_init
    call level_init
    call abilities_init
    call items_init
    call vision_init
    call summ_init
    call jungle_init
    call ui_init
    call ai_init
    call effects_init
    call audio_init
    call menu_init
    call game_init

    ; === MAIN GAME LOOP ===
.game_loop:
    ; --- Get frame start time ---
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rel time_before]
    syscall

    ; --- Clear per-frame input ---
    call input_clear_frame

    ; --- Poll input events ---
    call input_poll

    ; --- Check quit ---
    cmp dword [quit_flag], 0
    jne .exit_game

    ; --- Check game state for menu vs playing ---
    cmp dword [game_state], 3       ; GAMESTATE_PLAYING
    je .state_playing

    ; Non-playing states: menu, champion select, loading, etc.
    call menu_update

    mov edi, COLOR_BLACK
    call render_clear
    call menu_render
    call render_flush
    jmp .frame_sleep

.state_playing:
    ; --- Update game logic ---
    call game_update
    call level_update
    call abilities_tick_cooldowns
    call summ_tick_cooldowns
    call jungle_update
    call vision_update
    call ui_update
    call ai_update
    call effects_update
    call audio_update

    ; --- Render frame ---
    ; Clear screen
    mov edi, COLOR_BLACK
    call render_clear

    ; Render map
    call map_render

    ; Render entities
    call hud_render_entities

    ; Render HP bars above entities
    call hud_render_entity_bars

    ; Render visual effects (particles, damage numbers)
    call effects_render

    ; Render fog of war overlay
    call vision_render_fog

    ; Render HUD panel
    call hud_render_panel

    ; Render UI overlays
    call ui_render_ability_bar
    call ui_render_inventory
    call ui_render_stats_panel
    call ui_render_scoreboard
    call ui_render_kill_feed

    ; Render FPS counter
    call hud_update_fps
    lea rdi, [rel str_fps]
    mov esi, WINDOW_WIDTH - 80
    mov edx, 5
    mov ecx, COLOR_YELLOW
    call render_string

    mov edi, [fps_display]
    mov esi, WINDOW_WIDTH - 40
    mov edx, 5
    mov ecx, COLOR_YELLOW
    call render_number

    ; Flush frame to display
    call render_flush

.frame_sleep:
    ; --- Frame timing ---
    ; Sleep to maintain ~60 FPS
    mov rax, SYS_CLOCK_NANOSLEEP
    mov rdi, CLOCK_MONOTONIC
    mov rsi, 1              ; flags = TIMER_ABSTIME
    ; Calculate target wakeup time = time_before + frame_time
    mov rax, [time_before]
    mov rdx, [time_before + 8]
    add rdx, FRAME_TIME_NS
    cmp rdx, 1000000000
    jl .no_sec_overflow
    sub rdx, 1000000000
    inc rax
.no_sec_overflow:
    mov [time_after], rax       ; reuse as target timespec
    mov [time_after + 8], rdx

    mov rax, SYS_CLOCK_NANOSLEEP
    mov rdi, CLOCK_MONOTONIC
    mov rsi, 1              ; TIMER_ABSTIME
    lea rdx, [rel time_after]
    lea r10, [rel time_remain]
    syscall

    jmp .game_loop

; ============================================================================
; Exit handlers
; ============================================================================
.exit_game:
    call audio_cleanup
    call x11_cleanup

.exit:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

.fatal_exit:
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall
