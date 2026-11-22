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
; ---------- FZED41K STATUS OUT (FZED 24 >= 64; off at start-up): the record state (0 idle, 1 armed, 2 waiting, 3
; recording, 4 done, 5 used, 6 no memory), the record rate (16 + 0-3: 36k, 18k, 9k, 4.5k) and the slice count (64 +
; 0-63) to MIDI OUT as CC3 on channel 16 (the ROM's MIDI call ORs in the basic channel: 16 stays 16), each only when it
; changes. For the Gills (Core 123): its RECORD page shows them. The ROM's internal copy of the message is taken back
; out of its queue (write pointer 0BE0h put back), so only MIDI OUT sends it and the FZ itself never acts on it.
SOL: db 0xff,0xff,0xff      ; last sent: state, rate, slices (FFh: send)
STSTAT:             ; main loop, then on into GLSTEP
    cmp byte [STOUT],64
    jb GLSTEP
    mov bx,SOL
    mov al,[RST]
    call .s
    mov al,[0x4d9]
    and al,3
    or al,16
    call .s
    mov al,[NBND]
    and al,63
    or al,64
    call .s
    jmp short GLSTEP
.s: inc bx
    cmp al,[bx-1]
    jz .r1
    mov [bx-1],al
    mov ah,[RST]            ; FZED41L: armed, waiting or recording: the FZ's MIDI interrupts are off (FZED polls the UART
    dec ah                  ; itself), so the ROM's queue would hold it until afterwards: sent straight to the UART
    cmp ah,3
    jb .u
    push bx
    push word [0xbe0]
    xor ah,ah
    push ax
    push word 3
    push word 0xbf
    APIC 0x33,6
    pop word [0xbe0]
    pop bx
.r1: ret
.u: push ax
    mov al,0xbf
    call .tx
    mov al,3
    call .tx
    pop ax
.tx: mov ah,al              ; one byte to the 8251 when it is ready (TxRDY), or after about 64K tries
    xor cx,cx
.t1: in al,0xd2
    test al,1
    loopz .t1
    mov al,ah
    out 0xd0,al
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
