; ============================================================================
; constants.inc - Game constants (FULL LoL replica)
; ============================================================================

%ifndef CONSTANTS_INC
%define CONSTANTS_INC

; ==============================
; Entity system
; ==============================
%define MAX_ENTITIES        512
%define ENTITY_ALIGN        64
%define MAX_ITEMS_PER_ENT   6
%define MAX_ABILITIES       4
%define MAX_BUFFS           16
%define MAX_PROJECTILES     128
%define MAX_PARTICLES       256
%define MAX_DAMAGE_NUMS     32

; ==============================
; Game states
; ==============================
%define GAMESTATE_MENU          0
%define GAMESTATE_CHAMP_SELECT  1
%define GAMESTATE_LOADING       2
%define GAMESTATE_PLAYING       3
%define GAMESTATE_PAUSED        4
%define GAMESTATE_VICTORY       5
%define GAMESTATE_DEFEAT        6
%define MAX_ITEMS           200
%define MAX_WARDS           50

; Entity types
%define ENT_NONE            0
%define ENT_CHAMPION        1
%define ENT_MINION_MELEE    2
%define ENT_MINION_CASTER   3
%define ENT_TOWER           4
%define ENT_NEXUS           5
%define ENT_INHIBITOR       6
%define ENT_PROJECTILE      7
%define ENT_MINION_CANNON   8
%define ENT_MINION_SUPER    9
%define ENT_JUNGLE_CAMP     10
%define ENT_DRAGON          11
%define ENT_BARON           12
%define ENT_HERALD          13
%define ENT_WARD            14
%define ENT_PLANT           15
%define ENT_BLAST_CONE      16
%define ENT_SCRYER          17
%define ENT_HONEYFRUIT      18

; Entity states
%define STATE_IDLE          0
%define STATE_MOVING        1
%define STATE_ATTACKING     2
%define STATE_DEAD          3
%define STATE_RESPAWNING    4
%define STATE_CHANNELING    5
%define STATE_STUNNED        6
%define STATE_ROOTED        7
%define STATE_SILENCED      8
%define STATE_RECALLING     9
%define STATE_DASHING       10
%define STATE_INVULNERABLE  11

; Teams
%define TEAM_BLUE           0
%define TEAM_RED            1
%define TEAM_NEUTRAL        2

; Player entity index (always 0)
%define PLAYER_ID           0

; ==============================
; Damage types
; ==============================
%define DMG_PHYSICAL        0
%define DMG_MAGIC           1
%define DMG_TRUE            2

; ==============================
; Crowd Control types
; ==============================
%define CC_NONE             0
%define CC_SLOW             1
%define CC_STUN             2
%define CC_ROOT             3
%define CC_SILENCE          4
%define CC_KNOCKUP          5
%define CC_KNOCKBACK        6
%define CC_BLIND            7
%define CC_CHARM            8
%define CC_FEAR             9
%define CC_TAUNT            10
%define CC_SUPPRESSION      11
%define CC_GROUND           12

; ==============================
; Ability targeting types
; ==============================
%define TARGET_NONE         0
%define TARGET_SELF         1
%define TARGET_POINT_CLICK  2
%define TARGET_SKILLSHOT    3
%define TARGET_CIRCULAR_AOE 4
%define TARGET_CONE         5
%define TARGET_LINE         6
%define TARGET_GLOBAL       7
%define TARGET_PASSIVE      8
%define TARGET_AUTO_AREA    9
%define TARGET_DASH         10

; ==============================
; Ability slots
; ==============================
%define SLOT_PASSIVE        0
%define SLOT_Q              1
%define SLOT_W              2
%define SLOT_E              3
%define SLOT_R              4
%define SLOT_SUMM1          5
%define SLOT_SUMM2          6
%define SLOT_ITEM_1         7
%define SLOT_ITEM_6         12

; ==============================
; Champion IDs
; ==============================
%define CHAMP_NONE          0
%define CHAMP_GAREN         1
%define CHAMP_ASHE          2
%define CHAMP_ANNIE         3
%define CHAMP_ZED           4
%define CHAMP_SORAKA        5
%define CHAMP_JINX          6
%define CHAMP_DARIUS        7
%define CHAMP_LUX           8
%define CHAMP_MASTER_YI     9
%define CHAMP_BLITZCRANK    10
%define NUM_CHAMPIONS       10

