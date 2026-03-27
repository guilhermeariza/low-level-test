; ============================================================================
; pathfinding.asm - A* pathfinding on tile grid
; Task 1.01, 1.02: A* pathfinding + collision map
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern map_tiles

section .data

align 8
; Direction offsets for 8-directional movement (dx, dy pairs)
dir_offsets:
    dd  0, -1       ; N
    dd  1, -1       ; NE
    dd  1,  0       ; E
    dd  1,  1       ; SE
    dd  0,  1       ; S
    dd -1,  1       ; SW
    dd -1,  0       ; W
    dd -1, -1       ; NW

; Cost for each direction (10 for cardinal, 14 for diagonal ≈ 10*sqrt(2))
dir_costs:
    dd 10, 14, 10, 14, 10, 14, 10, 14

section .bss

; Collision map: 1 byte per tile (0=blocked, 1=walkable)
alignb 64
global collision_map
collision_map:  resb MAP_WIDTH * MAP_HEIGHT

; A* node data (for PATH_MAX_NODES open set)
; Using a simple array-based open set (fast enough for game tick budget)
alignb 64
astar_open_x:   resw PATH_MAX_NODES    ; x coords in open set
astar_open_y:   resw PATH_MAX_NODES    ; y coords
astar_open_f:   resd PATH_MAX_NODES    ; f = g + h
astar_open_g:   resd PATH_MAX_NODES    ; g cost
astar_open_cnt: resd 1                 ; count of items in open set

; Visited grid (1 bit per cell would be ideal, using 1 byte for simplicity)
; Only allocate for active search area (not full map)
alignb 64
astar_closed:   resb MAP_WIDTH * MAP_HEIGHT  ; closed set flags
astar_g_map:    resd MAP_WIDTH * MAP_HEIGHT  ; best g cost per cell
astar_parent_x: resw MAP_WIDTH * MAP_HEIGHT  ; parent x for path reconstruction
astar_parent_y: resw MAP_WIDTH * MAP_HEIGHT  ; parent y

; Result path (waypoints in tile coordinates)
alignb 64
global path_result_x, path_result_y, path_result_len
path_result_x: resw 256     ; path waypoint X coords (tile)
path_result_y: resw 256     ; path waypoint Y coords (tile)
path_result_len: resd 1     ; number of waypoints in result

section .text

; ============================================================================
; collision_map_init - Build collision map from tile data
; Walkable: grass, lane, river, jungle, bush, base, shop, alcove
; Blocked: wall
; ============================================================================
global collision_map_init
collision_map_init:
    push rbx
    push r12

    lea rsi, [rel map_tiles]
    lea rdi, [rel collision_map]
    mov ecx, MAP_WIDTH * MAP_HEIGHT
    xor ebx, ebx

.build_loop:
    cmp ebx, ecx
    jge .build_done

    movzx eax, byte [rsi + rbx]

    ; Wall = blocked, everything else = walkable
    cmp al, TILE_WALL
    je .set_blocked
    mov byte [rdi + rbx], 1     ; walkable
    jmp .build_next
.set_blocked:
    mov byte [rdi + rbx], 0     ; blocked
.build_next:
    inc ebx
    jmp .build_loop

.build_done:
    pop r12
    pop rbx
    ret

; ============================================================================
; path_is_walkable - Check if tile coordinate is walkable
; edi = tile_x, esi = tile_y
; Returns: eax = 1 walkable, 0 blocked
; ============================================================================
global path_is_walkable
path_is_walkable:
    ; Bounds check
    cmp edi, 0
    jl .blocked
    cmp edi, MAP_WIDTH
    jge .blocked
    cmp esi, 0
    jl .blocked
    cmp esi, MAP_HEIGHT
    jge .blocked

    imul eax, esi, MAP_WIDTH
    add eax, edi
    lea rcx, [rel collision_map]
    movzx eax, byte [rcx + rax]
    ret
.blocked:
    xor eax, eax
    ret

