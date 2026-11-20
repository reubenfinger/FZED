; ---------- FZED41C disintegration, high area part: the stage itself (settings and ageing: fx/dis1.asm; variables
; and the dropout pick: fx/dis3.asm)
; a = age / 256 (0-255). FZED41D: three passes over the chunk, each only when it does something (about a third of the
; FZED41C clocks). Dulling (a > 0): a one-pole low-pass k = (256 - a)^2 / 2 with 300h ORed in (Q15;
; fx/dis1.asm): the cutoff falls steadily with age, about 5 kHz at a = 64, 1.8 kHz at 128, 500 Hz at 192 and 135 Hz
; at the end (36 kHz voice; half that at 18 kHz). Run at half scale (the output's lowest bit is 0), started from the word before the chunk as the
; voice now holds it, so chunks join up. Dropouts: 2048-word stretches of the clean sample, picked by a hash of their
; place against DROPOUTS * 2a, faded over 128 words at each end. Hiss: noise (a 16-bit LCG) at HISS^2 / 2 (at most
; about -12 dB), the sum held at full scale.
DISCH:              ; LVCHK, after the effect: LVN words in LVBUF, clean offset LVSO + LVPOS (keeps every register)
    pusha
    push es
    call DISPRM             ; dx:ax = LVPOS, bp = dulling k
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
    cld
    cmp byte [DAGE+3],0
    jz .h                   ; new: hiss only
    mov si,LVBUF
    mov cx,[LVN]
.l: lodsw                   ; dulling, at half scale (di = y / 2)
    sar ax,1
    sub ax,di
    imul bp
    shl ax,1
    rcl dx,1
    add di,dx
    mov ax,di
    shl ax,1
    mov [si-2],ax
    loop .l
    cmp word [DTH],0        ; dropouts
    jz .h
    mov si,LVBUF
    mov cx,[LVN]
    mov bx,[DQ]
.dl: cmp word [DDR],256
    jz .dn
    mov dx,2047
    sub dx,bx
    cmp dx,bx
    jb .e
    mov dx,bx
.e: add dx,-128             ; FZED41D: gain = the larger of the stretch's level and the edge ramp
    jnc .g
    xor dx,dx               ; 128 or more words in: the stretch's level
.g: shl dx,1
    neg dx                  ; 256 - 2e near the edges
    cmp dx,[DDR]
    jge .m
    mov dx,[DDR]
.m: mov ax,[si]
    imul dx
    mov al,ah
    mov ah,dl
    mov [si],ax
.dn: inc si
    inc si
    inc bx
    test bh,8
    jz .dc                  ; (2048: the next stretch)
    inc word [DU]
    call DUNIT
    xor bx,bx
.dc: loop .dl
.h: mov al,[DISH]            ; hiss. FZED41E: xorshift noise (7, 9, 8; no multiply) shifted down to the level, added to
    dec al                  ; every other word only (white noise with every other value 0 is still white): about a
                            ; third of FZED41D's clocks
    js .x                   ; HISS 0: none
    xor al,0x7f
    shr al,4
    add al,2
    mov cl,al               ; noise >> (2 + (128 - HISS) / 16): about -15 dB at 113-127, 6 dB steps down to -57 dB at 1-16
    mov bp,[LVN]
    inc bp
    shr bp,1                ; words 0, 2, 4 ... of the chunk
    mov si,LVBUF
    mov di,[DRN]
.hl: mov ax,di
    mov bx,ax
    shl bx,7
    xor ax,bx
    mov bx,ax
    shr bx,9
    xor ax,bx
    xor ah,al
    mov di,ax
    sar ax,cl
    add ax,[si]
    jno .w
    mov ax,0x7fff
    js .w
    inc ax
.w: mov [si],ax
    add si,4
    dec bp
    jnz .hl
    mov [DRN],di
.x: pop es
    popa
    ret
DTICK:              ; CF=1 until 4096 timer units (about 40 ms) since the last ageing step; then a step: DCNT from 0
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[DTM]
    cmp ax,0x1000
    jb .r
    mov [DTM],dx
    xor ax,ax
    mov [DCNT],ax
    mov [DCNT+2],ax
.r: ret
