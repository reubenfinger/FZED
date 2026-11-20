; ---------- FZED41C disintegration, a live stage after the effect (low area part: controls, ageing; fx/dis2.asm runs it)
; FZED 20 = HISS, FZED 21 = DECAY (how fast the sample ages; 0 rewinds it to new), FZED 22 = DROPOUTS. With live FX on
; (CC119), every chunk the live engine writes passes through it after the CC112 effect: the older the sample, the
; duller it gets and (with DROPOUTS) the more 57 ms stretches drop out, each with a 3.5 ms fade. The same stretches
; drop out as it ages (picked from the sample's own place, not at random), and more of them join. The clean copy is never touched: DECAY 0 brings the sample back as it was. Hiss is added last.
; RENDERED (LIVE) keeps the sample as it sounds at that moment.
DISH: db 0                  ; FZED 20 hiss 0-127 (DISH, DISD, DISP in this order)
DISD: db 0                  ; FZED 21 decay rate
DISP: db 0                  ; FZED 22 dropouts
DAGE: dd 0                  ; age: high word 0 (new) .. FFFFh (gone), low word its fraction
DTM: dw 0                   ; timer at the last ageing step

DISSET:             ; parameter 89 with STSEL 20-22: bl = 0-2, al = value (no LCD message: no room)
    xor bh,bh
    and al,0x7f
    mov [bx+DISH],al
    cmp bl,1
    jnz .m
    or al,al
    jnz .m
    cbw
    mov [DAGE],ax           ; DECAY 0: new again
    mov [DAGE+2],ax
.m: ret

DISAGE:             ; LVRUN, every pass: live on, every 4096 timer units (about 40 ms) the age grows by 4 * decay^2
    cmp byte [LVON],2       ; 65536ths of the way (DECAY 127: new to gone in about 10 s; 8: about 45 minutes)
    jnz .r
.t: mov ax,[0x40a]           ; (capture's driver enters here)
    mov dx,ax
    sub ax,[DTM]
    cmp ax,0x1000
    jb .r
    mov [DTM],dx
    mov al,[DISD]
    mul al
    shl ax,2
    add [DAGE],ax
    adc word [DAGE+2],0
    jnc .r
    mov word [DAGE+2],0xffff
.r: ret

DISPRM:             ; DISCH: the chunk's settings. ZF=1: new and no hiss, nothing to do. Else bp = k, dx:ax = LVPOS, DU / DQ / DDR set.
    mov bl,[DAGE+3]         ; a
    mov al,[DISH]
    mul al
    shr ax,3
    mov [DHA],ax
    xor bh,bh
    or ax,bx
    jz .r
    mov al,120
    mul bl
    not ax
    xor ah,0x80
    mov bp,ax               ; k = 32767 - 120a
    mov al,[DISP]
    mul bl
    shl ax,1
    mov [DTH],ax
    mov ax,[LVPOS]          ; stretch and place from the clean offset
    mov dx,[LVPOS+2]
    push ax
    push dx
    add ax,[LVSO]
    adc dx,[LVSO+2]
    mov cx,ax
    and ch,7
    mov [DQ],cx
    shr ax,11
    shl dx,5
    or ax,dx
    mov [DU],ax
    call DUNIT
    pop dx
    pop ax
    or sp,sp                ; ZF=0
.r: ret
