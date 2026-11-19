; ---------- EXT module 1: NOISE (FZED41B), disk sector 52, render effect. Adds noise to the sample during Render.
;   CC115 (input)  = noise level: 0 none, then rising with the square of the knob up to full scale.
;   CC116 (output) = tone: 127 white noise, lower values darker (a one-pole low-pass on the noise).
; The noise is the same on every Render (seeded at init); it runs on across the edit voice and its chop slices.
; Peaks that would pass full scale are held at full scale. The other FX controls are not used.
    dw 0x4034
    db 1, 1                 ; ABI 1, render effect
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT NOISE',0
    times 0x20-($-$$) db 0
    jmp near NZINIT         ; +20h
    jmp near NZRUN          ; +23h
NZLEV: dw 0                 ; level, Q15
NZK: dw 0                   ; tone: low-pass coefficient, Q15
NZX: dw 0                   ; xorshift state
NZY: dw 0                   ; filtered noise (half scale)
NZINIT:
    mov al,[FXIN]
    mul al                  ; level = 2 v^2: 0 .. 32258
    shl ax,1
    mov [NZLEV],ax
    mov al,[FXOUT]
    mov ah,al               ; k = 256 v + 255: 255 .. 32767
    mov al,0xff
    mov [NZK],ax
    mov word [NZX],0xACE1
    mov word [NZY],0
    clc
    ret
NZRUN:              ; cx words at es:si
.l: mov ax,[NZX]            ; xorshift16 (7, 9, 8)
    mov dx,ax
    shl dx,7
    xor ax,dx
    mov dx,ax
    shr dx,9
    xor ax,dx
    mov dx,ax
    shl dx,8
    xor ax,dx
    mov [NZX],ax
    sar ax,1                ; y += ((x/2) - y) * k >> 15
    mov bx,[NZY]
    sub ax,bx
    imul word [NZK]
    shl ax,1
    rcl dx,1
    add bx,dx
    mov [NZY],bx
    mov ax,bx               ; noise = 2y * level >> 15
    shl ax,1
    imul word [NZLEV]
    shl ax,1
    rcl dx,1
    add dx,[es:si]
    jno .s
    sar dx,15               ; overflowed: positive peaks to 7FFFh, negative to 8000h
    add dx,0x8000
.s: mov [es:si],dx
    add si,2
    loop .l
    ret

%if ($-$$) > 0x3A0
%error EXT module 1 reaches the top of its sector
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4034
    times 0x400-($-$$) db 0x5a
