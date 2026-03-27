; ============================================================================
; items.asm - Item system and shop
; Tasks 4.01-4.10: Inventory, shop, item DB, build paths, actives
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_speed, ent_atk_speed, ent_range
extern ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_count
extern ent_armor, ent_mr, ent_ap, ent_cdr
extern ent_crit_chance, ent_crit_mult, ent_lifesteal, ent_lethality
extern ent_magic_pen_flat, ent_armor_pen_pct

section .data

; ============================================================================
; Item database
; Each item: cost(4), ad(4), ap(4), hp(4), mana(4), armor(4), mr(4),
;            atk_spd(4), crit(4), lifesteal(4), cdr(4), speed(4),
;            lethality(4), mpen(4), armor_pen_pct(4), active_id(4)
;            = 64 bytes per item
; ============================================================================

align 64
global item_db
item_db:

; ITEM_NONE (0)
times 64 db 0

; ITEM_DORANS_BLADE (1)
    dd 450     ; cost
    dd 8       ; ad
    dd 0       ; ap
    dd 80      ; hp
    dd 0,0,0   ; mana, armor, mr
    dd 0       ; atk_spd
    dd 0       ; crit
    dd 3       ; lifesteal %
    dd 0,0,0,0,0,0  ; cdr, speed, lethality, mpen, armor_pen, active
; ITEM_DORANS_RING (2)
    dd 400, 0, 15, 70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_DORANS_SHIELD (3)
    dd 450, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_LONG_SWORD (4)
    dd 350, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_AMP_TOME (5)
    dd 435, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_CLOTH_ARMOR (6)
    dd 300, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_NULL_MAGIC (7)
    dd 450, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_BOOTS (8)
    dd 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0
; ITEM_RUBY_CRYSTAL (9)
    dd 400, 0, 0, 150, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_SAPPHIRE_CRYST (10)
    dd 350, 0, 0, 0, 250, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_REFILL_POTION (11)
    dd 150, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_HEALTH_POTION (12)
    dd 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Padding for items 13-19
times 7 * 64 db 0

; ITEM_BF_SWORD (20)
    dd 1300, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_PICKAXE (21)
    dd 875, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_INFINITY_EDGE (22)
    dd 3400, 70, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0
; ITEM_BLOODTHIRSTER (23)
    dd 3400, 55, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0
; ITEM_BLADE_RUINED (24)
    dd 3300, 40, 0, 0, 0, 0, 0, 25, 0, 10, 0, 0, 0, 0, 0, 1
; ITEM_YOUMUUS (25)
    dd 3000, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 18, 0, 0, 2
; ITEM_DEATHS_DANCE (26)
    dd 3100, 55, 0, 0, 0, 15, 15, 0, 0, 0, 15, 0, 0, 0, 0, 0
; ITEM_BLACK_CLEAVER (27)
    dd 3100, 40, 0, 350, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 30, 0
; ITEM_COLLECTOR (28)
    dd 3000, 55, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 12, 0, 0, 0
; ITEM_PHANTOM_DANCER (29)
    dd 2600, 20, 0, 0, 0, 0, 0, 35, 20, 0, 0, 7, 0, 0, 0, 0

; Padding for items 30-39
times 10 * 64 db 0

; ITEM_NEEDLESS_ROD (40)
    dd 1250, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_LOST_CHAPTER (41)
    dd 1300, 0, 40, 0, 300, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0
; ITEM_RABADONS (42)
    dd 3600, 0, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_LUDENS (43)
    dd 3200, 0, 80, 0, 600, 0, 0, 0, 0, 0, 20, 0, 0, 6, 0, 0
; ITEM_ZHONYAS (44)
    dd 2600, 0, 65, 0, 0, 15, 0, 0, 0, 0, 10, 0, 0, 0, 0, 3
; ITEM_VOID_STAFF (45)
    dd 2800, 0, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  ; +40% mpen handled separately
; ITEM_MORELLOS (46)
    dd 2500, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 15, 0, 0
; ITEM_BANSHEES (47)
    dd 2600, 0, 65, 0, 0, 0, 45, 0, 0, 0, 10, 0, 0, 0, 0, 0
