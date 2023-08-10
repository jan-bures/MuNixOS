; Start addresses from 0x7C00, which is where BIOS looks for the OS
org 0x7C00
; Emit 16-bit instructions
bits 16


main:
    ; Halt the processor
    hlt

.halt:
    ; If the processor starts executing code again, trap it in an infinite loop
    jmp .halt


; $ = memory offset of current line in bytes, $$ = memory offset of current segment
; Our sector is 512 bytes, so we need to pad it with 510-($-$$) bytes of 0s
times 510-($-$$) db 0
; The last two bytes are the magic number that BIOS looks for to identify a boot sector
dw 0AA55h