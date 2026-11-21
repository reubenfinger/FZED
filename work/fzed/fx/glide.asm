; ---------- FZED41I Window Snap GLIDE (LWSNAP 107-127; WHOLE FRAMES is now 86-106). On whole frames the loop window
; steps one frame at a time towards where it is sent (knob, matrix, LFO 2, pattern), at most one step per cycle of the
; frame at its original key (36 kHz: about 2.9 timer units a word, 3 used), so a sweep plays every frame on the way
; and never skips one. GLSTEP (main loop) carries on stepping after the last move until the window gets there.
GLC: dw 0                   ; the frame the window is on
GLT: dw 0                   ; the frame it is heading for
GLV: dw 0                   ; the voice they belong to
GLTM: dw 0                  ; timer at the last step
GLP: db 0                   ; the last position sent (0-127)
GLIDX:              ; LOOPWIN, whole frames: ax = the frame sent -> the frame to play now (keeps bx, si)
    push bx
    push bp
    mov bp,sp
    mov bl,[bp+6]           ; the position sent (LOOPWIN keeps it on the stack), for GLSTEP's later steps
    mov [GLP],bl
    pop bp
    mov [GLT],ax
    mov bl,[ACTIVE]
    xor bh,bh
    cmp byte [bx+LWSNAP],107
    jb .j                   ; WHOLE FRAMES: straight there
    cmp si,[GLV]
    jnz .n                  ; another voice: straight there
    mov bx,ax
    mov ax,[GLC]
    call GLDUE
    jc .s                   ; not yet: stay
    cmp ax,bx
    jz .s
    jb .up
    dec ax
    dec ax
.up: inc ax
    mov bx,[0x40a]
    mov [GLTM],bx
    jmp .s
.n: mov [GLV],si
.j:
.s: mov [GLC],ax
    pop bx
    ret
GLDUE:              ; CF=1 if less than one cycle of the frame (3 x LWL timer units) since the last step
    push ax
    push cx
    mov cx,0xffff
    cmp word [LWL+2],0
    jnz .b
    mov ax,[LWL]
    cmp ax,21845
    jae .b
    mov cx,ax
    shl cx,1
    add cx,ax
.b: mov ax,[0x40a]
    sub ax,[GLTM]
    cmp ax,cx
    pop cx
    pop ax
    ret
GLSTEP:             ; main loop: the window still on its way: the next step when due, as the knob does it
    mov ax,[GLC]
    cmp ax,[GLT]
    jz .r
    cmp byte [PREADY],0
    jz .r
    cmp byte [CAPON],0
    jnz .r
    call GLDUE
    jc .r
    call L61DB
    cmp si,[GLV]
    jnz .r
    mov al,[cs:LASTCC]
    push ax
    mov byte [cs:LASTCC],126
    mov al,[GLP]
    call WRITEL
    pop ax
    mov [cs:LASTCC],al
.r: ret