; ITEM_LICH_BANE (48)
    dd 3000, 0, 75, 0, 0, 0, 0, 0, 0, 0, 10, 4, 0, 0, 0, 0
; ITEM_RYLAIS (49)
    dd 2600, 0, 75, 350, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Padding for items 50-59
times 10 * 64 db 0

; ITEM_CHAIN_VEST (60)
    dd 800, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_WARDENS_MAIL (61)
    dd 1000, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_THORNMAIL (62)
    dd 2700, 0, 0, 350, 0, 70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_SUNFIRE (63)
    dd 2700, 0, 0, 450, 0, 35, 35, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ITEM_RANDUINS (64)
    dd 2700, 0, 0, 250, 0, 70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4
; ITEM_DEAD_MANS (65)
    dd 2900, 0, 0, 300, 0, 45, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0
; ITEM_SPIRIT_VISAGE (66)
    dd 2900, 0, 0, 450, 0, 0, 60, 0, 0, 0, 10, 0, 0, 0, 0, 0
; ITEM_FORCE_NATURE (67)
    dd 2900, 0, 0, 350, 0, 0, 70, 0, 0, 0, 0, 5, 0, 0, 0, 0
; ITEM_GARGOYLE (68)
    dd 3200, 0, 0, 0, 0, 60, 60, 0, 0, 0, 0, 0, 0, 0, 0, 5
; ITEM_WARMOGS (69)
    dd 3000, 0, 0, 800, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0

; Padding for items 70-79
times 10 * 64 db 0

; ITEM_BERSERKERS (80)
    dd 1100, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 45, 0, 0, 0, 0
; ITEM_SORC_SHOES (81)
    dd 1100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 45, 0, 18, 0, 0
; ITEM_TABIS (82)
    dd 1100, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 45, 0, 0, 0, 0
; ITEM_MERCS (83)
    dd 1100, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 45, 0, 0, 0, 0  ; +30% tenacity handled separately
; ITEM_LUCIDITY (84)
    dd 950, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 45, 0, 0, 0, 0
; ITEM_SWIFTIES (85)
    dd 900, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60, 0, 0, 0, 0

; Padding for items 86-89
times 4 * 64 db 0

; ITEM_REDEMPTION (90)
    dd 2300, 0, 0, 200, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 6
; ITEM_LOCKET (91)
    dd 2500, 0, 0, 200, 0, 30, 30, 0, 0, 0, 0, 0, 0, 0, 0, 7
; ITEM_MIKAELS (92)
    dd 2300, 0, 0, 0, 0, 0, 40, 0, 0, 0, 15, 0, 0, 0, 0, 8
; ITEM_ARDENT (93)
    dd 2300, 0, 60, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0

; Padding for items 94-99
times 6 * 64 db 0

; ITEM_STEALTH_WARD (100)
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10
; ITEM_CONTROL_WARD (101)
    dd 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11
; ITEM_SWEEPER (102)
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12
; ITEM_FARSIGHT (103)
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13

; Remaining padding to NUM_ITEMS is implicit (bss would zero it)

section .bss

; Entity inventory (6 item slots per entity)
alignb 64
global ent_inventory
ent_inventory:  resb MAX_ENTITIES * MAX_ITEMS_PER_ENT   ; item IDs

; Trinket slot (separate from inventory)
global ent_trinket
ent_trinket:    resb MAX_ENTITIES

; Shop state
global shop_open, shop_scroll
shop_open:      resd 1          ; 1 = shop UI visible
shop_scroll:    resd 1          ; scroll position

; Cached total item stats per entity (recalculated on item change)
alignb 64
global item_bonus_ad, item_bonus_ap, item_bonus_hp, item_bonus_mana
global item_bonus_armor, item_bonus_mr, item_bonus_speed
global item_bonus_atk_spd, item_bonus_crit, item_bonus_lifesteal
global item_bonus_cdr, item_bonus_lethality, item_bonus_mpen

