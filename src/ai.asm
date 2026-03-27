; ============================================================================
; ai.asm - AI Bot System
; Phase 10: Lane bots, jungler AI, ability usage, item buying AI
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_target_x, ent_target_y
extern ent_hp, ent_max_hp, ent_mana, ent_max_mana
extern ent_atk, ent_range, ent_speed, ent_atk_speed
extern ent_atk_target, ent_type, ent_team, ent_state, ent_active
extern ent_gold, ent_level, ent_count
extern entity_spawn, entity_set_stats
extern math_distance
extern abilities_cast
extern items_buy
extern game_frame

; ============================================================================
; Data section
; ============================================================================
section .data

; Target positions for blue team bots per lane (x, y pairs)
align 8
ai_lane_targets_blue:
    ; Top lane target
    dd MAP_PIXEL_WIDTH / 2, 400
    ; Mid lane target
    dd MAP_PIXEL_WIDTH - 500, 500
    ; Bot lane target
    dd MAP_PIXEL_WIDTH - 400, MAP_PIXEL_HEIGHT / 2

; Target positions for red team bots per lane (x, y pairs)
align 8
ai_lane_targets_red:
    ; Top lane target
    dd 400, MAP_PIXEL_HEIGHT / 2
    ; Mid lane target
    dd 500, MAP_PIXEL_HEIGHT - 500
    ; Bot lane target
    dd MAP_PIXEL_WIDTH / 2, MAP_PIXEL_HEIGHT - 400

; Blue base retreat position
ai_blue_base_x: dd 400
ai_blue_base_y: dd MAP_PIXEL_HEIGHT - 400

; Red base retreat position
ai_red_base_x: dd MAP_PIXEL_WIDTH - 400
ai_red_base_y: dd 400

; ============================================================================
; BSS section
; ============================================================================
section .bss

alignb 64
global ai_bot_indices, ai_bot_count, ai_decision_timer, ai_bot_role
ai_bot_indices:      resd 9          ; entity indices of the 9 AI bots (-1 = none)
ai_bot_count:        resd 1
ai_decision_timer:   resd 9          ; frames until next decision per bot
ai_bot_role:         resb 9          ; 0=top, 1=mid, 2=bot, 3=jungler, 4=support

; ============================================================================
; Text section
; ============================================================================
section .text

; ============================================================================
; ai_init - Spawn 9 AI-controlled champion bots
; Blue team: entities 1-4 (top/mid/bot/jungler)
; Red team: entities 5-9 (top/mid/bot/jungler/support)
; ============================================================================
global ai_init
ai_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; align stack to 16

    ; Initialize all bot indices to -1
    lea rdi, [rel ai_bot_indices]
    mov ecx, 9
    mov eax, -1
.init_indices:
    mov [rdi + rcx * 4 - 4], eax
    dec ecx
    jnz .init_indices

    xor r14d, r14d                  ; bot counter

    ; ---------------------------------------------------------------
    ; Blue team bots (4 bots: top, mid, bot, jungler)
    ; ---------------------------------------------------------------

    ; Blue bot 0 - Top lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    mov eax, 300
    vcvtsi2sd xmm0, xmm0, eax      ; x = 300
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 600
    vcvtsi2sd xmm1, xmm1, eax      ; y = map_height - 600
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 0         ; top
    call .set_champion_stats
    inc r14d

    ; Blue bot 1 - Mid lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    mov eax, 500
    vcvtsi2sd xmm0, xmm0, eax      ; x = 500
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 500
    vcvtsi2sd xmm1, xmm1, eax      ; y = map_height - 500
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 1         ; mid
    call .set_champion_stats
    inc r14d

    ; Blue bot 2 - Bot lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    mov eax, 600
    vcvtsi2sd xmm0, xmm0, eax      ; x = 600
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 300
    vcvtsi2sd xmm1, xmm1, eax      ; y = map_height - 300
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 2         ; bot
    call .set_champion_stats
    inc r14d

    ; Blue bot 3 - Jungler
    mov edi, ENT_CHAMPION
    mov esi, TEAM_BLUE
    mov eax, 800
    vcvtsi2sd xmm0, xmm0, eax      ; x = 800
    mov eax, MAP_PIXEL_HEIGHT
    sub eax, 800
    vcvtsi2sd xmm1, xmm1, eax      ; y = map_height - 800
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 3         ; jungler
    call .set_champion_stats
    inc r14d

    ; ---------------------------------------------------------------
    ; Red team bots (5 bots: top, mid, bot, jungler, support)
    ; ---------------------------------------------------------------

    ; Red bot 4 - Top lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 300
    vcvtsi2sd xmm0, xmm0, eax      ; x = map_width - 300
    mov eax, 600
    vcvtsi2sd xmm1, xmm1, eax      ; y = 600
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 0         ; top
    call .set_champion_stats
    inc r14d

    ; Red bot 5 - Mid lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 500
    vcvtsi2sd xmm0, xmm0, eax      ; x = map_width - 500
    mov eax, 500
    vcvtsi2sd xmm1, xmm1, eax      ; y = 500
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 1         ; mid
    call .set_champion_stats
    inc r14d

    ; Red bot 6 - Bot lane
    mov edi, ENT_CHAMPION
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 600
    vcvtsi2sd xmm0, xmm0, eax      ; x = map_width - 600
    mov eax, 300
    vcvtsi2sd xmm1, xmm1, eax      ; y = 300
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 2         ; bot
    call .set_champion_stats
    inc r14d

    ; Red bot 7 - Jungler
    mov edi, ENT_CHAMPION
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 800
    vcvtsi2sd xmm0, xmm0, eax      ; x = map_width - 800
    mov eax, 800
    vcvtsi2sd xmm1, xmm1, eax      ; y = 800
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 3         ; jungler
    call .set_champion_stats
    inc r14d

    ; Red bot 8 - Support
    mov edi, ENT_CHAMPION
    mov esi, TEAM_RED
    mov eax, MAP_PIXEL_WIDTH
    sub eax, 700
    vcvtsi2sd xmm0, xmm0, eax      ; x = map_width - 700
    mov eax, 400
    vcvtsi2sd xmm1, xmm1, eax      ; y = 400
    call entity_spawn
    mov r12d, eax
    lea rdi, [rel ai_bot_indices]
    mov [rdi + r14 * 4], r12d
    lea rdi, [rel ai_bot_role]
    mov byte [rdi + r14], 4         ; support
    call .set_champion_stats
    inc r14d

    ; Set bot count
    mov dword [rel ai_bot_count], 9

    ; Initialize decision timers to 30 frames (0.5s at 60fps)
    lea rdi, [rel ai_decision_timer]
    mov ecx, 9
    mov eax, 30