; ============================================================================
; path_find - A* pathfinding from (sx,sy) to (ex,ey) in tile coordinates
; edi = start_tile_x, esi = start_tile_y
; edx = end_tile_x, ecx = end_tile_y
; Returns: eax = path_result_len (0 = no path found)
; Path stored in path_result_x/y arrays
; ============================================================================
global path_find
path_find:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 32

    ; Save start/end
    mov [rsp], edi          ; start_x
    mov [rsp+4], esi        ; start_y
    mov [rsp+8], edx        ; end_x
    mov [rsp+12], ecx       ; end_y

    ; Quick check: destination walkable?
    mov edi, edx
    mov esi, ecx
    call path_is_walkable
    test eax, eax
    jz .no_path

    ; Clear closed set and g_map
    lea rdi, [rel astar_closed]
    xor eax, eax
    mov ecx, MAP_WIDTH * MAP_HEIGHT / 4
    rep stosd

    lea rdi, [rel astar_g_map]
    mov eax, 0x7FFFFFFF
    mov ecx, MAP_WIDTH * MAP_HEIGHT
    rep stosd

    ; Initialize open set with start node
    mov dword [astar_open_cnt], 1
    mov ax, word [rsp]          ; start_x
    lea rdi, [rel astar_open_x]
    mov [rdi], ax
    mov ax, word [rsp+4]        ; start_y
    lea rdi, [rel astar_open_y]
    mov [rdi], ax

    ; g(start) = 0
    movsx eax, word [rsp+4]
    imul eax, MAP_WIDTH
    movsx ecx, word [rsp]
    add eax, ecx
    lea rdi, [rel astar_g_map]
    mov dword [rdi + rax * 4], 0

    ; f(start) = h(start)
    call .calc_heuristic_start
    lea rdi, [rel astar_open_f]
    mov [rdi], eax
    lea rdi, [rel astar_open_g]
    mov dword [rdi], 0

    ; Main A* loop
    mov r15d, 5000          ; max iterations (budget guard)

.astar_loop:
    dec r15d
    jz .no_path             ; budget exhausted

    ; Check if open set is empty
    cmp dword [astar_open_cnt], 0
    je .no_path

    ; Find node with lowest f in open set
    call .find_best_open
    ; eax = best index
    mov ebp, eax            ; save best index

    ; Get best node coords
    lea rdi, [rel astar_open_x]
    movzx r12d, word [rdi + rbp * 2]   ; current x
    lea rdi, [rel astar_open_y]
    movzx r13d, word [rdi + rbp * 2]   ; current y

    ; Remove from open set (swap with last)
    call .remove_open

    ; Check if we reached the goal
    cmp r12d, [rsp+8]
    jne .not_goal
    cmp r13d, [rsp+12]
    jne .not_goal
    jmp .goal_reached

.not_goal:
    ; Mark as closed
    imul eax, r13d, MAP_WIDTH
    add eax, r12d
    lea rdi, [rel astar_closed]
    mov byte [rdi + rax], 1

    ; Get current g cost
    imul eax, r13d, MAP_WIDTH
    add eax, r12d
    lea rdi, [rel astar_g_map]
    mov r14d, [rdi + rax * 4]  ; current g

    ; Explore 8 neighbors
    xor ebx, ebx           ; direction index