; ==============================
; Summoner Spell IDs
; ==============================
%define SUMM_NONE           0
%define SUMM_FLASH          1
%define SUMM_IGNITE         2
%define SUMM_HEAL           3
%define SUMM_TELEPORT       4
%define SUMM_SMITE          5
%define SUMM_BARRIER        6
%define SUMM_EXHAUST        7
%define SUMM_GHOST          8
%define SUMM_CLEANSE        9

; ==============================
; Item IDs (categories)
; ==============================
%define ITEM_NONE           0
; Starter items
%define ITEM_DORANS_BLADE   1
%define ITEM_DORANS_RING    2
%define ITEM_DORANS_SHIELD  3
%define ITEM_LONG_SWORD     4
%define ITEM_AMP_TOME       5
%define ITEM_CLOTH_ARMOR    6
%define ITEM_NULL_MAGIC     7
%define ITEM_BOOTS          8
%define ITEM_RUBY_CRYSTAL   9
%define ITEM_SAPPHIRE_CRYST 10
%define ITEM_REFILL_POTION  11
%define ITEM_HEALTH_POTION  12
; AD items
%define ITEM_BF_SWORD       20
%define ITEM_PICKAXE        21
%define ITEM_INFINITY_EDGE  22
%define ITEM_BLOODTHIRSTER  23
%define ITEM_BLADE_RUINED   24
%define ITEM_YOUMUUS        25
%define ITEM_DEATHS_DANCE   26
%define ITEM_BLACK_CLEAVER  27
%define ITEM_COLLECTOR      28
%define ITEM_PHANTOM_DANCER 29
; AP items
%define ITEM_NEEDLESS_ROD   40
%define ITEM_LOST_CHAPTER   41
%define ITEM_RABADONS       42
%define ITEM_LUDENS         43
%define ITEM_ZHONYAS        44
%define ITEM_VOID_STAFF     45
%define ITEM_MORELLOS       46
%define ITEM_BANSHEES       47
%define ITEM_LICH_BANE      48
%define ITEM_RYLAIS         49
; Tank items
%define ITEM_CHAIN_VEST     60
%define ITEM_WARDENS_MAIL   61
%define ITEM_THORNMAIL      62
%define ITEM_SUNFIRE        63
%define ITEM_RANDUINS       64
%define ITEM_DEAD_MANS      65
%define ITEM_SPIRIT_VISAGE  66
%define ITEM_FORCE_NATURE   67
%define ITEM_GARGOYLE       68
%define ITEM_WARMOGS        69
; Boots
%define ITEM_BERSERKERS     80
%define ITEM_SORC_SHOES     81
%define ITEM_TABIS          82
%define ITEM_MERCS          83
%define ITEM_LUCIDITY        84
%define ITEM_SWIFTIES       85
; Support items
%define ITEM_REDEMPTION     90
%define ITEM_LOCKET         91
%define ITEM_MIKAELS        92
%define ITEM_ARDENT          93
; Trinkets / Wards
%define ITEM_STEALTH_WARD   100
%define ITEM_CONTROL_WARD   101
%define ITEM_SWEEPER        102
%define ITEM_FARSIGHT       103
; Total unique items
%define NUM_ITEMS           104

; ==============================
; Buff/Debuff IDs
; ==============================
%define BUFF_NONE           0
%define BUFF_RED_BUFF       1
%define BUFF_BLUE_BUFF      2
%define BUFF_BARON          3
%define BUFF_DRAGON_INF     4
%define BUFF_DRAGON_OCN     5
%define BUFF_DRAGON_MTN     6
%define BUFF_DRAGON_CLD     7
%define BUFF_ELDER          8
%define BUFF_SHIELD         9
%define BUFF_SPEED_BOOST    10
%define BUFF_IGNITE_DOT     11
%define BUFF_EXHAUST_SLOW   12
%define BUFF_ZHONYAS_STASIS 13
%define BUFF_RECALL         14
%define BUFF_GAREN_SPIN     15
%define BUFF_ASHE_FOCUS     16

; ==============================
; Dragon types
; ==============================
%define DRAGON_INFERNAL     0
%define DRAGON_OCEAN        1
%define DRAGON_MOUNTAIN     2
%define DRAGON_CLOUD        3
%define DRAGON_ELDER         4

