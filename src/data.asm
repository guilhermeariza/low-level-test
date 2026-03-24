; ============================================================================
; data.asm - Static game data (sprites, text strings, etc.)
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

section .data

; Game strings
global str_hp, str_mana, str_gold, str_level, str_fps
global str_game_title, str_kills, str_deaths
global str_blue_team, str_red_team

str_hp:         db "HP", 0
str_mana:       db "MANA", 0
str_gold:       db "GOLD", 0
str_level:      db "LVL", 0
str_fps:        db "FPS", 0
str_game_title: db "LOL ASSEMBLY", 0
str_kills:      db "K", 0
str_deaths:     db "D", 0
str_blue_team:  db "BLUE", 0
str_red_team:   db "RED", 0
str_time:       db "TIME", 0
str_slash:      db "/", 0
str_colon:      db ":", 0

global str_time, str_slash, str_colon

; Entity radius lookup by type
global entity_radius_table
align 4
entity_radius_table:
    dd 0                    ; ENT_NONE
    dd ENTITY_RADIUS        ; ENT_CHAMPION
    dd MINION_RADIUS        ; ENT_MINION_MELEE
    dd MINION_RADIUS        ; ENT_MINION_CASTER
    dd TOWER_RADIUS         ; ENT_TOWER
    dd TOWER_RADIUS         ; ENT_NEXUS
    dd ENTITY_RADIUS        ; ENT_INHIBITOR
    dd 4                    ; ENT_PROJECTILE

; Entity color lookup by type + team
; [type * 2 + team]
global entity_color_table
align 4
entity_color_table:
    dd COLOR_WHITE, COLOR_WHITE         ; ENT_NONE
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM  ; ENT_CHAMPION
    dd COLOR_MINION_BLUE, COLOR_MINION_RED  ; ENT_MINION_MELEE
    dd COLOR_MINION_BLUE, COLOR_MINION_RED  ; ENT_MINION_CASTER
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM  ; ENT_TOWER
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM  ; ENT_NEXUS
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM  ; ENT_INHIBITOR
    dd COLOR_YELLOW, COLOR_YELLOW       ; ENT_PROJECTILE

section .bss

section .text
; No code needed - this is a data-only module
; Need at least one instruction for linker
global data_dummy
data_dummy:
    ret
