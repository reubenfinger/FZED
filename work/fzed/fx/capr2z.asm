; PERF38M capture mode: resident hooks in the B800h section (see capr.asm)
CAPTICK:            ; main loop: capture state machine, then the LFOs as before
    cmp byte [CAPON],0
    jz .n
    call CAPRUN
.n: jmp LFOALL
CAPMX:              ; leaving PERF: end capture mode first
    cmp byte [CAPON],0
    jz .n
    call CAPEND
.n: jmp MXOFF
CAPRE:              ; PERF38R (from the overlay, CAPON 1, in CSTART): release, CAPGO again (it deletes the voice on the
    mov byte [CREM],0xCA    ; KSB stack, reloads the overlay and CAPSTART keeps the settings: FZED41C, they stay in LVBUF)
    mov byte [CAPON],0
    jmp CAPGO.k
DSEED: dw 1                 ; FZED41F: dropout pattern seed (fx/dis2.asm DTICK, fx/dis3.asm DUNIT)
DISCAP:             ; FZED41C (resident for room; from DISCP0 in the capture overlay), a take playing: disintegration
                    ; (fx/dis1.asm) over its next 64 words, in place. Each pass
                            ; builds on the last (as Basinski's tape loops); hiss is left out here, as it would build
                            ; up pass after pass. It ages with the timer as live FX do (DISCP0, in the overlay, ages
                            ; it and calls this only once it is no longer new). A last part under 64 words is left.
    mov si,[0xe04]
    mov ax,[si+8]           ; LVSD = the take's start, LVPOS = the place in it (LVSO, left from live FX, only moves
                            ; where the dropout stretches fall)
    mov dx,[si+0xa]
    and dx,0x1f
    mov [LVSD],ax
    mov [LVSD+2],dx
    mov bx,[DCP]
    mov cx,[DCP+2]
    mov [LVPOS],bx
    mov [LVPOS+2],cx
    add ax,bx
    adc dx,cx               ; dx:ax = the chunk's first word
    add bx,64
    adc cx,0
    mov [DCP],bx
    mov [DCP+2],cx
    mov bx,ax
    mov cx,dx
    add bx,63
    adc cx,0                ; its last word
    mov di,[si+0xe]
    and di,0x1f
    cmp cx,di
    jb .k
    ja .z
    cmp bx,[si+0xc]
    ja .z
.k: jmp DISRW              ; (in the capture overlay, for room)
.z: xor ax,ax               ; past the end: round again
    mov [DCP],ax
    mov [DCP+2],ax
    ret

CZERO:              ; PERF38S (moved from the overlay; uses its CEL / CLAST): capture phase time = 0
    xor ax,ax
    mov [CEL],ax
    mov [CEL+2],ax
    mov ax,[0x40a]
    mov [CLAST],ax
    ret