; ==============================
; Map constants
; ==============================
%define TILE_SIZE           32
%define MAP_WIDTH           280
%define MAP_HEIGHT          280
%define MAP_PIXEL_WIDTH     (MAP_WIDTH * TILE_SIZE)
%define MAP_PIXEL_HEIGHT    (MAP_HEIGHT * TILE_SIZE)

; Pathfinding
%define PATH_MAX_NODES      1024
%define PATH_GRID_SCALE     2       ; pathfinding grid = tile grid / 2 (16px cells)
%define PATH_GRID_W         (MAP_WIDTH * PATH_GRID_SCALE)
%define PATH_GRID_H         (MAP_HEIGHT * PATH_GRID_SCALE)
%define PATH_CELL_SIZE      (TILE_SIZE / PATH_GRID_SCALE)

; Tile types
%define TILE_GRASS          0
%define TILE_RIVER          1
%define TILE_WALL           2
%define TILE_LANE           3
%define TILE_BASE_BLUE      4
%define TILE_BASE_RED       5
%define TILE_JUNGLE         6
%define TILE_BUSH           7
%define TILE_SHOP_BLUE      8
%define TILE_SHOP_RED       9
%define TILE_ALCOVE         10

; Tile walkability (bitmask)
%define WALK_NONE           0
%define WALK_GROUND         1
%define WALK_WATER          2
%define WALK_ALL            3

; ==============================
; Colors (BGRA format for X11)
; ==============================
%define COLOR_BLACK         0xFF000000
%define COLOR_WHITE         0xFFFFFFFF
%define COLOR_RED           0xFF0000FF
%define COLOR_GREEN         0xFF00FF00
%define COLOR_BLUE          0xFFFF0000
%define COLOR_YELLOW        0xFF00FFFF
%define COLOR_CYAN          0xFFFFFF00
%define COLOR_ORANGE        0xFF0088FF
%define COLOR_PURPLE        0xFFFF0088
%define COLOR_PINK          0xFF8888FF
%define COLOR_DARK_GREEN    0xFF005500
%define COLOR_DARK_RED      0xFF000088
%define COLOR_DARK_BLUE     0xFF880000
%define COLOR_GRAY          0xFF888888
%define COLOR_DARK_GRAY     0xFF444444
%define COLOR_LIGHT_GRAY    0xFFCCCCCC

; Map colors
%define COLOR_GRASS         0xFF228B22
%define COLOR_RIVER_BLUE    0xFFDD8844
%define COLOR_LANE_BROWN    0xFF3388AA
%define COLOR_WALL_GRAY     0xFF555555
%define COLOR_BASE_BLUE     0xFFCC6633
%define COLOR_BASE_RED      0xFF3333CC
%define COLOR_JUNGLE_GREEN  0xFF115511
%define COLOR_BUSH_GREEN    0xFF009933
%define COLOR_SHOP_GOLD     0xFF00AAFF
%define COLOR_ALCOVE_DARK   0xFF334422

; UI colors
%define COLOR_HP_GREEN      0xFF00CC00
%define COLOR_HP_RED        0xFF0000CC
%define COLOR_HP_YELLOW     0xFF00CCCC
%define COLOR_MANA_BLUE     0xFFFF6600
%define COLOR_HUD_BG        0xFF222222
%define COLOR_HUD_BORDER    0xFF888888
%define COLOR_GOLD          0xFF00D4FF
%define COLOR_XP_PURPLE     0xFFCC44CC
%define COLOR_CD_OVERLAY    0xAA000000
%define COLOR_SHIELD_WHITE  0xFFEEEEFF
%define COLOR_TRUE_DMG      0xFFFFFFFF

; Team colors
%define COLOR_BLUE_TEAM     0xFFFF4422
%define COLOR_RED_TEAM      0xFF2222FF
%define COLOR_TOWER_GRAY    0xFFAAAAAA
%define COLOR_MINION_BLUE   0xFFEE8844
%define COLOR_MINION_RED    0xFF4444EE
%define COLOR_MINIMAP_BG    0xFF111111

; Fog of war
%define COLOR_FOG_FULL      0xFF000000
%define COLOR_FOG_HALF      0x88000000

; Buff colors
%define COLOR_BUFF_RED      0xFF0044FF
%define COLOR_BUFF_BLUE     0xFFFF8800
%define COLOR_BUFF_BARON    0xFF8800FF
%define COLOR_STUN_STAR     0xFFFFFFFF