.init_timers:
    mov [rdi + rcx * 4 - 4], eax
    dec ecx
    jnz .init_timers

    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Helper: set champion stats and starting gold for entity in r12d
.set_champion_stats:
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
    ret

; ============================================================================
; ai_update - Called each frame, drives all AI bot decisions
; ============================================================================
global ai_update
ai_update:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; align stack to 16

    mov dword [rsp], 0              ; current bot index on stack
    xor r15d, r15d                  ; r15 = bot loop counter

.bot_loop:
    cmp r15d, 9
    jge .bot_loop_done

    ; Load entity index for this bot
    lea rax, [rel ai_bot_indices]
    mov r12d, [rax + r15 * 4]      ; r12d = entity index

    ; Skip if index is -1 (no bot)
    cmp r12d, -1
    je .bot_next

    ; Skip if not active
    lea rax, [rel ent_active]
    movzx eax, byte [rax + r12]
    test eax, eax
    jz .bot_next

    ; Skip if dead
    lea rax, [rel ent_state]
    movzx eax, byte [rax + r12]
    cmp eax, STATE_DEAD
    je .bot_next

    ; Decrement decision timer
    lea rax, [rel ai_decision_timer]
    mov ecx, [rax + r15 * 4]
    dec ecx
    mov [rax + r15 * 4], ecx
    cmp ecx, 0
    jg .bot_check_periodic          ; timer not expired, skip decision

    ; Timer expired - reset to 60 frames (1 second)
    lea rax, [rel ai_decision_timer]
    mov dword [rax + r15 * 4], 60

    ; ---------------------------------------------------------------
    ; Decision logic
    ; ---------------------------------------------------------------

    ; (a) Check if HP < 30% of max_hp -> retreat
    lea rax, [rel ent_hp]
    mov ecx, [rax + r12 * 4]       ; current HP
    lea rax, [rel ent_max_hp]
    mov edx, [rax + r12 * 4]       ; max HP

    ; Calculate 30% of max_hp: (max_hp * 30) / 100
    ; Use two-operand imul to avoid three-register form
    mov eax, edx
    imul eax, 30
    mov ebx, 100
    xor edx, edx
    div ebx                         ; eax = 30% of max_hp
    cmp ecx, eax
    jl .retreat                     ; HP < 30%, retreat

    ; (b/c) Find nearest enemy
    mov ebx, r12d                   ; rbx = bot entity index
    call ai_find_nearest_enemy      ; returns r12d preserved, result in r13d (nearest idx)
    ; Note: ai_find_nearest_enemy uses rbx as bot index, returns r12d = nearest

    ; We saved bot entity index; restore context
    ; r12d still has our entity index (callee-saved via push in find_nearest)
    ; Result is in eax after the call
    mov r13d, eax                   ; r13d = nearest enemy index

    cmp r13d, -1
    je .move_to_lane                ; no enemy found, go to lane

    ; Enemy found - check if in attack range
    lea rax, [rel ent_range]
    mov ebx, [rax + r12 * 4]       ; our attack range

    ; Get distance to nearest enemy (integer approximation)
    ; |dx| + |dy| is a fast approximation (Manhattan distance)
    lea rax, [rel ent_x]
    movsd xmm0, [rax + r12 * 8]
    lea rax, [rel ent_x]
    movsd xmm2, [rax + r13 * 8]
    vsubsd xmm4, xmm0, xmm2        ; dx
    ; absolute value
    vpand xmm4, xmm4, [rel abs_mask]

    lea rax, [rel ent_y]
    movsd xmm1, [rax + r12 * 8]
    lea rax, [rel ent_y]
    movsd xmm3, [rax + r13 * 8]
    vsubsd xmm5, xmm1, xmm3        ; dy
    vpand xmm5, xmm5, [rel abs_mask]

    vaddsd xmm4, xmm4, xmm5        ; manhattan distance
    vcvtsi2sd xmm6, xmm6, ebx      ; range as double
    vucomisd xmm6, xmm4             ; range >= distance?
    jae .attack_enemy               ; in range -> attack

    ; Out of range -> move toward enemy
    lea rax, [rel ent_x]
    movsd xmm0, [rax + r13 * 8]    ; enemy x
    lea rax, [rel ent_target_x]
    movsd [rax + r12 * 8], xmm0

    lea rax, [rel ent_y]
    movsd xmm0, [rax + r13 * 8]    ; enemy y
    lea rax, [rel ent_target_y]
    movsd [rax + r12 * 8], xmm0

    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_MOVING
    jmp .bot_check_periodic

