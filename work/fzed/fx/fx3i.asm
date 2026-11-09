; ---------- PERF38D: echo / comb and position effects (live; render goes through the live engine) ----------
; Echo / comb (12): y = x + g * x[n - D], from the clean copy. CC115 delay D = 1 + v^3/256 words (1-8001),
;   CC116 gain g = (v - 64) / 63 (64 = none, 127 = +1, 1 = -1: comb notches instead of peaks), CC117 mix.
; Position (13): CC115 type 0-42 reverse each window, 43-85 stutter (the window's first quarter repeated),
;   86-127 scramble (windows swapped in eights: i <-> i xor 5); CC116 window (16 + (v and 15)) << (v / 16)
;   words (16-3968); CC117 mix. Partial windows at the end of a segment stay in place (scramble) or shrink.
PTYPE equ 0xC3F6            ; 0 reverse, 1 stutter, 2 scramble
PW equ 0xC3F8               ; window (words)
ED equ 0xC3FA               ; echo delay (words)
EG equ 0xC3FC               ; echo gain (Q15)
DBUF equ 0xD400             ; source words for the chunk (128)
TBUF equ 0xD600             ; reversed run (128)
PPOS equ 0xD7F0             ; PSRC: position (dword)
PB equ 0xD7F4               ; window start (dword)
PO equ 0xD7F8               ; place in the window
PWW equ 0xD7FA              ; this window's length (shorter at the segment end)
PQ equ 0xD7FC               ; window number (low word)
S_RD: db 'RENDERED (LIVE) ',0

NXPAR2:             ; FXPAR: echo and position parameters
    mov al,[FXIN]           ; D = 1 + v^3 / 256
    xor ah,ah
    mov bx,ax
    mul bx
    mul bx
    mov al,ah
    mov ah,dl
    inc ax
    mov [ED],ax
    mov al,[FXOUT]          ; g = (v - 64) * 32767 / 63, v at least 1 (0 would overflow the divide)
    xor ah,ah
    or al,al
    jnz .g1
    inc ax
.g1: sub ax,64
    mov cx,32767
    imul cx
    mov cx,63
    idiv cx
    mov [EG],ax
    mov al,[FXIN]
    xor ah,ah
    mov cl,43
    div cl
    mov [PTYPE],al          ; 0 / 1 / 2
    mov al,[FXOUT]          ; W = (16 + (v and 15)) << (v >> 4)
    mov cl,al
    shr cl,4
    and ax,15
    add ax,16
    shl ax,cl
    mov [PW],ax
    ret

FXREN2:             ; render echo / position: clean copy, sweep everything once, keep the result
    mov al,127
    call LVCC
    cmp byte [LVON],1
    jnz .x
.cp: call LVCPY
    cmp byte [LVON],2
    jnz .cp
    call FXPAR
    mov byte [LVDIRTY],0
    call LVSETLEN
    xor ax,ax
    mov [LVPOS],ax
    mov [LVPOS+2],ax
    mov [LVSEGI],al
.sw: call LVCHK
    mov ax,[LVNN]
    sub [LVCLN],ax
    sbb word [LVCLN+2],0
    jnc .sw
    mov byte [LVDV],0       ; release without putting the clean words back
    mov byte [LVDS],0
    call LVOFF
    mov bx,S_RD
    jmp NMSG
.x: ret

RDCLEAN:            ; cx words of the segment's clean copy from position dx:ax into [di]
    jcxz .r
    add ax,[LVSO]
    adc dx,[LVSO+2]
    add ax,[LVSRC]
    adc dx,[LVSRC+2]
    call LVRDX
.r: push ds
    pop es
    ret

ECPREP:             ; live echo: DBUF = clean words D before the chunk (0 before the segment start)
    mov bx,[ED]             ; PERF38I: the same as ECTAP (fx5bi.asm) with bx = D
    mov di,DBUF
    jmp ECTAP

POPREP:             ; live position: DBUF = the chunk's source words, run by run
    xor bp,bp
.run: mov cx,[LVN]
    sub cx,bp
    jnz .go
    ret
.go: push cx
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    add ax,bp
    adc dx,0
    call PSRC               ; dx:ax = source of this word, cx = run, bl = 1 reversed
    pop di
    cmp cx,di
    jbe .l
    mov cx,di
.l: push cx
    push bx
    or bl,bl
    jnz .rv
    lea di,[bp+DBUF]
    add di,bp
    call RDCLEAN
    pop bx
    pop cx
    add bp,cx
    jmp .run
.rv: inc ax                 ; reversed: words src-L+1 .. src read forwards, then turned round
    adc dx,0
    sub ax,cx
    sbb dx,0
    mov di,TBUF
    call RDCLEAN
    pop bx
    pop cx
    lea di,[bp+DBUF]
    add di,bp
    mov si,TBUF
    add si,cx
    add si,cx
.c: sub si,2
    mov ax,[si]
    mov [di],ax
    add di,2
    inc bp
    loop .c
    jmp .run

PSRC:               ; segment position dx:ax -> dx:ax source position, cx words in this run, bl 1 = reversed
    mov [PPOS],ax
    mov [PPOS+2],dx
    mov cx,[PW]
    mov bx,ax
    mov ax,dx
    xor dx,dx
    div cx
    mov ax,bx
    div cx
    mov [PQ],ax
    mov [PO],dx
    mov ax,[PPOS]           ; b = pos - o
    mov dx,[PPOS+2]
    sub ax,[PO]
    sbb dx,0
    mov [PB],ax
    mov [PB+2],dx
    mov bx,[LVSL]           ; W' = min(W, length - b)
    mov si,[LVSL+2]
    sub bx,ax
    sbb si,dx
    jnz .wf
    cmp bx,cx
    jb .ws
.wf: mov bx,cx
.ws: mov [PWW],bx
    mov al,[PTYPE]
    or al,al
    jnz .ns
    mov ax,bx               ; reverse: src = b + W' - 1 - o, run W' - o going down
    dec ax
    sub ax,[PO]
    xor dx,dx
    add ax,[PB]
    adc dx,[PB+2]
    sub bx,[PO]
    mov cx,bx
    mov bl,1
    ret
.ns: cmp al,1
    jnz .sc
    shr bx,2                ; stutter: R = W' / 4, src = b + (o mod R), run R - (o mod R)
    jnz .r1
    inc bx
.r1: mov ax,[PO]
    xor dx,dx
    div bx
    sub bx,dx
    mov cx,bx
    mov ax,dx
    xor dx,dx
    add ax,[PB]
    adc dx,[PB+2]
    xor bl,bl
    ret
.sc: cmp bx,cx              ; scramble: whole windows only
    jnz .id
    mov ax,[PQ]
    mov dx,ax
    xor dx,5
    sub dx,ax               ; partner - this (+-1, 3 or 5)
    mov ax,dx
    imul cx
    add ax,[PB]
    adc dx,[PB+2]
    push ax
    push dx
    add ax,cx               ; partner whole inside the segment?
    adc dx,0
    cmp dx,[LVSL+2]
    jb .ok
    ja .no
    cmp ax,[LVSL]
    jbe .ok
.no: pop dx
    pop ax
    jmp .id
.ok: pop dx
    pop ax
    add ax,[PO]
    adc dx,0
    sub cx,[PO]
    xor bl,bl
    ret
.id: mov ax,[PPOS]
    mov dx,[PPOS+2]
    mov cx,[PWW]
    sub cx,[PO]
    xor bl,bl
    ret

FXLE:               ; echo / comb: x + g * DBUF, saturated, mix
    mov di,DBUF
.l: mov ax,[es:si]
    mov [FXD],ax
    mov ax,[di]
    imul word [EG]
    shl ax,1
    rcl dx,1
    mov ax,dx
    add ax,[FXD]
    jno .m
    mov ax,0x7fff
    test byte [FXD+1],0x80
    jz .m
    mov ax,0x8000
.m: call MIXW
    mov [es:si],ax
    add si,2
    add di,2
    loop .l
    ret

FXLQ:               ; position: DBUF word, mix
    mov di,DBUF
.l: mov ax,[es:si]
    mov [FXD],ax
    mov ax,[di]
    call MIXW
    mov [es:si],ax
    add si,2
    add di,2
    loop .l
    ret
