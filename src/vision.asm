; ============================================================================
; vision.asm - Fog of War and ward system
; Tasks 6.01-6.09: Vision, wards, bushes, sweeper
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

extern ent_x, ent_y, ent_type, ent_team, ent_state, ent_active, ent_count
extern map_tiles
extern camera_x, camera_y
extern framebuffer
extern entity_spawn

section .data

section .bss

; Vision map: 1 byte per tile
; 0 = not visible (fog), 1 = previously seen (dark fog), 2 = currently visible
alignb 64
global vision_map
vision_map:     resb MAP_WIDTH * MAP_HEIGHT

; Ward data (separate tracking from entity system)
alignb 64
global ward_x, ward_y, ward_team, ward_type, ward_timer, ward_active, ward_count
ward_x:         resd MAX_WARDS
ward_y:         resd MAX_WARDS
ward_team:      resb MAX_WARDS
ward_type:      resb MAX_WARDS      ; 0=stealth, 1=control
ward_timer:     resd MAX_WARDS      ; frames remaining
ward_active:    resb MAX_WARDS
ward_count:     resd 1

; Per-team ward counts
global blue_stealth_wards, blue_control_wards
global red_stealth_wards, red_control_wards
blue_stealth_wards: resd 1
blue_control_wards: resd 1
red_stealth_wards:  resd 1
red_control_wards:  resd 1

; Sweeper state
global sweeper_active, sweeper_x, sweeper_y, sweeper_timer, sweeper_team
sweeper_active: resd 1
sweeper_x:      resd 1
sweeper_y:      resd 1
sweeper_timer:  resd 1
sweeper_team:   resd 1

section .text

; ============================================================================
; vision_init - Initialize vision system
; ============================================================================
global vision_init
vision_init:
    ; Set all tiles to "previously seen" (dark fog) initially
    ; In real LoL, map starts as fully fogged
    lea rdi, [rel vision_map]
    xor eax, eax            ; 0 = not visible
    mov ecx, MAP_WIDTH * MAP_HEIGHT
    rep stosb

    ; Clear wards
    lea rdi, [rel ward_active]
    xor eax, eax
    mov ecx, MAX_WARDS / 4
    rep stosd

    mov dword [ward_count], 0
    mov dword [blue_stealth_wards], 0
    mov dword [blue_control_wards], 0
    mov dword [red_stealth_wards], 0
    mov dword [red_control_wards], 0

    mov dword [sweeper_active], 0
    ret

; ============================================================================
; vision_update - Update vision map based on ally positions
; Called once per frame
; ============================================================================
global vision_update
vision_update:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Step 1: Decay all "currently visible" to "previously seen"
    lea rdi, [rel vision_map]
    mov ecx, MAP_WIDTH * MAP_HEIGHT
    xor ebx, ebx
.decay_loop:
    cmp ebx, ecx
    jge .decay_done
    cmp byte [rdi + rbx], 2
    jne .decay_next
    mov byte [rdi + rbx], 1     ; was visible, now dark fog
.decay_next:
    inc ebx
    jmp .decay_loop