.attack_enemy:
    ; Set attack target and state
    lea rax, [rel ent_atk_target]
    mov [rax + r12 * 4], r13d
    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_ATTACKING
    jmp .bot_check_periodic

.retreat:
    ; Move toward own base
    lea rax, [rel ent_team]
    movzx ecx, byte [rax + r12]
    test ecx, ecx
    jnz .retreat_red

    ; Blue team retreats to blue base
    mov eax, [rel ai_blue_base_x]
    vcvtsi2sd xmm0, xmm0, eax
    lea rax, [rel ent_target_x]
    movsd [rax + r12 * 8], xmm0

    mov eax, [rel ai_blue_base_y]
    vcvtsi2sd xmm0, xmm0, eax
    lea rax, [rel ent_target_y]
    movsd [rax + r12 * 8], xmm0
    jmp .retreat_set_state

.retreat_red:
    ; Red team retreats to red base
    mov eax, [rel ai_red_base_x]
    vcvtsi2sd xmm0, xmm0, eax
    lea rax, [rel ent_target_x]
    movsd [rax + r12 * 8], xmm0

    mov eax, [rel ai_red_base_y]
    vcvtsi2sd xmm0, xmm0, eax
    lea rax, [rel ent_target_y]
    movsd [rax + r12 * 8], xmm0

.retreat_set_state:
    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_MOVING
    jmp .bot_check_periodic

.move_to_lane:
    ; Move toward lane target based on role and team
    lea rax, [rel ai_bot_role]
    movzx ecx, byte [rax + r15]    ; role (0=top, 1=mid, 2=bot, 3=jg, 4=sup)

    ; Jungler and support use mid lane targets as fallback
    cmp ecx, 3
    jl .lane_valid
    mov ecx, 1                      ; jungler/support -> mid lane target
.lane_valid:
    ; ecx = lane index (0-2), each entry is 2 dwords (8 bytes)
    mov eax, ecx
    shl eax, 3                      ; eax = lane * 8 (offset into target array)

    lea rax, [rel ent_team]
    movzx edx, byte [rax + r12]
    test edx, edx
    jnz .lane_red

    ; Blue team lane targets
    lea rsi, [rel ai_lane_targets_blue]
    jmp .lane_set_target

.lane_red:
    lea rsi, [rel ai_lane_targets_red]

.lane_set_target:
    ; eax = offset into lane target array
    movsxd rax, eax
    mov ecx, [rsi + rax]            ; target x (dword)
    vcvtsi2sd xmm0, xmm0, ecx
    lea rdi, [rel ent_target_x]
    movsd [rdi + r12 * 8], xmm0

    mov ecx, [rsi + rax + 4]        ; target y (dword)
    vcvtsi2sd xmm0, xmm0, ecx
    lea rdi, [rel ent_target_y]
    movsd [rdi + r12 * 8], xmm0

    lea rax, [rel ent_state]
    mov byte [rax + r12], STATE_MOVING

