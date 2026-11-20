; ---------- FZED41C disintegration, a live stage after the effect (low area part: controls, ageing; fx/dis2.asm runs it)
; FZED 20 = HISS, FZED 21 = DECAY (how fast the sample ages; 0 rewinds it to new), FZED 22 = DROPOUTS. With live FX on
; (CC119), every chunk the live engine writes passes through it after the CC112 effect: the older the sample, the
; duller it gets and (with DROPOUTS) the more 57 ms stretches drop out, each with a 3.5 ms fade. The same stretches
; drop out as it ages (picked from the sample's own place, not at random), and more of them join. The clean copy is never touched: DECAY 0 brings the sample back as it was. Hiss is added last.
; RENDERED (LIVE) keeps the sample as it sounds at that moment.
DISH: db 0                  ; FZED 20 hiss 0-127 (DISH, DISD, DISP in this order)
DISD: db 0                  ; FZED 21 decay rate
DISP: db 0                  ; FZED 22 dropouts
DIS4: db 0                  ; FZED 23 EVEN AGEING (FZED41D): 0 off; FZED41E: 1-127, 2^(value / 16) steps a round
DTM: dw 0                   ; timer at the last ageing step
DAGE: dd 0                  ; age: high word 0 (new) .. FFFFh (gone), low word its fraction

DISSET:             ; parameter 89 with STSEL 20-23: bl = 0-3, al = value 0-127 (no LCD message: no room)
    xor bh,bh
    mov [bx+DISH],al
    dec bx
    jnz .m                  ; (DECAY)
    or al,al
    jnz .m
    cbw
    mov [DAGE],ax           ; DECAY 0: new again
    mov [DAGE+2],ax
.m: ret

DISAGE:             ; LVRUN, every pass: live on, every 4096 timer units (about 40 ms) the age (high word) grows by
    cmp byte [LVON],2       ; decay^2 / 64 (DECAY 127: new to gone in about 10 s; 32: 2.7 minutes; 8: about 45 minutes)
    jnz .r
    call DCOV               ; FZED41D: EVEN AGEING (fx/dis2.asm)
    jc .r
.t: call DTICK              ; (capture's driver enters here)
    jc .r
    mov al,[DISD]
    mul al
    mov cx,1024             ; FZED41D: decay^2 x 1024 (FZED41C added it 256 times too low: 43 minutes at 127)
    mul cx
    add [DAGE],ax
    adc [DAGE+2],dx
    jnc .r
    or word [DAGE+2],-1      ; (held at full)
.r: ret

DISPRM:             ; DISCH: the chunk's settings. ZF=1: new and no hiss, nothing to do. Else dx:ax = LVPOS, bp = dulling k, DTH / DU / DQ /
                    ; DDR set.
    mov ax,[LVN]            ; FZED41D: words through the stage, for EVEN AGEING. FZED41E: counted 2^(EVEN AGEING / 16)
    mov cl,[DIS4]           ; times over, so 1-15 allows one ageing step per time round the sample, 16-31 two, ... 112-127
    shr cl,4                ; 128 (DISAGE's timer still limits it to one step each 40 ms)
    shl ax,cl
    add [DCNT],ax
    adc word [DCNT+2],0
    mov bl,[DAGE+3]         ; a
    mov al,[DISH]
    or al,bl                ; (FZED41E: hiss is set in DISCH)
    jz .r
    mov al,[DISP]
    mul bl
    shl ax,1
    mov [DTH],ax
    mov al,bl               ; FZED41D: bp = dulling k = (256 - a)^2 / 2, with 300h ORed in as its floor (a = 0: unused)
    neg al
    mul al
    shr ax,1
    or ah,3
    mov bp,ax
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

DCOV:               ; FZED41D (FZED41E: here for room), live FX only: with EVEN AGEING on, CF=1 until the stage has had as many words as the clean
    cmp byte [DIS4],0       ; copy holds (LVLEN) since the last ageing step, so the age moves on only once the live engine
    jz .r                   ; has been round, and old and new pieces differ by one step at most (CF=0 from cmp)
    mov ax,[DCNT]
    mov dx,[DCNT+2]
    sub ax,[LVLEN]
    sbb dx,[LVLEN+2]
.r: ret