.neighbor_loop:
    cmp ebx, 8
    jge .astar_loop

    ; Calculate neighbor position
    lea rdi, [rel dir_offsets]
    mov eax, [rdi + rbx * 8]       ; dx
    add eax, r12d                   ; nx = current_x + dx
    mov [rsp+16], eax               ; save nx
    mov ecx, [rdi + rbx * 8 + 4]   ; dy
    add ecx, r13d                   ; ny = current_y + dy
    mov [rsp+20], ecx               ; save ny

    ; Check walkable
    mov edi, [rsp+16]
    mov esi, [rsp+20]
    call path_is_walkable
    test eax, eax
    jz .next_neighbor

    ; Check not closed
    mov eax, [rsp+20]
    imul eax, MAP_WIDTH
    add eax, [rsp+16]
    lea rdi, [rel astar_closed]
    cmp byte [rdi + rax], 0
    jne .next_neighbor

    ; Calculate tentative g
    lea rdi, [rel dir_costs]
    mov ecx, [rdi + rbx * 4]
    add ecx, r14d                   ; tentative_g = current_g + step_cost

    ; Check if better than existing g
    mov eax, [rsp+20]
    imul eax, MAP_WIDTH
    add eax, [rsp+16]
    lea rdi, [rel astar_g_map]
    cmp ecx, [rdi + rax * 4]
    jge .next_neighbor              ; not better

    ; Update g cost
    mov [rdi + rax * 4], ecx
    mov [rsp+24], ecx               ; save new g

    ; Update parent
    lea rdi, [rel astar_parent_x]
    mov word [rdi + rax * 2], r12w
    lea rdi, [rel astar_parent_y]
    mov word [rdi + rax * 2], r13w

    ; Calculate h (Manhattan distance to goal)
    mov edi, [rsp+16]
    mov esi, [rsp+20]
    mov edx, [rsp+8]
    mov ecx, [rsp+12]
    call .calc_heuristic
    ; eax = h

    ; f = g + h
    add eax, [rsp+24]

    ; Add to open set (or update)
    mov edi, [rsp+16]       ; nx
    mov esi, [rsp+20]       ; ny
    mov edx, eax            ; f
    mov ecx, [rsp+24]       ; g
    call .add_to_open

.next_neighbor:
    inc ebx
    jmp .neighbor_loop

; ============================================================================
; Goal reached - reconstruct path
; ============================================================================
.goal_reached:
    ; Trace back from goal to start using parent pointers
    mov dword [path_result_len], 0
    mov r12d, [rsp+8]      ; current = goal_x
    mov r13d, [rsp+12]     ; current = goal_y

.trace_loop:
    ; Store waypoint
    mov ecx, [path_result_len]
    cmp ecx, 255
    jge .trace_done

    lea rdi, [rel path_result_x]
    mov [rdi + rcx * 2], r12w
    lea rdi, [rel path_result_y]
    mov [rdi + rcx * 2], r13w
    inc dword [path_result_len]

    ; Check if we're back at start
    cmp r12d, [rsp]
    jne .not_start
    cmp r13d, [rsp+4]
    jne .not_start
    jmp .trace_done

.not_start:
    ; Get parent
    imul eax, r13d, MAP_WIDTH
    add eax, r12d
    lea rdi, [rel astar_parent_x]
    movzx r12d, word [rdi + rax * 2]
    lea rdi, [rel astar_parent_y]
    movzx r13d, word [rdi + rax * 2]
    jmp .trace_loop