.decay_done:

    ; Step 2: For each ally entity, reveal tiles in vision radius
    ; (For now, reveal for TEAM_BLUE = player's team)
    mov r15d, [ent_count]
    xor r12d, r12d

.reveal_loop:
    cmp r12d, r15d
    jge .reveal_done

    lea rax, [rel ent_active]
    cmp byte [rax + r12], 0
    je .reveal_next
    lea rax, [rel ent_state]
    cmp byte [rax + r12], STATE_DEAD
    je .reveal_next
    lea rax, [rel ent_team]
    cmp byte [rax + r12], TEAM_BLUE
    jne .reveal_next

    ; Get entity tile position
    lea rax, [rel ent_x]
    vcvttsd2si eax, [rax + r12 * 8]
    shr eax, 5              ; / TILE_SIZE
    mov r13d, eax           ; tile_x

    lea rax, [rel ent_y]
    vcvttsd2si eax, [rax + r12 * 8]
    shr eax, 5
    mov r14d, eax           ; tile_y

    ; Vision radius in tiles = VISION_RADIUS / TILE_SIZE
    mov ebx, VISION_RADIUS / TILE_SIZE

    ; Reveal circle of tiles
    call vision_reveal_tiles

.reveal_next:
    inc r12d
    jmp .reveal_loop

.reveal_done:
    ; Step 3: Reveal around wards
    call vision_update_wards

    ; Step 4: Reveal around towers
    call vision_reveal_towers

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Reveal tiles in radius around (r13d, r14d) with radius ebx ---
vision_reveal_tiles:
    push rcx
    push rdx
    push rsi
    push rdi

    ; Simple: iterate square and check circular distance
    mov ecx, r14d
    sub ecx, ebx            ; start_y
.rt_y:
    mov edx, r14d
    add edx, ebx
    cmp ecx, edx
    jg .rt_done

    cmp ecx, 0
    jl .rt_y_next
    cmp ecx, MAP_HEIGHT
    jge .rt_done

    mov esi, r13d
    sub esi, ebx            ; start_x
.rt_x:
    mov edx, r13d
    add edx, ebx
    cmp esi, edx
    jg .rt_y_next

    cmp esi, 0
    jl .rt_x_next
    cmp esi, MAP_WIDTH
    jge .rt_y_next

    ; Check circular distance
    mov eax, esi
    sub eax, r13d
    imul eax, eax
    mov edi, ecx
    sub edi, r14d
    imul edi, edi
    add eax, edi
    mov edi, ebx
    imul edi, ebx           ; radius^2
    cmp eax, edi
    jg .rt_x_next

    ; Check bush blocking (simplified: bushes only block if entity not in bush)
    imul eax, ecx, MAP_WIDTH
    add eax, esi
    lea rdi, [rel map_tiles]
    cmp byte [rdi + rax], TILE_BUSH
    je .rt_check_bush

.rt_set_visible:
    imul eax, ecx, MAP_WIDTH
    add eax, esi
    lea rdi, [rel vision_map]
    mov byte [rdi + rax], 2  ; currently visible

.rt_x_next:
    inc esi
    jmp .rt_x

.rt_y_next:
    inc ecx
    jmp .rt_y

.rt_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    ret

.rt_check_bush:
    ; Only reveal bush if observer is inside same bush
    imul eax, r14d, MAP_WIDTH
    add eax, r13d
    lea rdi, [rel map_tiles]
    cmp byte [rdi + rax], TILE_BUSH
    je .rt_set_visible       ; observer is in bush too, can see
    jmp .rt_x_next           ; can't see into bush from outside

; --- Reveal around ally towers ---
vision_reveal_towers:
    push r12
    push r13
    push r14
    push rbx

    mov r15d, [ent_count]
    xor r12d, r12d

.tower_vis_loop:
    cmp r12d, r15d
    jge .tower_vis_done

    lea rax, [rel ent_active]
    cmp byte [rax + r12], 0
    je .tower_vis_next
    lea rax, [rel ent_type]
    cmp byte [rax + r12], ENT_TOWER
    jne .tower_vis_next
    lea rax, [rel ent_team]
    cmp byte [rax + r12], TEAM_BLUE
    jne .tower_vis_next

    lea rax, [rel ent_x]
    vcvttsd2si r13d, [rax + r12 * 8]
    shr r13d, 5
    lea rax, [rel ent_y]
    vcvttsd2si r14d, [rax + r12 * 8]
    shr r14d, 5
    mov ebx, TOWER_VISION / TILE_SIZE
    call vision_reveal_tiles

.tower_vis_next:
    inc r12d
    jmp .tower_vis_loop

.tower_vis_done:
    pop rbx
    pop r14
    pop r13
    pop r12
    ret

; ============================================================================
; vision_update_wards - Update ward timers and vision
; ============================================================================
vision_update_wards:
    push rbx
    push r12
    push r13
    push r14

    xor ebx, ebx
.ward_loop:
    cmp ebx, MAX_WARDS
    jge .ward_done

    lea rax, [rel ward_active]
    cmp byte [rax + rbx], 0
    je .ward_next

    ; Tick timer
    lea rax, [rel ward_timer]
    dec dword [rax + rbx * 4]
    cmp dword [rax + rbx * 4], 0
    jle .ward_expire

    ; Reveal vision if ally ward
    lea rax, [rel ward_team]
    cmp byte [rax + rbx], TEAM_BLUE
    jne .ward_next

    ; Get ward tile position
    lea rax, [rel ward_x]
    mov r13d, [rax + rbx * 4]
    shr r13d, 5
    lea rax, [rel ward_y]
    mov r14d, [rax + rbx * 4]
    shr r14d, 5
    push rbx
    mov ebx, WARD_VISION / TILE_SIZE
    call vision_reveal_tiles
    pop rbx
    jmp .ward_next

.ward_expire:
    lea rax, [rel ward_active]
    mov byte [rax + rbx], 0

.ward_next:
    inc ebx
    jmp .ward_loop

.ward_done:
    ; Update sweeper
    cmp dword [sweeper_active], 0
    je .no_sweeper
    dec dword [sweeper_timer]
    cmp dword [sweeper_timer], 0
    jle .sweeper_end
    jmp .no_sweeper
.sweeper_end:
    mov dword [sweeper_active], 0
.no_sweeper:

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; vision_place_ward - Place a ward
; edi = world_x, esi = world_y, edx = team, ecx = ward_type (0=stealth,1=control)
; Returns: eax = 1 success, 0 fail
; ============================================================================
global vision_place_ward
vision_place_ward:
    push rbx

    ; Check ward limits
    cmp ecx, 0
    je .check_stealth_limit
    ; Control ward
    cmp edx, TEAM_BLUE
    jne .check_red_ctrl
    cmp dword [blue_control_wards], MAX_CONTROL_WARDS
    jge .ward_fail
    jmp .find_ward_slot
.check_red_ctrl:
    cmp dword [red_control_wards], MAX_CONTROL_WARDS
    jge .ward_fail
    jmp .find_ward_slot

.check_stealth_limit:
    cmp edx, TEAM_BLUE
    jne .check_red_stealth
    cmp dword [blue_stealth_wards], MAX_STEALTH_WARDS
    jge .ward_fail
    jmp .find_ward_slot
.check_red_stealth:
    cmp dword [red_stealth_wards], MAX_STEALTH_WARDS
    jge .ward_fail

.find_ward_slot:
    xor ebx, ebx
.find_ws:
    cmp ebx, MAX_WARDS
    jge .ward_fail
    lea rax, [rel ward_active]
    cmp byte [rax + rbx], 0
    je .place_ward
    inc ebx
    jmp .find_ws

.place_ward:
    lea rax, [rel ward_active]
    mov byte [rax + rbx], 1
    lea rax, [rel ward_x]
    mov [rax + rbx * 4], edi
    lea rax, [rel ward_y]
    mov [rax + rbx * 4], esi
    lea rax, [rel ward_team]
    mov [rax + rbx], dl
    lea rax, [rel ward_type]
    mov [rax + rbx], cl
    lea rax, [rel ward_timer]
    cmp cl, 0
    je .stealth_duration
    mov dword [rax + rbx * 4], 0x7FFFFFFF   ; control ward: infinite
    jmp .ward_placed
.stealth_duration:
    mov dword [rax + rbx * 4], WARD_DURATION

.ward_placed:
    ; Increment counter
    cmp cl, 0
    je .inc_stealth
    cmp dl, TEAM_BLUE
    jne .inc_red_ctrl
    inc dword [blue_control_wards]
    jmp .ward_success
.inc_red_ctrl:
    inc dword [red_control_wards]
    jmp .ward_success
.inc_stealth:
    cmp dl, TEAM_BLUE
    jne .inc_red_stealth
    inc dword [blue_stealth_wards]
    jmp .ward_success
.inc_red_stealth:
    inc dword [red_stealth_wards]

.ward_success:
    mov eax, 1
    pop rbx
    ret

.ward_fail:
    xor eax, eax
    pop rbx
    ret

; ============================================================================
; vision_is_visible - Check if a tile is visible to player's team
; edi = tile_x, esi = tile_y
; Returns: eax = visibility level (0=fog, 1=dark, 2=visible)
; ============================================================================
global vision_is_visible
vision_is_visible:
    cmp edi, 0
    jl .fog
    cmp edi, MAP_WIDTH
    jge .fog
    cmp esi, 0
    jl .fog
    cmp esi, MAP_HEIGHT
    jge .fog

    imul eax, esi, MAP_WIDTH
    add eax, edi
    lea rcx, [rel vision_map]
    movzx eax, byte [rcx + rax]
    ret
.fog:
    xor eax, eax
    ret

; ============================================================================
; vision_render_fog - Apply fog of war overlay to framebuffer
; Called after all game rendering, before HUD
; ============================================================================
global vision_render_fog
vision_render_fog:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; For each visible tile on screen, darken if not visible
    mov eax, [camera_x]
    shr eax, 5
    mov r12d, eax           ; start_tile_x

    mov eax, [camera_y]
    shr eax, 5
    mov r13d, eax           ; start_tile_y

    mov eax, [camera_x]
    add eax, WINDOW_WIDTH + TILE_SIZE - 1
    shr eax, 5
    mov r14d, eax
    cmp r14d, MAP_WIDTH
    jl .fog_no_clamp_x
    mov r14d, MAP_WIDTH
.fog_no_clamp_x:

    mov eax, [camera_y]
    add eax, WINDOW_HEIGHT + TILE_SIZE - 1
    shr eax, 5
    mov r15d, eax
    cmp r15d, MAP_HEIGHT
    jl .fog_no_clamp_y
    mov r15d, MAP_HEIGHT
.fog_no_clamp_y:

    mov ebp, r13d           ; ty

.fog_row:
    cmp ebp, r15d
    jge .fog_done

    mov ebx, r12d           ; tx
.fog_col:
    cmp ebx, r14d
    jge .fog_row_next

    ; Check visibility
    imul eax, ebp, MAP_WIDTH
    add eax, ebx
    lea rcx, [rel vision_map]
    movzx eax, byte [rcx + rax]

    cmp al, 2
    je .fog_next            ; fully visible, skip

    ; Calculate screen rect for this tile
    imul edi, ebx, TILE_SIZE
    sub edi, [camera_x]
    imul esi, ebp, TILE_SIZE
    sub esi, [camera_y]

    ; Skip if off screen
    cmp edi, WINDOW_WIDTH
    jge .fog_next
    cmp esi, WINDOW_HEIGHT
    jge .fog_next
    mov edx, edi
    add edx, TILE_SIZE
    cmp edx, 0
    jle .fog_next
    mov edx, esi
    add edx, TILE_SIZE
    cmp edx, 0
    jle .fog_next

    ; Darken pixels in this tile area
    ; For fog (0): full black
    ; For dark fog (1): 50% darken
    cmp al, 0
    je .full_fog

    ; Dark fog: darken each pixel by shifting right
    call .darken_tile_half
    jmp .fog_next

.full_fog:
    call .darken_tile_full
    jmp .fog_next

.fog_next:
    inc ebx
    jmp .fog_col

.fog_row_next:
    inc ebp
    jmp .fog_row

.fog_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; --- Darken tile fully (black) ---
; edi = screen_x, esi = screen_y
.darken_tile_full:
    push rax
    push rcx
    push rdx

    ; Clamp to screen
    mov eax, edi
    cmp eax, 0
    cmovl eax, [rel .zero]
    mov edi, eax

    mov eax, esi
    cmp eax, 0
    cmovl eax, [rel .zero]
    mov esi, eax

    mov ecx, TILE_SIZE
    mov edx, esi
    add edx, ecx
    cmp edx, HUD_Y
    jle .dtf_ok
    mov ecx, HUD_Y
    sub ecx, esi
    jle .dtf_done
.dtf_ok:
    mov rax, [framebuffer]
    test rax, rax
    jz .dtf_done

.dtf_row:
    test ecx, ecx
    jz .dtf_done

    ; Calculate pixel offset
    push rcx
    imul edx, esi, WINDOW_WIDTH
    add edx, edi
    shl edx, 2
    lea r8, [rax + rdx]

    mov edx, TILE_SIZE
    mov ecx, edi
    add ecx, edx
    cmp ecx, WINDOW_WIDTH
    jle .dtf_w_ok
    mov edx, WINDOW_WIDTH
    sub edx, edi
.dtf_w_ok:
    ; Write black pixels
.dtf_px:
    test edx, edx
    jz .dtf_row_done
    mov dword [r8], COLOR_BLACK
    add r8, 4
    dec edx
    jmp .dtf_px
.dtf_row_done:
    pop rcx
    inc esi
    dec ecx
    jmp .dtf_row

.dtf_done:
    pop rdx
    pop rcx
    pop rax
    ret

; --- Darken tile half (dim) ---
.darken_tile_half:
    push rax
    push rcx
    push rdx

    mov rax, [framebuffer]
    test rax, rax
    jz .dth_done

    mov ecx, TILE_SIZE
    mov edx, esi
    add edx, ecx
    cmp edx, HUD_Y
    jle .dth_ok
    mov ecx, HUD_Y
    sub ecx, esi
    jle .dth_done
.dth_ok:

.dth_row:
    test ecx, ecx
    jz .dth_done

    cmp esi, 0
    jl .dth_skip_row

    push rcx
    imul edx, esi, WINDOW_WIDTH
    add edx, edi
    shl edx, 2
    lea r8, [rax + rdx]

    mov edx, TILE_SIZE
    mov ecx, edi
    add ecx, edx
    cmp ecx, WINDOW_WIDTH
    jle .dth_w_ok
    mov edx, WINDOW_WIDTH
    sub edx, edi
.dth_w_ok:
    cmp edi, 0
    jge .dth_px
    add r8d, edi            ; skip negative pixels (simplified)
    add edx, edi
    jle .dth_row_done2

.dth_px:
    test edx, edx
    jz .dth_row_done2
    ; Halve each color channel: (pixel >> 1) & 0x7F7F7F7F
    mov r9d, [r8]
    shr r9d, 1
    and r9d, 0x7F7F7F7F
    or  r9d, 0xFF000000     ; keep alpha
    mov [r8], r9d
    add r8, 4
    dec edx
    jmp .dth_px

.dth_row_done2:
    pop rcx
.dth_skip_row:
    inc esi
    dec ecx
    jmp .dth_row

.dth_done:
    pop rdx
    pop rcx
    pop rax
    ret

align 4
.zero: dd 0
