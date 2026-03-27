; ============================================================================
; map.asm - Tile-based map rendering with camera scrolling
; Summoner's Rift inspired layout
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern render_rect
extern camera_x, camera_y
extern framebuffer

section .data

; Tile color lookup table (indexed by tile type)
align 64
tile_colors:
    dd COLOR_GRASS          ; 0 = TILE_GRASS
    dd COLOR_RIVER_BLUE     ; 1 = TILE_RIVER
    dd COLOR_WALL_GRAY      ; 2 = TILE_WALL
    dd COLOR_LANE_BROWN     ; 3 = TILE_LANE
    dd COLOR_BASE_BLUE      ; 4 = TILE_BASE_BLUE
    dd COLOR_BASE_RED       ; 5 = TILE_BASE_RED
    dd COLOR_JUNGLE_GREEN   ; 6 = TILE_JUNGLE
    dd COLOR_BUSH_GREEN     ; 7 = TILE_BUSH
    dd COLOR_SHOP_GOLD      ; 8 = TILE_SHOP_BLUE
    dd COLOR_SHOP_GOLD      ; 9 = TILE_SHOP_RED
    dd COLOR_ALCOVE_DARK    ; 10 = TILE_ALCOVE

; Waypoints for lanes (world coordinates as pairs of dwords: x, y)
; Mid lane waypoints for blue team
align 8
global map_waypoints_mid_blue
map_waypoints_mid_blue:
    dd 800,  5600       ; start near blue base
    dd 1600, 4800
    dd 2400, 4000
    dd 3200, 3200       ; center of map
    dd 4000, 2400
    dd 4800, 1600
    dd 5600, 800        ; near red base
map_waypoints_mid_blue_end:

global map_waypoints_mid_red
map_waypoints_mid_red:
    dd 5600, 800
    dd 4800, 1600
    dd 4000, 2400
    dd 3200, 3200
    dd 2400, 4000
    dd 1600, 4800
    dd 800,  5600
map_waypoints_mid_red_end:

; Top lane
global map_waypoints_top_blue
map_waypoints_top_blue:
    dd 400,  5600
    dd 400,  3200
    dd 400,  800
    dd 2400, 400
    dd 4800, 400
    dd 5600, 400
map_waypoints_top_blue_end:

global map_waypoints_top_red
map_waypoints_top_red:
    dd 5600, 400
    dd 4800, 400
    dd 2400, 400
    dd 400,  800
    dd 400,  3200
    dd 400,  5600
map_waypoints_top_red_end:

; Bot lane
global map_waypoints_bot_blue
map_waypoints_bot_blue:
    dd 800,  5600
    dd 2400, 5600
    dd 4800, 5600
    dd 5600, 5600
    dd 5600, 3200
    dd 5600, 800
map_waypoints_bot_blue_end:

global map_waypoints_bot_red
map_waypoints_bot_red:
    dd 5600, 800
    dd 5600, 3200
    dd 5600, 5600
    dd 4800, 5600
    dd 2400, 5600
    dd 800,  5600
map_waypoints_bot_red_end:

; Waypoint counts per lane (top, mid, bot) x (blue, red)
global map_waypoint_counts
map_waypoint_counts:
    dd 6, 6     ; top blue, top red
    dd 7, 7     ; mid blue, mid red
    dd 6, 6     ; bot blue, bot red

section .bss

; Map tile data - generated at init time
alignb 64
global map_tiles
map_tiles:  resb MAP_WIDTH * MAP_HEIGHT

section .text

; ============================================================================
; map_init - Generate the map tile data
; Creates a Summoner's Rift inspired layout
; ============================================================================
global map_init
map_init:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Fill entire map with grass
    lea rdi, [rel map_tiles]
    mov al, TILE_GRASS
    mov ecx, MAP_WIDTH * MAP_HEIGHT
    rep stosb

    ; --- Draw lanes ---
    ; Lanes are 3 tiles wide

    ; Mid lane: diagonal from bottom-left to top-right
    xor r12d, r12d          ; tile x
.mid_lane:
    cmp r12d, MAP_WIDTH
    jge .mid_lane_done

    ; y = MAP_HEIGHT - 1 - x (diagonal)
    mov r13d, MAP_HEIGHT - 1
    sub r13d, r12d

    ; Draw 3 tiles wide
    mov r14d, -1
