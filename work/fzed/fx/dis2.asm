; ---------- FZED41C disintegration, high area part: the stage itself (settings and ageing: fx/dis1.asm; variables
; and the dropout pick: fx/dis3.asm)
; a = age / 256 (0-255): dulling, a one-pole low-pass k = 32767 - 120a (Q15; a = 255 is about 380 Hz at 36 kHz) run at
; half scale (the output's lowest bit is 0 while the stage is on),
; started from the word before the chunk as the voice now holds it, so chunks join up; dropouts, 2048-word stretches of the clean sample, picked by a hash of
; their place against DROPOUTS * 2a (all of them at 127 and full age), faded over 128 words at each end; then hiss,
; noise (a 16-bit LCG) at HISS^2 / 8 (at most about -24 dB), and the sum held at full scale.
DISCH:              ; LVCHK, after the effect: LVN words in LVBUF, clean offset LVSO + LVPOS (keeps every register)
    pusha
    push es
    call DISPRM             ; bp = k, dx:ax = LVPOS
    jz .x
    mov di,[LVBUF]          ; low-pass from the word before (the chunk's first word at the segment start)
    sub ax,1
    sbb dx,0
    jc .p
    add ax,[LVSD]
    adc dx,[LVSD+2]
    mov di,DY
    mov cx,1
    call LVRDX
    mov di,[DY]
.p: sar di,1
    push ds
    pop es
    mov si,LVBUF
    mov cx,[LVN]
    cld
.l: lodsw
    sar ax,1                ; dulling, at half scale (di = y / 2)
    sub ax,di
    imul bp
    shl ax,1
    rcl dx,1
    add di,dx
    mov ax,di
    shl ax,1
    mov bx,[DQ]             ; dropouts
    cmp byte [DDR],0
    jz .d2
    mov dx,2047
    sub dx,bx
    cmp dx,bx
    jb .e
    mov dx,bx
.e: sub dx,128
    jnc .z
    shl dx,1
    neg dx
    imul dx
    mov al,ah
    mov ah,dl
    jmp short .d2
.z: xor ax,ax
.d2: inc bx
    and bx,2047
    mov [DQ],bx
    jnz .h
    inc word [DU]
    push ax
    call DUNIT
    pop ax
.h: mov bx,[DHA]            ; hiss
    or bx,bx
    jz .w
    push ax
    mov ax,25173
    mul word [DRN]
    add ax,13849
    mov [DRN],ax
    imul bx
    shl ax,1
    rcl dx,1
    pop ax
    add ax,dx
    jno .w
    mov ax,0x7fff
    js .w
    inc ax
.w: mov [si-2],ax
    dec cx
    jz .x
    jmp .l
.x: pop es
    popa
    ret
