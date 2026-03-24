; ============================================================================
; constants.inc - Game constants
; ============================================================================

%ifndef CONSTANTS_INC
%define CONSTANTS_INC

; Entity system
%define MAX_ENTITIES        256
%define ENTITY_ALIGN        64      ; AVX-512 alignment

; Entity types
%define ENT_NONE            0
%define ENT_CHAMPION        1
%define ENT_MINION_MELEE    2
%define ENT_MINION_CASTER   3
%define ENT_TOWER           4
%define ENT_NEXUS           5
%define ENT_INHIBITOR       6
%define ENT_PROJECTILE      7

; Entity states
%define STATE_IDLE          0
%define STATE_MOVING        1
%define STATE_ATTACKING     2
%define STATE_DEAD          3
%define STATE_RESPAWNING    4

; Teams
%define TEAM_BLUE           0
%define TEAM_RED            1
%define TEAM_NEUTRAL        2

; Player entity index (always 0)
%define PLAYER_ID           0

; Map constants
%define TILE_SIZE           32
%define MAP_WIDTH           200
%define MAP_HEIGHT          200
%define MAP_PIXEL_WIDTH     (MAP_WIDTH * TILE_SIZE)
%define MAP_PIXEL_HEIGHT    (MAP_HEIGHT * TILE_SIZE)

; Tile types
%define TILE_GRASS          0
%define TILE_RIVER          1
%define TILE_WALL           2
%define TILE_LANE           3
%define TILE_BASE_BLUE      4
%define TILE_BASE_RED       5
%define TILE_JUNGLE         6
%define TILE_BUSH           7

; Colors (BGRA format for X11)
%define COLOR_BLACK         0xFF000000
%define COLOR_WHITE         0xFFFFFFFF
%define COLOR_RED           0xFF0000FF
%define COLOR_GREEN         0xFF00FF00
%define COLOR_BLUE          0xFFFF0000
%define COLOR_YELLOW        0xFF00FFFF
%define COLOR_CYAN          0xFFFFFF00
%define COLOR_DARK_GREEN    0xFF005500
%define COLOR_GRASS         0xFF228B22
%define COLOR_RIVER_BLUE    0xFFDD8844
%define COLOR_LANE_BROWN    0xFF3388AA
%define COLOR_WALL_GRAY     0xFF555555
%define COLOR_BASE_BLUE     0xFFCC6633
%define COLOR_BASE_RED      0xFF3333CC
%define COLOR_JUNGLE_GREEN  0xFF115511
%define COLOR_BUSH_GREEN    0xFF009933
%define COLOR_HP_GREEN      0xFF00CC00
%define COLOR_HP_RED        0xFF0000CC
%define COLOR_MANA_BLUE     0xFFFF6600
%define COLOR_HUD_BG        0xFF333333
%define COLOR_HUD_BORDER    0xFF888888
%define COLOR_GOLD          0xFF00D4FF
%define COLOR_BLUE_TEAM     0xFFFF4422
%define COLOR_RED_TEAM      0xFF2222FF
%define COLOR_TOWER_GRAY    0xFFAAAAAA
%define COLOR_MINION_BLUE   0xFFEE8844
%define COLOR_MINION_RED    0xFF4444EE
%define COLOR_MINIMAP_BG    0xFF111111

; Game balance
%define CHAMPION_HP         1000
%define CHAMPION_MANA       500
%define CHAMPION_AD         60
%define CHAMPION_SPEED      330     ; movement speed (pixels/sec scaled)
%define CHAMPION_RANGE      125     ; auto attack range
%define CHAMPION_ATK_SPD    100     ; attack speed (100 = 1.0 attacks/sec)
%define CHAMPION_RESPAWN    500     ; respawn time in frames (~8 sec)

%define MINION_MELEE_HP     450
%define MINION_MELEE_AD     12
%define MINION_MELEE_SPEED  250
%define MINION_MELEE_RANGE  50

%define MINION_CASTER_HP    300
%define MINION_CASTER_AD    25
%define MINION_CASTER_SPEED 250
%define MINION_CASTER_RANGE 300

%define TOWER_HP            3000
%define TOWER_AD            150
%define TOWER_RANGE         400
%define TOWER_ATK_SPD       83      ; ~0.83 attacks/sec

%define MINION_WAVE_INTERVAL 1800   ; frames between waves (30 sec at 60fps)
%define MINIONS_PER_WAVE    6       ; melee minions per wave
%define CASTERS_PER_WAVE    3       ; caster minions per wave

%define GOLD_PER_MINION     20
%define GOLD_PER_CHAMPION   300
%define GOLD_PER_TOWER      150
%define STARTING_GOLD       500

; Game timing
%define TARGET_FPS          60
%define FRAME_TIME_NS       16666667    ; 1000000000 / 60
%define GAME_TICK_RATE      60          ; updates per second

; Rendering
%define ENTITY_RADIUS       12      ; champion circle radius
%define MINION_RADIUS       8       ; minion circle radius
%define TOWER_RADIUS        16      ; tower circle radius
%define HP_BAR_WIDTH        30
%define HP_BAR_HEIGHT       4
%define HP_BAR_OFFSET       18      ; pixels above entity center

; HUD
%define HUD_HEIGHT          100
%define HUD_Y               (WINDOW_HEIGHT - HUD_HEIGHT)
%define MINIMAP_SIZE        150
%define MINIMAP_X           (WINDOW_WIDTH - MINIMAP_SIZE - 10)
%define MINIMAP_Y           (HUD_Y + 5)

; Camera
%define CAMERA_EDGE_SCROLL  30      ; pixels from edge to trigger scroll
%define CAMERA_SCROLL_SPEED 8       ; pixels per frame

%endif