; ==============================
; Champion base stats
; ==============================
%define CHAMPION_HP         1000
%define CHAMPION_HP_LVL     90      ; HP per level
%define CHAMPION_MANA       500
%define CHAMPION_MANA_LVL   40
%define CHAMPION_AD         60
%define CHAMPION_AD_LVL     3       ; AD per level
%define CHAMPION_AP         0
%define CHAMPION_ARMOR      30
%define CHAMPION_ARMOR_LVL  4
%define CHAMPION_MR         30
%define CHAMPION_MR_LVL     1
%define CHAMPION_SPEED      330
%define CHAMPION_RANGE      125
%define CHAMPION_ATK_SPD    100     ; 100 = 1.0 attacks/sec
%define CHAMPION_ATK_SPD_LVL 2     ; per level
%define CHAMPION_CRIT       0       ; crit chance %
%define CHAMPION_LIFESTEAL  0
%define CHAMPION_CDR        0
%define CHAMPION_TENACITY   0
%define CHAMPION_LETHALITY  0
%define CHAMPION_MPEN       0
%define CHAMPION_RESPAWN_BASE 180   ; 3 sec base respawn (frames)
%define CHAMPION_RESPAWN_LVL 120    ; +2 sec per level

; ==============================
; Minion stats
; ==============================
%define MINION_MELEE_HP     450
%define MINION_MELEE_AD     12
%define MINION_MELEE_ARMOR  0
%define MINION_MELEE_MR     0
%define MINION_MELEE_SPEED  250
%define MINION_MELEE_RANGE  50

%define MINION_CASTER_HP    300
%define MINION_CASTER_AD    25
%define MINION_CASTER_ARMOR 0
%define MINION_CASTER_MR    0
%define MINION_CASTER_SPEED 250
%define MINION_CASTER_RANGE 300

%define MINION_CANNON_HP    700
%define MINION_CANNON_AD    40
%define MINION_CANNON_ARMOR 10
%define MINION_CANNON_MR    10
%define MINION_CANNON_SPEED 250
%define MINION_CANNON_RANGE 250

%define MINION_SUPER_HP     1500
%define MINION_SUPER_AD     50
%define MINION_SUPER_ARMOR  30
%define MINION_SUPER_MR     30
%define MINION_SUPER_SPEED  300
%define MINION_SUPER_RANGE  50

; ==============================
; Tower stats
; ==============================
%define TOWER_HP            3000
%define TOWER_AD            150
%define TOWER_AD_RAMP       40      ; +40 per consecutive hit
%define TOWER_RANGE         400
%define TOWER_ATK_SPD       83
%define TOWER_ARMOR         40
%define TOWER_MR            40
%define TOWER_PLATES_COUNT  5
%define TOWER_PLATE_HP      600     ; each plate at 600 HP intervals
%define TOWER_PLATE_GOLD    160

; Tower aggro priorities
%define AGGRO_MINION        1
%define AGGRO_PET           2
%define AGGRO_CHAMPION      3

; ==============================
; Nexus / Inhibitor
; ==============================
%define NEXUS_HP            5000
%define NEXUS_ARMOR         20
%define NEXUS_MR            20

%define INHIBITOR_HP        3000
%define INHIBITOR_ARMOR     20
%define INHIBITOR_MR        20
%define INHIBITOR_RESPAWN   18000   ; 5 minutes at 60fps

; ==============================
; Jungle monsters
; ==============================
%define GROMP_HP            1800
%define GROMP_AD            70
%define WOLVES_HP           1200
%define WOLVES_AD           40
%define RAPTORS_HP          900
%define RAPTORS_AD          25
%define KRUGS_HP            1500
%define KRUGS_AD            60

%define BLUE_BUFF_HP        2100
%define BLUE_BUFF_AD        75
%define RED_BUFF_HP         2100
%define RED_BUFF_AD         75

%define DRAGON_HP           5000
%define DRAGON_AD           100
%define DRAGON_ARMOR        30
%define DRAGON_MR           30

%define BARON_HP            12000
%define BARON_AD            300
%define BARON_ARMOR         120
%define BARON_MR            70

%define HERALD_HP           8000
%define HERALD_AD           100

