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

str_cs:         db "CS", 0
str_kda:        db "KDA", 0
str_assists:    db "A", 0
str_respawn:    db "RESPAWN:", 0
str_victory:    db "VICTORY", 0
str_defeat:     db "DEFEAT", 0

global str_time, str_slash, str_colon
global str_cs, str_kda, str_assists, str_respawn, str_victory, str_defeat

; Entity radius lookup by type
global entity_radius_table
align 4
entity_radius_table:
    dd 0                    ; 0: ENT_NONE
    dd ENTITY_RADIUS        ; 1: ENT_CHAMPION
    dd MINION_RADIUS        ; 2: ENT_MINION_MELEE
    dd MINION_RADIUS        ; 3: ENT_MINION_CASTER
    dd TOWER_RADIUS         ; 4: ENT_TOWER
    dd TOWER_RADIUS         ; 5: ENT_NEXUS
    dd ENTITY_RADIUS        ; 6: ENT_INHIBITOR
    dd 4                    ; 7: ENT_PROJECTILE
    dd MINION_RADIUS + 2    ; 8: ENT_MINION_CANNON
    dd MINION_RADIUS + 1    ; 9: ENT_MINION_SUPER
    dd 10                   ; 10: ENT_JUNGLE_CAMP
    dd 16                   ; 11: ENT_DRAGON
    dd 20                   ; 12: ENT_BARON
    dd 14                   ; 13: ENT_HERALD
    dd 3                    ; 14: ENT_WARD
    dd 5                    ; 15: ENT_PLANT
    dd 5                    ; 16: ENT_BLAST_CONE
    dd 5                    ; 17: ENT_SCRYER
    dd 5                    ; 18: ENT_HONEYFRUIT

; Entity color lookup by type + team
; [type * 2 + team]
global entity_color_table
align 4
entity_color_table:
    dd COLOR_WHITE, COLOR_WHITE                    ; 0: ENT_NONE
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM             ; 1: ENT_CHAMPION
    dd COLOR_MINION_BLUE, COLOR_MINION_RED         ; 2: ENT_MINION_MELEE
    dd COLOR_MINION_BLUE, COLOR_MINION_RED         ; 3: ENT_MINION_CASTER
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM             ; 4: ENT_TOWER
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM             ; 5: ENT_NEXUS
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM             ; 6: ENT_INHIBITOR
    dd COLOR_YELLOW, COLOR_YELLOW                  ; 7: ENT_PROJECTILE
    dd COLOR_MINION_BLUE, COLOR_MINION_RED         ; 8: ENT_MINION_CANNON
    dd COLOR_MINION_BLUE, COLOR_MINION_RED         ; 9: ENT_MINION_SUPER
    dd COLOR_JUNGLE_GREEN, COLOR_JUNGLE_GREEN      ; 10: ENT_JUNGLE_CAMP
    dd COLOR_PURPLE, COLOR_PURPLE                  ; 11: ENT_DRAGON
    dd COLOR_DARK_RED, COLOR_DARK_RED              ; 12: ENT_BARON
    dd COLOR_PURPLE, COLOR_PURPLE                  ; 13: ENT_HERALD
    dd COLOR_BLUE_TEAM, COLOR_RED_TEAM             ; 14: ENT_WARD
    dd COLOR_GREEN, COLOR_GREEN                    ; 15: ENT_PLANT
    dd COLOR_ORANGE, COLOR_ORANGE                  ; 16: ENT_BLAST_CONE
    dd COLOR_CYAN, COLOR_CYAN                      ; 17: ENT_SCRYER
    dd COLOR_GREEN, COLOR_GREEN                    ; 18: ENT_HONEYFRUIT

section .bss

section .text
; No code needed - this is a data-only module
; Need at least one instruction for linker
global data_dummy
data_dummy:
    ret
