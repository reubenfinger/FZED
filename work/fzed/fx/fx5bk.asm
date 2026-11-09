; PERF38H part in the main section after the matrix (see fx5.asm)
; ---- echo: CC114 >= 64 = three reflections at D, 13D/7, 23D/7 (D/2 + D2/4 + D3/4, read from the clean copy)
ECPREP2:
    cmp byte [FXDF],64
    jae .m
    jmp ECPREP
.m: push bp
    push es
    push ds
    pop es
    cld
    mov di,DBUF             ; DBUF = 0, then each tap added in from TBUF
    mov cx,[LVN]
    xor ax,ax
    rep stosw
    pop es
    mov cx,0x0107           ; D * 7/7, / 2
    call .tp
    mov cx,0x020d           ; D * 13/7, / 4
    call .tp
    mov cx,0x0217           ; D * 23/7, / 4
    call .tp
    pop bp
    ret
.tp: push cx
    mov ax,[ED]
    xor ch,ch
    mul cx
    mov cx,7
    div cx
    mov bx,ax
    mov di,TBUF
    call ECTAP
    pop cx
    mov cl,ch
    mov si,DBUF
    mov di,TBUF
    mov bp,[LVN]
.l: mov ax,[di]
    sar ax,cl
    add [si],ax
    add si,2
    add di,2
    dec bp
    jnz .l
    ret
ECTAP:              ; [di] = LVN clean words bx before the chunk (0 before the segment start)
    mov cx,[LVN]
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    sub ax,bx
    sbb dx,0
    jnc .rd
    sub bx,[LVPOS]
    cmp bx,cx
    jbe .z
    mov bx,cx
.z: sub cx,bx
    push cx
    mov cx,bx
    xor ax,ax
    push es
    push ds
    pop es
    cld
    rep stosw
    pop es
    pop cx
    xor ax,ax
    xor dx,dx
.rd: jmp RDCLEAN

NPAD:               ; FZED: NMSG's print: blank line 3, then the message (bx). PRT has no column: cx is the
    push bx         ; attribute (1 = inverse, as the title), so the line is cleared by a full-width blank first
    mov bx,S_BL
    xor cx,cx
    mov dx,3
    call PRT
    pop bx
    xor cx,cx
    mov dx,3
    jmp PRT
PMSG:               ; FZED: CC70 set the play mode (al = value >> 5): name it
    mov bx,S_MOG
    or al,al
    jz NMSGD
    mov bx,S_MRV
    dec al
    jz NMSGD
    mov bx,S_MCU
    jmp short NMSGD
LMSG:               ; FZED: CC86 loop mode, then its name (0-42 one-shot, 43-84 original, 85-127 loop)
    cmp bl,86           ; (CC87 / CC88 / loop window go straight to LOOPCC)
    jnz LOOPCC
    push ax
    call LOOPCC
    pop ax
    mov bx,S_MOS
    cmp al,43
    jb NMSGD
    mov bx,S_MOG
    cmp al,85
    jb NMSGD
    mov bx,S_MSE
; ---- LCD pacing: FX value messages and the CC echo line wait until about 60 ms after the last paced write
NMSGD:              ; bx = FX value message
    cmp byte [MXQ],0
    jnz LCDCHK.r
    mov [LCDP],bx
    mov byte [LCDE],2       ; PERF38I: this control has its own message, no CC echo for it
    jmp short LCDCHK
LCDCHK:             ; write one waiting line if it is time
    mov ax,[0x40a]
    sub ax,[LCDT]
    cmp ax,LCDINT
    jb .r
    mov bx,[LCDP]
    or bx,bx
    jz .e
    call .t
    jmp NMSG                ; (clears LCDP)
.e: cmp byte [LCDE],1
    jnz .r
    mov byte [LCDE],0
    call .t
    mov bx,S_C
    xor cx,cx
    mov dx,4
    jmp PRT
.t: mov ax,[0x40a]
    mov [LCDT],ax
.r: ret



PATSRC:             ; MXSRC sources 12 and up (ah = 0)
    cmp al,13
    ja .z
    mov cl,al
    mov al,[PV]
    cmp cl,13
    jz .r
    sub ax,127
.r: ret
.z: xor ax,ax
    ret

PATPAR:             ; PERF parameters 8 pattern, 9 rate, 87 smoothing (al = value)
    cmp bl,8
    jnz .p9
    shr al,3
    mov [PATN],al
    ret
.p9: cmp bl,9
    jnz .p87
    mov [PATR],al
    ret
.p87: cmp bl,87
    jnz STRP                ; PERF40F: 88 / 89 are STRETCH
    mov [PATS],al
.r: ret

ZCOK:               ; PERF38I, ZCNEAR: ZF=1 only for a zero crossing at dx:ax with GSAVE < dx:ax <= AE (in the sample)
    push cx
    mov cx,[GSAVE+2]
    and cx,0x1f
    cmp dx,cx
    jb .n
    ja .a
    cmp ax,[GSAVE]
    jbe .n
.a: mov cx,[AEH]
    and cx,0x1f
    cmp dx,cx
    jb .z
    ja .n
    cmp ax,[AEL]
    ja .n
.z: pop cx
    jmp ZCAT
.n: pop cx
    or sp,sp
    ret

SVMCHK2:            ; PERF38I, SVPAR: the filter map is cleared once when the filter is left or re-entered, not on every
    mov al,1                ; parameter update of another effect (that also restarted the sweep each time)
    cmp byte [FXM],8
    jnz .n
    dec ax
.n: xchg al,[SVMOFF]
    cmp al,[SVMOFF]
    jz .s
    jmp SVMAPCHK.clr        ; filter <-> other effect
.s: or al,al
    jnz .r                  ; another effect, already cleared
    jmp SVMAPCHK            ; filter: as before
.r: ret

GAPENT:             ; |x| = 64k: crossover (x - T) * 32767 / (32767 - T) morphing to a pulse of GAPA as CC116 rises
    mov ax,cx
    shl ax,6
    sub ax,[GAPT]
    jbe .z
    mov bx,ax
    mov dx,32767
    mul dx
    cmp dx,[GAPM]
    jae .cl
    div word [GAPM]
    cmp ax,32767
    jbe .cr
.cl: mov ax,32767
.cr: mov bx,GAPA
    jmp short .mx
.z: xor ax,ax
    xor bx,bx
.mx: sub bx,ax              ; y = cross + (fuzz - cross) * c / 127
    push ax
    mov ax,bx
    mov bl,[GAPC]
    xor bh,bh
    imul bx
    mov bx,127
    idiv bx
    pop bx
    add ax,bx
    ret

