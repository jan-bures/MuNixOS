bits 16

section _ENTRY class=CODE

extern _cstart_
global entry

entry:
    ; Set up stack
    cli
    mov ax, ds
    mov ss, ax
    mov sp, 0
    mov bp, sp
    sti

    ; Expect boot drive in DL, send it as a parameter to cstart
    xor dh, dh
    push dx
    call _cstart_

    cli
    hlt