; Spawn times (in frames at 60fps)
%define JUNGLE_SPAWN_TIME   90      ; 1.5 sec (initial)
%define JUNGLE_RESPAWN      7200    ; 2 min respawn
%define DRAGON_SPAWN        18000   ; 5 min
%define DRAGON_RESPAWN      18000   ; 5 min respawn
%define BARON_SPAWN         72000   ; 20 min
%define BARON_RESPAWN       21600   ; 6 min respawn
%define HERALD_SPAWN        28800   ; 8 min

; ==============================
; Gold economy
; ==============================
%define GOLD_PER_MINION_MELEE  21
%define GOLD_PER_MINION_CASTER 14
%define GOLD_PER_MINION_CANNON 60
%define GOLD_PER_CHAMPION   300
%define GOLD_PER_TOWER      150
%define GOLD_PER_DRAGON     200
%define GOLD_PER_BARON      300
%define GOLD_PER_HERALD     100
%define GOLD_PER_PLATE      160
%define GOLD_PER_INHIB      50
%define GOLD_PASSIVE_RATE   30      ; frames between passive gold (0.5 sec)
%define GOLD_PASSIVE_AMOUNT 1
%define STARTING_GOLD       500

; Legacy aliases (used by game.asm)
%define GOLD_PER_MINION     GOLD_PER_MINION_MELEE
%define CHAMPION_RESPAWN    600     ; 10 sec base respawn (frames)

; Bounty system
%define BOUNTY_BASE         300
%define BOUNTY_PER_KILL     100     ; extra gold per kill streak
%define BOUNTY_MAX          1000

; Assist gold
%define ASSIST_GOLD_PCT     50      ; 50% of kill gold to assists

; ==============================
; Wave spawning
; ==============================
%define MINION_WAVE_INTERVAL 1800   ; 30 sec at 60fps
%define MINIONS_PER_WAVE    6       ; melee
%define CASTERS_PER_WAVE    3       ; caster
%define CANNON_WAVE_FREQ    3       ; cannon every N waves
%define CANNON_WAVE_LATE    1       ; cannon every wave after 25 min

; ==============================
; Level / XP system
; ==============================
%define MAX_LEVEL           18
%define XP_PER_MINION       60
%define XP_PER_CANNON       90
%define XP_PER_CHAMPION     200
%define XP_PER_JUNGLE       100
%define XP_RANGE            1600    ; max distance to gain XP
%define ABILITY_POINTS_INIT 1       ; start with 1 point

; XP required per level (cumulative, stored in data.asm)
; Level 2: 280, Level 3: 660, ... Level 18: 17850

; Ability max ranks
%define ABILITY_MAX_RANK    5
%define ULTIMATE_MAX_RANK   3
%define ULT_UNLOCK_LVL     6       ; can put first point in R at level 6
%define ULT_LVL_2           11
%define ULT_LVL_3           16

; ==============================
; Recall
; ==============================
%define RECALL_CHANNEL_TIME 480     ; 8 seconds at 60fps
%define RECALL_HEAL_PCT     100     ; heal to full on recall

; ==============================
; Summoner spell cooldowns (frames)
; ==============================
%define FLASH_CD            18000   ; 300 sec
%define FLASH_RANGE         400
%define IGNITE_CD           10800   ; 180 sec
%define IGNITE_DURATION     300     ; 5 sec
%define IGNITE_TOTAL_DMG    410     ; at level 18
%define HEAL_CD             14400   ; 240 sec
%define HEAL_AMOUNT         300
%define TELEPORT_CD         21600   ; 360 sec
%define TELEPORT_CHANNEL    240     ; 4 sec
%define SMITE_CD            5400    ; 90 sec
%define SMITE_DMG           900
%define BARRIER_CD          10800   ; 180 sec
%define BARRIER_SHIELD      300
%define BARRIER_DURATION    150     ; 2.5 sec
%define EXHAUST_CD          12600   ; 210 sec
%define EXHAUST_DURATION    180     ; 3 sec
%define EXHAUST_SLOW_PCT    30
%define EXHAUST_DMG_RED     40      ; 40% damage reduction
%define GHOST_CD            12600   ; 210 sec
%define GHOST_DURATION      600     ; 10 sec
%define GHOST_SPEED_PCT     24
%define CLEANSE_CD          12600   ; 210 sec

