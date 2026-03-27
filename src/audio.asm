; ============================================================================
; audio.asm - Audio system via ALSA (Advanced Linux Sound Architecture)
; Tasks 11.01-11.06: Sound engine, SFX, announcer, background music
; Uses direct ALSA device access via /dev/snd/pcmC0D0p
; ============================================================================

%include "syscalls.inc"
%include "x11proto.inc"
%include "constants.inc"
%include "macros.inc"

section .data

; Audio device path
audio_dev_path: db "/dev/snd/pcmC0D0p", 0

; Simple waveform data for sound effects (square wave, 8-bit mono)
; Attack sound: short burst
align 16
sfx_attack:
    times 64 db 127
    times 64 db -128
    times 64 db 127
    times 64 db -128
sfx_attack_len equ $ - sfx_attack

; Level up sound: ascending tone
sfx_levelup:
    times 32 db 127
    times 32 db -128
    times 24 db 127
    times 24 db -128
    times 16 db 127
    times 16 db -128
    times 12 db 127
    times 12 db -128
sfx_levelup_len equ $ - sfx_levelup

; Death sound: descending
sfx_death:
    times 12 db 127
    times 12 db -128
    times 16 db 127
    times 16 db -128
    times 24 db 127
    times 24 db -128
    times 32 db 127
    times 32 db -128
sfx_death_len equ $ - sfx_death

; Gold sound: short high ping
sfx_gold:
    times 16 db 127
    times 16 db -128
    times 16 db 127
    times 16 db -128
sfx_gold_len equ $ - sfx_gold

; Tower destroy sound
sfx_tower:
    times 48 db 127
    times 48 db -128
    times 48 db 127
    times 48 db -128
    times 48 db 127
    times 48 db -128
sfx_tower_len equ $ - sfx_tower

section .bss

; Audio state
global audio_enabled
audio_enabled:  resd 1
audio_fd:       resd 1

; Sound queue (max 8 pending sounds)
alignb 64
global sound_queue
sound_queue_ptr: resq 8    ; pointer to sound data
sound_queue_len: resd 8    ; length of sound data
sound_queue_count: resd 1
sound_queue_head: resd 1

section .text

; ============================================================================
; audio_init - Initialize audio system
; Opens ALSA PCM device. If fails, audio_enabled = 0 (graceful degradation)
; ============================================================================
global audio_init
audio_init:
    mov dword [audio_enabled], 0
    mov dword [sound_queue_count], 0
    mov dword [sound_queue_head], 0
    mov dword [audio_fd], -1

    ; Try to open audio device
    mov rax, SYS_OPEN
    lea rdi, [rel audio_dev_path]
    mov rsi, 1              ; O_WRONLY
    xor rdx, rdx
    syscall

    cmp rax, 0
    jl .audio_unavailable

    mov [audio_fd], eax
    mov dword [audio_enabled], 1
    ret

.audio_unavailable:
    ; Audio not available - game continues silently
    ret

; ============================================================================
; audio_cleanup - Close audio device
; ============================================================================
global audio_cleanup
audio_cleanup:
    cmp dword [audio_enabled], 0
    je .done
    mov rax, SYS_CLOSE
    movsx rdi, dword [audio_fd]
    syscall
    mov dword [audio_enabled], 0
.done:
    ret

; ============================================================================
; audio_play_sfx - Queue a sound effect
; edi = sfx type (0=attack, 1=levelup, 2=death, 3=gold, 4=tower)
; ============================================================================
global audio_play_sfx
audio_play_sfx:
    cmp dword [audio_enabled], 0
    je .no_audio

    cmp dword [sound_queue_count], 8
    jge .no_audio             ; queue full

    ; Get sound data pointer and length
    cmp edi, 0
    je .sfx_attack
    cmp edi, 1
    je .sfx_levelup
    cmp edi, 2
    je .sfx_death
    cmp edi, 3
    je .sfx_gold
    cmp edi, 4
    je .sfx_tower
    ret

.sfx_attack:
    lea rsi, [rel sfx_attack]
    mov edx, sfx_attack_len
    jmp .queue_sound
.sfx_levelup:
    lea rsi, [rel sfx_levelup]
    mov edx, sfx_levelup_len
    jmp .queue_sound
.sfx_death:
    lea rsi, [rel sfx_death]
    mov edx, sfx_death_len
    jmp .queue_sound
.sfx_gold:
    lea rsi, [rel sfx_gold]
    mov edx, sfx_gold_len
    jmp .queue_sound
.sfx_tower:
    lea rsi, [rel sfx_tower]
    mov edx, sfx_tower_len

.queue_sound:
    mov ecx, [sound_queue_count]
    lea rax, [rel sound_queue_ptr]
    mov [rax + rcx * 8], rsi
    lea rax, [rel sound_queue_len]
    mov [rax + rcx * 4], edx
    inc dword [sound_queue_count]

.no_audio:
    ret

; ============================================================================
; audio_update - Process sound queue, write to device
; Called once per frame
; ============================================================================
global audio_update
audio_update:
    cmp dword [audio_enabled], 0
    je .done
    cmp dword [sound_queue_count], 0
    je .done

    push rbx

    ; Play first sound in queue
    mov ebx, [sound_queue_head]
    lea rax, [rel sound_queue_ptr]
    mov rsi, [rax + rbx * 8]
    lea rax, [rel sound_queue_len]
    mov edx, [rax + rbx * 4]

    ; Write to audio device (non-blocking, best effort)
    mov rax, SYS_WRITE
    movsx rdi, dword [audio_fd]
    mov edx, edx                ; zero-extend to rdx
    syscall

    ; Advance queue
    inc dword [sound_queue_head]
    dec dword [sound_queue_count]
    cmp dword [sound_queue_count], 0
    jg .more
    mov dword [sound_queue_head], 0
.more:
    pop rbx
.done:
    ret
