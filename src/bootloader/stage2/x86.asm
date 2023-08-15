bits 16

section _TEXT class=CODE

;
; int 10h ah=0eh
; args: character, page
;
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    ; Make new stack frame
    push bp             ; Save old call frame
    mov bp, sp          ; Set new call frame

    ; Save bx
    push bx

    ; [bp + 0] = old call frame
    ; [bp + 2] = return address (small memory model => 2 bytes)
    ; [bp + 4] = first argument (character)
    ; [bp + 6] = second argument (page)
    ; Note: bytes are converted to words (a single byte cannot be pushed onto the stack)
    mov ah, 0xE
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 0x10

    ; Restore bx
    pop bx

    ; Restore old stack frame
    mov sp, bp
    pop bp

    ret