.mid_lane_width:
    cmp r14d, 2
    jg .mid_lane_next

    mov eax, r13d
    add eax, r14d
    ; Bounds check
    cmp eax, 0
    jl .mid_lane_w_next
    cmp eax, MAP_HEIGHT
    jge .mid_lane_w_next

    ; Set tile
    imul ecx, eax, MAP_WIDTH
    add ecx, r12d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_LANE

.mid_lane_w_next:
    inc r14d
    jmp .mid_lane_width

.mid_lane_next:
    inc r12d
    jmp .mid_lane

.mid_lane_done:

    ; Top lane: along top edge and left edge (L-shape)
    ; Left edge: x=0..2, y=0..MAP_HEIGHT
    xor r12d, r12d
.top_lane_left:
    cmp r12d, MAP_HEIGHT
    jge .top_lane_left_done
    mov r13d, 0
.top_lane_left_w:
    cmp r13d, 3
    jge .top_lane_left_next
    imul ecx, r12d, MAP_WIDTH
    add ecx, r13d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_LANE
    inc r13d
    jmp .top_lane_left_w
.top_lane_left_next:
    inc r12d
    jmp .top_lane_left
.top_lane_left_done:

    ; Top edge: x=0..MAP_WIDTH, y=0..2
    xor r12d, r12d
.top_lane_top:
    cmp r12d, MAP_WIDTH
    jge .top_lane_top_done
    mov r13d, 0
.top_lane_top_w:
    cmp r13d, 3
    jge .top_lane_top_next
    imul ecx, r13d, MAP_WIDTH
    add ecx, r12d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_LANE
    inc r13d
    jmp .top_lane_top_w
.top_lane_top_next:
    inc r12d
    jmp .top_lane_top
.top_lane_top_done:

    ; Bot lane: along bottom edge and right edge (L-shape)
    ; Bottom edge: y=MAP_HEIGHT-3..MAP_HEIGHT-1
    xor r12d, r12d
.bot_lane_bottom:
    cmp r12d, MAP_WIDTH
    jge .bot_lane_bottom_done
    mov r13d, MAP_HEIGHT - 3
.bot_lane_bottom_w:
    cmp r13d, MAP_HEIGHT
    jge .bot_lane_bottom_next
    imul ecx, r13d, MAP_WIDTH
    add ecx, r12d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_LANE
    inc r13d
    jmp .bot_lane_bottom_w
.bot_lane_bottom_next:
    inc r12d
    jmp .bot_lane_bottom
.bot_lane_bottom_done:

    ; Right edge: x=MAP_WIDTH-3..MAP_WIDTH-1
    xor r12d, r12d
.bot_lane_right:
    cmp r12d, MAP_HEIGHT
    jge .bot_lane_right_done
    mov r13d, MAP_WIDTH - 3
.bot_lane_right_w:
    cmp r13d, MAP_WIDTH
    jge .bot_lane_right_next
    imul ecx, r12d, MAP_WIDTH
    add ecx, r13d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_LANE
    inc r13d
    jmp .bot_lane_right_w
.bot_lane_right_next:
    inc r12d
    jmp .bot_lane_right
.bot_lane_right_done:

    ; --- Draw river (diagonal, perpendicular to mid lane) ---
    xor r12d, r12d
.river:
    cmp r12d, MAP_WIDTH
    jge .river_done

    ; River goes from top-left to bottom-right (perpendicular to mid)
    ; y = x (diagonal)
    mov r13d, r12d

    ; 2 tiles wide
    mov r14d, -1
.river_width:
    cmp r14d, 1
    jg .river_next
    mov eax, r13d
    add eax, r14d
    cmp eax, 0
    jl .river_w_next
    cmp eax, MAP_HEIGHT
    jge .river_w_next
    imul ecx, eax, MAP_WIDTH
    add ecx, r12d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_RIVER
    inc r14d
    jmp .river_width
.river_w_next:
    inc r14d
    jmp .river_width
.river_next:
    inc r12d
    jmp .river
.river_done:

    ; --- Draw bases ---
    ; Blue base: bottom-left corner (tiles 0-6, MAP_HEIGHT-7 to MAP_HEIGHT-1)
    mov r12d, MAP_HEIGHT - 7
.blue_base_y:
    cmp r12d, MAP_HEIGHT
    jge .blue_base_done
    xor r13d, r13d
.blue_base_x:
    cmp r13d, 7
    jge .blue_base_y_next
    imul ecx, r12d, MAP_WIDTH
    add ecx, r13d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_BASE_BLUE
    inc r13d
    jmp .blue_base_x
.blue_base_y_next:
    inc r12d
    jmp .blue_base_y
