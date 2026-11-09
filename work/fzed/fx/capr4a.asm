; PERF38U: capture-mode display data moved out of the overlay (fx/capo.asm) for the fade code; space from the old
; exit trace ('EXIT n' on LCD line 7, from the PERF exit-hang hunt), removed
CHNM: db 'ORIGOCTS5+8 MAJ MIN MAJ7MIN75-8-WIDE'
S_COFF: db 'CAPTURE OFF',0
S_CMEM equ S_CM+6        ; PERF38Z: the end of 'CHOP: NO MEMORY'
MXFAIR:             ; PERF38Z (matrixz.asm slow destinations): cl = record x 8 + destination. ZF=1: it had the last slot,
    cmp cl,[MXLW]           ; so it waits this turn (and may have the next); ZF=0: it takes the slot
    jnz .w
    mov cl,0xff
.w: mov [MXLW],cl
    ret
NFV equ MISC+0x115          ; PERF39A: CC110 NORM FILTER choice, 80h + value (0 = none; MISC is cleared at start)
NFAP:               ; PERF39A: the CC110 choice over the record setup's defaults (after every record setup, and on CC110):
    mov al,[NFV]            ; 0-63 off; 64-79 on, 18k cutoff (7Ch); 80-95 9k (6Ch); 96-111 4.5k (5Ch); 112-127 on,
    shl al,1                ; the rate's own cutoff. Nothing chosen: the defaults stand
    jnc .r
    mov ah,al
    in al,0x22
    shl al,1
    shl ah,1                ; CF = on (64-127)
    rcr al,1
    out 0x22,al
    or al,al
    jns .r
    mov al,ah
    shr al,6                ; band 0-3
    mov bx,NFT
    cs xlatb
    or al,al
    jz .r
    out 0xbe,al
.r: ret
NFT: db 0x7C,0x6C,0x5C,0
MOVB:               ; PERF39A: cx bytes ds:si -> ds:di (shared by the voice / buffer copies)
    push es
    push ds
    pop es
    cld
    rep movsb
    pop es
    ret
