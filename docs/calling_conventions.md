# Calling conventions

## Overview

A calling convention is a set of rules that govern how functions use the stack
to pass arguments and return values. The calling convention is a contract between
the caller and the callee. The caller must pass arguments to the callee in the
correct order and in the correct format. The callee must return the result in the
correct format. The calling convention also specifies who is responsible for
cleaning up the stack after the function returns.

## CDECL

The CDECL calling convention is the default calling convention for x86 C and C++
programs. The caller is responsible for cleaning up the stack after the function
returns. The arguments are pushed onto the stack in reverse order. The return
value is stored in the EAX register.

### Arguments
- passed on the stack in reverse order
- pushed from right to left
- caller cleans up the stack

### Return value
- integer return value is stored in EAX
- floating point return value is stored in ST0

### Registers
- EAX, ECX, and EDX are caller saved
- all other registers are callee saved

### Name mangling
- C functions are prefixed with an underscore

### Example

C code:
```c
#include <stdint.h>

uint16_t lengthSquared(uint16_t x, uint16_t y)
{
    uint16_t r = x * x + y * y;
    return r;
}
```

ASM code:
```nasm
    ; save contents of eax, ecx, edx if important
    push y
    push x
    call _lengthSquared
    add sp, 4 ; clean up the stack

_lengthSquared:
    push bp ; save old base pointer
    mov bp, sp ; set new base pointer
    
    sub sp, 2 ; allocate space for r
    mov ax, [bp + 4] ; load x
    mul ax ; multiply x by x
    mov [bp - 2], ax ; store result in r
    
    mov ax, [bp + 6] ; load y
    mul ax ; multiply y by y
    add [bp - 2], ax ; add result to r
    
    mov ax, [bp - 2] ; load r
    
    mov sp, bp ; restore stack pointer
    pop bp ; restore base pointer
    ret ; return to caller
```