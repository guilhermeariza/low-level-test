; ============================================================================
; syscalls.inc - Linux x86-64 syscall numbers and helpers
; ============================================================================

%ifndef SYSCALLS_INC
%define SYSCALLS_INC

; Syscall numbers
%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_POLL        7
%define SYS_MMAP        9
%define SYS_MUNMAP      11
%define SYS_IOCTL       16
%define SYS_SOCKET      41
%define SYS_CONNECT     42
%define SYS_SENDTO      44
%define SYS_RECVFROM    45
%define SYS_BIND        49
%define SYS_LISTEN      50
%define SYS_ACCEPT      43
%define SYS_SHMGET      29
%define SYS_SHMAT       30
%define SYS_SHMCTL      31
%define SYS_SHMDT       67
%define SYS_CLOCK_NANOSLEEP 230
%define SYS_EXIT        60
%define SYS_CLOCK_GETTIME   228
%define SYS_GETRANDOM   318

; Socket constants
%define AF_UNIX         1
%define SOCK_STREAM     1

; mmap constants
%define PROT_READ       0x1
%define PROT_WRITE      0x2
%define MAP_SHARED      0x01
%define MAP_PRIVATE     0x02
%define MAP_ANONYMOUS   0x20

; SHM constants
%define IPC_PRIVATE     0
%define IPC_CREAT       0o1000
%define IPC_RMID        0
%define SHM_R           0o400
%define SHM_W           0o200

; Clock
%define CLOCK_MONOTONIC 1

; Poll
%define POLLIN          0x0001

; Macro: do syscall (rax=nr, rdi,rsi,rdx,r10,r8,r9 = args)
%macro SYSCALL0 1
    mov rax, %1
    syscall
%endmacro

%macro SYSCALL1 2
    mov rax, %1
    mov rdi, %2
    syscall
%endmacro

%macro SYSCALL2 3
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    syscall
%endmacro

%macro SYSCALL3 4
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    syscall
%endmacro

%macro SYSCALL4 5
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    mov r10, %5
    syscall
%endmacro

%macro SYSCALL6 7
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    mov r10, %5
    mov r8, %6
    mov r9, %7
    syscall
%endmacro

%endif