item_bonus_ad:      resd MAX_ENTITIES
item_bonus_ap:      resd MAX_ENTITIES
item_bonus_hp:      resd MAX_ENTITIES
item_bonus_mana:    resd MAX_ENTITIES
item_bonus_armor:   resd MAX_ENTITIES
item_bonus_mr:      resd MAX_ENTITIES
item_bonus_speed:   resd MAX_ENTITIES
item_bonus_atk_spd: resd MAX_ENTITIES
item_bonus_crit:    resd MAX_ENTITIES
item_bonus_lifesteal: resd MAX_ENTITIES
item_bonus_cdr:     resd MAX_ENTITIES
item_bonus_lethality: resd MAX_ENTITIES
item_bonus_mpen:    resd MAX_ENTITIES

section .text

; ============================================================================
; items_init - Initialize item system
; ============================================================================
global items_init
items_init:
    ; Clear inventories
    lea rdi, [rel ent_inventory]
    xor eax, eax
    mov ecx, (MAX_ENTITIES * MAX_ITEMS_PER_ENT) / 4
    rep stosd

    lea rdi, [rel ent_trinket]
    xor eax, eax
    mov ecx, MAX_ENTITIES / 4
    rep stosd

    mov dword [shop_open], 0
    mov dword [shop_scroll], 0

    ; Clear bonus caches
    lea rdi, [rel item_bonus_ad]
    xor eax, eax
    mov ecx, MAX_ENTITIES * 13     ; 13 bonus arrays
    rep stosd

    ret

; ============================================================================
; items_buy - Buy an item for entity
; edi = entity_idx, esi = item_id
; Returns: eax = 1 success, 0 failure (no gold or full inventory)
; ============================================================================
global items_buy
items_buy:
    push rbx
    push r12
    push r13

    mov r12d, edi           ; entity
    mov r13d, esi           ; item_id

    ; Check item exists
    cmp r13d, 0
    jle .buy_fail
    cmp r13d, NUM_ITEMS
    jge .buy_fail

    ; Check gold
    imul eax, r13d, 64
    lea rcx, [rel item_db]
    mov eax, [rcx + rax]           ; item cost
    lea rcx, [rel ent_gold]
    cmp eax, [rcx + r12 * 4]
    jg .buy_fail                    ; not enough gold

    ; Find empty inventory slot
    imul ebx, r12d, MAX_ITEMS_PER_ENT
    lea rcx, [rel ent_inventory]
    xor edx, edx
.find_slot:
    cmp edx, MAX_ITEMS_PER_ENT
    jge .buy_fail                   ; inventory full
    lea r8, [rcx + rbx]
    cmp byte [r8 + rdx], ITEM_NONE
    je .found_slot
    inc edx
    jmp .find_slot

.found_slot:
    ; Place item
    lea r8, [rcx + rbx]
    mov byte [r8 + rdx], r13b

    ; Deduct gold
    imul eax, r13d, 64
    lea rcx, [rel item_db]
    mov eax, [rcx + rax]
    lea rcx, [rel ent_gold]
    sub [rcx + r12 * 4], eax

    ; Recalculate stats
    mov edi, r12d
    call items_recalc_stats

    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret

.buy_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; items_sell - Sell an item from inventory slot
; edi = entity_idx, esi = slot (0-5)
; Returns: eax = 1 success
; ============================================================================
global items_sell
items_sell:
    push rbx
    push r12

    mov r12d, edi
    imul ebx, edi, MAX_ITEMS_PER_ENT
    add ebx, esi
    lea rcx, [rel ent_inventory]
    movzx eax, byte [rcx + rbx]

    cmp al, ITEM_NONE
    je .sell_fail

    ; Refund 70% of item cost
    push rcx
    movzx edx, al
    imul edx, 64
    lea rcx, [rel item_db]
    mov edx, [rcx + rdx]           ; cost
    imul edx, 70
    xor eax, eax
    push rdx
    pop rax
    xor edx, edx
    mov ecx, 100
    div ecx                         ; 70% refund
    lea rcx, [rel ent_gold]
    add [rcx + r12 * 4], eax
    pop rcx

    ; Remove item
    mov byte [rcx + rbx], ITEM_NONE

    ; Recalculate stats
    mov edi, r12d
    call items_recalc_stats

    mov eax, 1
    pop r12
    pop rbx
    ret

