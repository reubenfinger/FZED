; ---------- FZED41C disintegration, xt area part: its working variables and the dropout pick (fx/dis1.asm, fx/dis2.asm)
DTH: dw 0                   ; dropout threshold
DY: dw 0                    ; (low-pass state, read in from the voice)
DQ: dw 0                    ; place in the 2048-word stretch
DU: dw 0                    ; stretch number
DDR: dw 256                 ; this stretch's level, 0-256 (256: untouched)
DRN: dw 0xACE1              ; hiss noise state
DCNT: dd 0                  ; FZED41D: words through the stage since the last ageing step
DUNIT:              ; DU -> DDR. FZED41D: a stretch fades as DTH passes its hash h: level 256 - (DTH - h) / 16, so it
    mov ax,[DU]             ; goes over about 16 steps of age (DROPOUTS 127) instead of all at once
    add ax,[DSEED]          ; FZED41F: + the seed taken while the sample was new (fx/dis2.asm DTICK)
    mov bx,40503
    mul bx
    xor al,ah
    mul bx
    mov bx,[DTH]
    sub bx,ax
    mov ax,256
    jbe .s                  ; DTH at or below h: untouched
    shr bx,4
    sub ax,bx
    jnc .s
    xor ax,ax
.s: mov [DDR],ax
    ret
