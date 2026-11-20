; ---------- FZED41C disintegration, xt area part: its working variables and the dropout pick (fx/dis1.asm, fx/dis2.asm)
DTH: dw 0                   ; dropout threshold
DHA: dw 0                   ; hiss amplitude
DY: dw 0                    ; (low-pass state, read in from the voice)
DQ: dw 0                    ; place in the 2048-word stretch
DU: dw 0                    ; stretch number
DDR: db 0                   ; FFh = this stretch drops out
DRN: dw 0xACE1              ; hiss noise state
DUNIT:              ; DU -> DDR: FFh when the stretch's hash is below DTH
    mov ax,[DU]
    inc ax
    mov bx,40503
    mul bx
    xor al,ah
    mul bx
    cmp ax,[DTH]
    sbb al,al
    mov [DDR],al
    ret
