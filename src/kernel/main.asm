org 0x0
bits 16

%define ENDL `\r\n` ; Newline characters


start:
    jmp main


main:
    ; Print "Hello, world!"
    mov si, msg_hello
    call puts

.halt
    cli
    hlt


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
    lodsb               ; Load the next char from ds:si into al, and increment si
    or al, al           ; Set the zero flag if character in al is null
    jz .done            ; If the zero flag is set, we're done

    mov ah, 0x0E        ; BIOS teletype function
    mov bh, 0x00        ; Page number
    int 0x10            ; Call BIOS interrupt 0x10 (video services)

    jmp .loop           ; Repeat until the string is exhausted

.done:
    ; Restore registers
    pop ax
    pop si
    ret


msg_hello: db "Hello, world, from KERNEL!", ENDL, 0