.sell_fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

; ============================================================================
; items_recalc_stats - Recalculate total item bonus stats for entity
; edi = entity_idx
; ============================================================================
global items_recalc_stats
items_recalc_stats:
    push rbx
    push r12
    push r13

    mov r12d, edi

    ; Zero all bonuses
    xor eax, eax
    lea rcx, [rel item_bonus_ad]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_ap]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_hp]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_mana]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_armor]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_mr]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_speed]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_atk_spd]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_crit]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_lifesteal]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_cdr]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_lethality]
    mov [rcx + r12 * 4], eax
    lea rcx, [rel item_bonus_mpen]
    mov [rcx + r12 * 4], eax

    ; Sum stats from all 6 inventory slots
    imul r13d, r12d, MAX_ITEMS_PER_ENT
    xor ebx, ebx

.slot_loop:
    cmp ebx, MAX_ITEMS_PER_ENT
    jge .recalc_apply

    lea rcx, [rel ent_inventory]
    lea r8, [rcx + r13]
    movzx eax, byte [r8 + rbx]
    test al, al
    jz .slot_next

    ; Get item data pointer
    movzx eax, al
    imul eax, 64
    lea rcx, [rel item_db]
    add rcx, rax            ; rcx = item data

    ; Add each stat
    mov eax, [rcx + 4]      ; ad
    lea rdx, [rel item_bonus_ad]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 8]      ; ap
    lea rdx, [rel item_bonus_ap]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 12]     ; hp
    lea rdx, [rel item_bonus_hp]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 16]     ; mana
    lea rdx, [rel item_bonus_mana]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 20]     ; armor
    lea rdx, [rel item_bonus_armor]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 24]     ; mr
    lea rdx, [rel item_bonus_mr]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 28]     ; atk_spd
    lea rdx, [rel item_bonus_atk_spd]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 32]     ; crit
    lea rdx, [rel item_bonus_crit]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 36]     ; lifesteal
    lea rdx, [rel item_bonus_lifesteal]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 40]     ; cdr
    lea rdx, [rel item_bonus_cdr]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 44]     ; speed
    lea rdx, [rel item_bonus_speed]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 48]     ; lethality
    lea rdx, [rel item_bonus_lethality]
    add [rdx + r12 * 4], eax

    mov eax, [rcx + 52]     ; mpen
    lea rdx, [rel item_bonus_mpen]
    add [rdx + r12 * 4], eax

.slot_next:
    inc ebx
    jmp .slot_loop

.recalc_apply:
    ; Apply item bonuses to entity stats
    ; AD = base_ad + item_bonus_ad
    ; (simplified: just add item bonuses directly to combat stats)
    lea rax, [rel item_bonus_ad]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_atk]
    ; Note: we'd need base stats to properly recalculate
    ; For now, item bonuses are stored separately and combat system adds them

    ; Apply AP from items
    lea rax, [rel item_bonus_ap]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_ap]
    mov [rax + r12 * 4], ecx

    ; Apply crit from items
    lea rax, [rel item_bonus_crit]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_crit_chance]
    mov [rax + r12 * 4], ecx

    ; Apply lifesteal
    lea rax, [rel item_bonus_lifesteal]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_lifesteal]
    mov [rax + r12 * 4], ecx

    ; Apply CDR (cap at 40)
    lea rax, [rel item_bonus_cdr]
    mov ecx, [rax + r12 * 4]
    cmp ecx, 40
    jle .cdr_ok
    mov ecx, 40
.cdr_ok:
    lea rax, [rel ent_cdr]
    mov [rax + r12 * 4], ecx

    ; Apply lethality
    lea rax, [rel item_bonus_lethality]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_lethality]
    mov [rax + r12 * 4], ecx

    ; Apply magic pen
    lea rax, [rel item_bonus_mpen]
    mov ecx, [rax + r12 * 4]
    lea rax, [rel ent_magic_pen_flat]
    mov [rax + r12 * 4], ecx

    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; items_toggle_shop - Toggle shop UI
; ============================================================================
global items_toggle_shop
items_toggle_shop:
    xor dword [shop_open], 1
    ret
