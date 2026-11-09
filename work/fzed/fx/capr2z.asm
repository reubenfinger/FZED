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
CAPRE:              ; PERF38R (from the overlay, CAPON 1, in CSTART): settings to LVBUF, release, CAPGO again (it deletes
    push es         ; the voice on the KSB stack, reloads the overlay and CAPSTART takes the settings back)
    push ds
    pop es
    cld
    mov si,CHM-2            ; PERF38Z: the capture variables start 2 bytes below CHM (CRLM, CNF)
    mov di,LVBUF
    mov cx,0x20
    rep movsw
    pop es
    mov byte [LVBUF+0x40],0xCA
    mov byte [CAPON],0
    jmp CAPGO
CZERO:              ; PERF38S (moved from the overlay; uses its CEL / CLAST): capture phase time = 0
    xor ax,ax
    mov [CEL],ax
    mov [CEL+2],ax
    mov ax,[0x40a]
    mov [CLAST],ax
    ret