.bot_check_periodic:
    ; ---------------------------------------------------------------
    ; Periodic item buying: every 600 frames (10 sec)
    ; ---------------------------------------------------------------
    mov eax, [rel game_frame]
    xor edx, edx
    mov ecx, 600
    div ecx                         ; edx = frame % 600
    test edx, edx
    jnz .check_ability

    ; Check if gold >= 450 (cost of ITEM_LONG_SWORD)
    lea rax, [rel ent_gold]
    mov ecx, [rax + r12 * 4]
    cmp ecx, 450
    jl .check_ability

    ; Try to buy ITEM_LONG_SWORD
    mov edi, r12d
    mov esi, ITEM_LONG_SWORD
    call items_buy

.check_ability:
    ; ---------------------------------------------------------------
    ; Periodic ability usage: every 300 frames (5 sec)
    ; ---------------------------------------------------------------
    mov eax, [rel game_frame]
    xor edx, edx
    mov ecx, 300
    div ecx                         ; edx = frame % 300
    test edx, edx
    jnz .bot_next

    ; Check if mana > 100
    lea rax, [rel ent_mana]
    mov ecx, [rax + r12 * 4]
    cmp ecx, 100
    jle .bot_next

    ; Cast Q ability (slot=SLOT_Q, target coords = -1 for self-cast)
    mov edi, r12d
    mov esi, SLOT_Q
    mov edx, -1                     ; target_x = -1 (no target)
    mov ecx, -1                     ; target_y = -1 (no target)
    call abilities_cast

.bot_next:
    inc r15d
    jmp .bot_loop

.bot_loop_done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; ai_find_nearest_enemy - Find closest active, non-dead enemy
; Input: ebx = bot entity index
; Output: eax = nearest enemy index, or -1 if none found
; Searches within 600px radius (squared distance check: 360000)
; ============================================================================
global ai_find_nearest_enemy
ai_find_nearest_enemy:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; align stack

    mov r14d, ebx                   ; r14 = our entity index
    mov r12d, -1                    ; r12 = best enemy index (-1 = none)

    ; 600^2 = 360000 as squared distance threshold
    mov r13d, 360000                ; r13 = best distance squared (init to threshold)

    ; Get our team
    lea rax, [rel ent_team]
    movzx r15d, byte [rax + r14]   ; r15 = our team

    ; Get our position as integers for fast comparison
    lea rax, [rel ent_x]
    movsd xmm0, [rax + r14 * 8]
    vcvtsd2si ebx, xmm0            ; ebx = our x (int)

    lea rax, [rel ent_y]
    movsd xmm0, [rax + r14 * 8]
    vcvtsd2si ecx, xmm0            ; ecx = our y (int), save in stack area
    mov [rsp], ecx                  ; save our_y on stack

    xor ecx, ecx                    ; ecx = search index

.search_loop:
    cmp ecx, [rel ent_count]
    jge .search_done

    ; Skip self
    cmp ecx, r14d
    je .search_next

    ; Skip inactive
    lea rax, [rel ent_active]
    cmp byte [rax + rcx], 0
    je .search_next

    ; Skip dead
    lea rax, [rel ent_state]
    cmp byte [rax + rcx], STATE_DEAD
    je .search_next

    ; Skip same team
    lea rax, [rel ent_team]
    movzx edx, byte [rax + rcx]
    cmp edx, r15d
    je .search_next

    ; Calculate squared distance (integer)
    lea rax, [rel ent_x]
    movsd xmm0, [rax + rcx * 8]
    vcvtsd2si edx, xmm0            ; edx = enemy x
    sub edx, ebx                    ; dx = enemy_x - our_x
    imul edx, edx                   ; dx^2

    push rcx                        ; save loop counter
    lea rax, [rel ent_y]
    movsd xmm0, [rax + rcx * 8]
    vcvtsd2si eax, xmm0            ; eax = enemy y
    mov ecx, [rsp + 8]             ; our_y from stack (offset by push)
    sub eax, ecx                    ; dy = enemy_y - our_y
    imul eax, eax                   ; dy^2
    pop rcx                         ; restore loop counter

    add edx, eax                    ; dist_sq = dx^2 + dy^2

    ; Check if within radius and closer than current best
    cmp edx, r13d
    jge .search_next

    ; New closest enemy
    mov r12d, ecx                   ; best index
    mov r13d, edx                   ; best distance squared

.search_next:
    inc ecx
    jmp .search_loop

.search_done:
    mov eax, r12d                   ; return best index (or -1)

    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; Read-only data for absolute value mask (double precision)
; ============================================================================
section .data
align 16
abs_mask:
    dq 0x7FFFFFFFFFFFFFFF           ; mask to clear sign bit of double
    dq 0x7FFFFFFFFFFFFFFF