.blue_base_done:

    ; Red base: top-right corner
    xor r12d, r12d
.red_base_y:
    cmp r12d, 7
    jge .red_base_done
    mov r13d, MAP_WIDTH - 7
.red_base_x:
    cmp r13d, MAP_WIDTH
    jge .red_base_y_next
    imul ecx, r12d, MAP_WIDTH
    add ecx, r13d
    lea rdi, [rel map_tiles]
    mov byte [rdi + rcx], TILE_BASE_RED
    inc r13d
    jmp .red_base_x
.red_base_y_next:
    inc r12d
    jmp .red_base_y
.red_base_done:

    ; --- Add jungle patches ---
    ; Scatter some jungle tiles between lanes
    ; Simple: fill areas that aren't already lanes/river/base
    mov r12d, 10
.jungle_y:
    cmp r12d, MAP_HEIGHT - 10
    jge .jungle_done
    mov r13d, 10
.jungle_x:
    cmp r13d, MAP_WIDTH - 10
    jge .jungle_y_next

    ; Check if tile is grass (not already something else)
    imul ecx, r12d, MAP_WIDTH
    add ecx, r13d
    lea rdi, [rel map_tiles]
    cmp byte [rdi + rcx], TILE_GRASS
    jne .jungle_x_next

    ; Check if far enough from lanes (simple heuristic)
    ; If not near diagonal or edges, make it jungle
    mov eax, r12d
    add eax, r13d
    ; Near mid lane diagonal? (y + x ≈ MAP_HEIGHT)
    sub eax, MAP_HEIGHT
    cmp eax, -5
    jg .jungle_x_next       ; too close to mid lane/river

    mov byte [rdi + rcx], TILE_JUNGLE

.jungle_x_next:
    add r13d, 3             ; skip some tiles for variety
    jmp .jungle_x
.jungle_y_next:
    add r12d, 3
    jmp .jungle_y
.jungle_done:

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; map_render - Render visible tiles to framebuffer
; Uses camera position for viewport culling
; ============================================================================
global map_render
map_render:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; Calculate visible tile range
    mov eax, [camera_x]
    xor edx, edx
    mov ecx, TILE_SIZE
    div ecx
    mov r12d, eax           ; start_tile_x

    mov eax, [camera_y]
    xor edx, edx
    div ecx
    mov r13d, eax           ; start_tile_y

    ; End tiles (visible area + 1 for partial tiles)
    mov eax, [camera_x]
    add eax, WINDOW_WIDTH
    add eax, TILE_SIZE - 1
    xor edx, edx
    mov ecx, TILE_SIZE
    div ecx
    mov r14d, eax           ; end_tile_x
    cmp r14d, MAP_WIDTH
    jl .no_clamp_end_x
    mov r14d, MAP_WIDTH
.no_clamp_end_x:

    mov eax, [camera_y]
    add eax, WINDOW_HEIGHT
    add eax, TILE_SIZE - 1
    xor edx, edx
    div ecx
    mov r15d, eax           ; end_tile_y
    cmp r15d, MAP_HEIGHT
    jl .no_clamp_end_y
    mov r15d, MAP_HEIGHT
.no_clamp_end_y:

    ; Render tiles
    mov ebp, r13d           ; current tile_y
.tile_row:
    cmp ebp, r15d
    jge .tile_done

    mov ebx, r12d           ; current tile_x
.tile_col:
    cmp ebx, r14d
    jge .tile_row_next

    ; Bounds check
    cmp ebx, 0
    jl .tile_next
    cmp ebp, 0
    jl .tile_next
    cmp ebx, MAP_WIDTH
    jge .tile_next
    cmp ebp, MAP_HEIGHT
    jge .tile_next

    ; Get tile type
    imul eax, ebp, MAP_WIDTH
    add eax, ebx
    lea rcx, [rel map_tiles]
    movzx eax, byte [rcx + rax]

    ; Get tile color
    lea rcx, [rel tile_colors]
    mov r8d, [rcx + rax * 4]   ; color

    ; Calculate screen position
    imul edi, ebx, TILE_SIZE
    sub edi, [camera_x]        ; screen_x
    imul esi, ebp, TILE_SIZE
    sub esi, [camera_y]        ; screen_y
    mov edx, TILE_SIZE         ; width
    mov ecx, TILE_SIZE         ; height
    call render_rect

.tile_next:
    inc ebx
    jmp .tile_col

.tile_row_next:
    inc ebp
    jmp .tile_row

.tile_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