.trace_done:
    ; Reverse the path (it's currently goal→start, we want start→goal)
    mov ecx, [path_result_len]
    cmp ecx, 2
    jl .path_done

    xor eax, eax           ; i = 0
    mov edx, ecx
    dec edx                 ; j = len-1

.reverse_loop:
    cmp eax, edx
    jge .path_done

    ; Swap x[i] and x[j]
    lea rdi, [rel path_result_x]
    movzx r8d, word [rdi + rax * 2]
    movzx r9d, word [rdi + rdx * 2]
    mov [rdi + rax * 2], r9w
    mov [rdi + rdx * 2], r8w

    ; Swap y[i] and y[j]
    lea rdi, [rel path_result_y]
    movzx r8d, word [rdi + rax * 2]
    movzx r9d, word [rdi + rdx * 2]
    mov [rdi + rax * 2], r9w
    mov [rdi + rdx * 2], r8w

    inc eax
    dec edx
    jmp .reverse_loop

.path_done:
    mov eax, [path_result_len]
    jmp .cleanup

.no_path:
    mov dword [path_result_len], 0
    xor eax, eax

.cleanup:
    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Internal helpers ---

; Calculate heuristic from start to goal
.calc_heuristic_start:
    movsx edi, word [rsp+40]     ; start_x (adjust for return addr + pushes)
    movsx esi, word [rsp+44]     ; start_y
    mov edx, [rsp+48]           ; end_x
    mov ecx, [rsp+52]           ; end_y
    ; Fall through to calc_heuristic

; Calculate heuristic (Manhattan * 10 for integer costs)
; edi=x1, esi=y1, edx=x2, ecx=y2, returns eax
.calc_heuristic:
    sub edi, edx
    ; abs(dx)
    mov eax, edi
    cdq
    xor eax, edx
    sub eax, edx
    mov edi, eax            ; |dx|

    mov eax, esi
    sub eax, ecx
    cdq
    xor eax, edx
    sub eax, edx            ; |dy|

    add eax, edi            ; Manhattan distance
    imul eax, 10            ; scale to match g costs
    ret

; Find best (lowest f) node in open set, return index in eax
.find_best_open:
    mov ecx, [astar_open_cnt]
    lea rdi, [rel astar_open_f]
    xor eax, eax            ; best index
    mov edx, [rdi]          ; best f value
    mov esi, 1              ; i = 1

.find_loop:
    cmp esi, ecx
    jge .find_done
    cmp [rdi + rsi * 4], edx
    jge .find_next
    mov edx, [rdi + rsi * 4]
    mov eax, esi
.find_next:
    inc esi
    jmp .find_loop
.find_done:
    ret

; Remove node at index ebp from open set (swap with last)
.remove_open:
    mov ecx, [astar_open_cnt]
    dec ecx
    mov [astar_open_cnt], ecx

    cmp ebp, ecx
    je .remove_done         ; was last element

    ; Swap with last
    lea rdi, [rel astar_open_x]
    mov ax, [rdi + rcx * 2]
    mov [rdi + rbp * 2], ax

    lea rdi, [rel astar_open_y]
    mov ax, [rdi + rcx * 2]
    mov [rdi + rbp * 2], ax

    lea rdi, [rel astar_open_f]
    mov eax, [rdi + rcx * 4]
    mov [rdi + rbp * 4], eax

    lea rdi, [rel astar_open_g]
    mov eax, [rdi + rcx * 4]
    mov [rdi + rbp * 4], eax

.remove_done:
    ret

; Add node to open set (or update if already present)
; edi=x, esi=y, edx=f, ecx=g
.add_to_open:
    push rbx

    ; Check if already in open set
    mov r8d, [astar_open_cnt]
    xor ebx, ebx
.find_existing:
    cmp ebx, r8d
    jge .add_new

    lea rax, [rel astar_open_x]
    cmp [rax + rbx * 2], di
    jne .find_next_open
    lea rax, [rel astar_open_y]
    cmp [rax + rbx * 2], si
    jne .find_next_open

    ; Found - update if better f
    lea rax, [rel astar_open_f]
    cmp edx, [rax + rbx * 4]
    jge .add_done           ; not better
    mov [rax + rbx * 4], edx
    lea rax, [rel astar_open_g]
    mov [rax + rbx * 4], ecx
    jmp .add_done

.find_next_open:
    inc ebx
    jmp .find_existing

.add_new:
    ; Add new entry
    cmp r8d, PATH_MAX_NODES
    jge .add_done           ; full

    lea rax, [rel astar_open_x]
    mov [rax + r8 * 2], di
    lea rax, [rel astar_open_y]
    mov [rax + r8 * 2], si
    lea rax, [rel astar_open_f]
    mov [rax + r8 * 4], edx
    lea rax, [rel astar_open_g]
    mov [rax + r8 * 4], ecx
    inc dword [astar_open_cnt]

.add_done:
    pop rbx
    ret

; ============================================================================
; path_world_to_tile - Convert world coordinates to tile coordinates
; edi = world_x, esi = world_y
; Returns: eax = tile_x, edx = tile_y
; ============================================================================
global path_world_to_tile
path_world_to_tile:
    mov eax, edi
    shr eax, 5              ; / 32 (TILE_SIZE)
    mov edx, esi
    shr edx, 5
    ret

; ============================================================================
; path_tile_to_world - Convert tile center to world coordinates
; edi = tile_x, esi = tile_y
; Returns: eax = world_x (center), edx = world_y (center)
; ============================================================================
global path_tile_to_world
path_tile_to_world:
    mov eax, edi
    shl eax, 5              ; * 32
    add eax, TILE_SIZE / 2  ; center
    mov edx, esi
    shl edx, 5
    add edx, TILE_SIZE / 2
    ret