; ==============================
; Vision system
; ==============================
%define VISION_RADIUS       1200    ; base vision radius
%define TOWER_VISION        1000
%define WARD_VISION         900
%define WARD_DURATION       5400    ; 90 sec
%define CONTROL_WARD_VIS    900
%define SWEEPER_RADIUS      600
%define SWEEPER_DURATION    360     ; 6 sec
%define MAX_STEALTH_WARDS   3
%define MAX_CONTROL_WARDS   1
%define BUSH_VISION_BLOCK   1       ; 1 = bushes block vision

; ==============================
; Game timing
; ==============================
%define TARGET_FPS          60
%define FRAME_TIME_NS       16666667
%define GAME_TICK_RATE      60

; ==============================
; Rendering
; ==============================
%define ENTITY_RADIUS       14      ; champion circle radius
%define MINION_RADIUS       8
%define TOWER_RADIUS        18
%define NEXUS_RADIUS        24
%define INHIB_RADIUS        16
%define JUNGLE_RADIUS       12
%define DRAGON_RADIUS       20
%define BARON_RADIUS        24
%define WARD_RADIUS         4
%define PROJECTILE_RADIUS   4

%define HP_BAR_WIDTH        32
%define HP_BAR_HEIGHT       4
%define HP_BAR_OFFSET       20
%define HP_SEGMENT_SIZE     100     ; each segment = 100 HP

%define DAMAGE_NUM_LIFETIME 45      ; frames floating damage lasts
%define DAMAGE_NUM_SPEED    1       ; pixels per frame upward

; ==============================
; HUD layout
; ==============================
%define HUD_HEIGHT          120
%define HUD_Y               (WINDOW_HEIGHT - HUD_HEIGHT)
%define MINIMAP_SIZE        160
%define MINIMAP_X           (WINDOW_WIDTH - MINIMAP_SIZE - 10)
%define MINIMAP_Y           (HUD_Y + 5)

; Ability icons
%define ABILITY_ICON_SIZE   32
%define ABILITY_ICON_Y      (HUD_Y + 10)
%define ABILITY_ICON_X      480     ; starting X for Q
%define ABILITY_ICON_GAP    6

; Item slots
%define ITEM_SLOT_SIZE      24
%define ITEM_SLOT_Y         (HUD_Y + 55)
%define ITEM_SLOT_X         460
%define ITEM_SLOT_GAP       4

; Summoner spell icons
%define SUMM_ICON_SIZE      24
%define SUMM_ICON_Y         (HUD_Y + 10)
%define SUMM_ICON_X         430

; Portrait
%define PORTRAIT_SIZE       48
%define PORTRAIT_X          10
%define PORTRAIT_Y          (HUD_Y + 10)

; Stats panel
%define STATS_X             70
%define STATS_Y             (HUD_Y + 10)

; ==============================
; Camera
; ==============================
%define CAMERA_EDGE_SCROLL  30
%define CAMERA_SCROLL_SPEED 10
%define CAMERA_SMOOTH_FACTOR 8      ; for smooth camera interpolation

; ==============================
; Scoreboard
; ==============================
%define SCOREBOARD_X        200
%define SCOREBOARD_Y        50
%define SCOREBOARD_W        880
%define SCOREBOARD_H        500
%define SCOREBOARD_ROW_H    36

; ==============================
; Key codes (X11 keycodes)
; ==============================
%define KEY_ESCAPE  9
%define KEY_Q       24
%define KEY_W       25
%define KEY_E       26
%define KEY_R       27
%define KEY_D       40
%define KEY_F       41
%define KEY_A       38
%define KEY_S       39
%define KEY_B       56
%define KEY_H       43
%define KEY_P       33
%define KEY_TAB     23
%define KEY_SPACE   65
%define KEY_1       10
%define KEY_2       11
%define KEY_3       12
%define KEY_4       13
%define KEY_5       14
%define KEY_6       15
%define KEY_7       16
%define KEY_CTRL_L  37
%define KEY_SHIFT_L 50
%define KEY_ALT_L   64
%define KEY_G       42
%define KEY_Y       29
%define KEY_N       57
%define KEY_ENTER   36

; ==============================
; Mouse buttons
; ==============================
%define MOUSE_LEFT      1
%define MOUSE_MIDDLE    2
%define MOUSE_RIGHT     3
%define MOUSE_SCROLL_UP 4
%define MOUSE_SCROLL_DN 5

%endif
