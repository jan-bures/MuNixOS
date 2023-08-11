; Start addresses from 0x7C00, which is where BIOS looks for the OS
org 0x7C00
; Emit 16-bit instructions
bits 16


%define ENDL 0x0D, 0x0A ; Newline character


start:
    jmp main


;
; Print a string to the screen
; Parameters:
;   ds:si - Pointer to the string to print
;
puts:
    ; Save registers that we're going to modify
    push si
    push ax

.loop:
    lodsb ; Load the next char from ds:si into al, and increment si
    or al, al ; Set the zero flag if character in al is null
    jz .done ; If the zero flag is set, we're done

    mov ah, 0x0E ; BIOS teletype function
    mov bh, 0x00 ; Page number
    int 0x10 ; Call BIOS interrupt 0x10 (video services)

    jmp .loop ; Repeat until the string is exhausted

.done:
    ; Restore registers
    pop ax
    pop si
    ret


main:
    ; Set up data segments
    mov ax, 0 ; Can't write to ds/es directly because it's a 16-bit register
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00 ; Stack grows downwards, so we set it to the start of our OS

    ; Print a message
    mov si, msg_hello
    call puts

    ; Halt the processor
    hlt

.halt:
    ; If the processor starts executing code again, trap it in an infinite loop
    jmp .halt


msg_hello: db 'Hello, world!', ENDL, 0


; $ = memory offset of current line in bytes, $$ = memory offset of current segment
; Our sector is 512 bytes, so we need to pad it with 510-($-$$) bytes of 0s
times 510-($-$$) db 0
; The last two bytes are the magic number that BIOS looks for to identify a boot sector
dw 0AA55h