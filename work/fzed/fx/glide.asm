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
    jmp SOTEXT              ; FZED41P: then the FZ's last message as text (fx/multi.asm), then GLSTEP
.s: inc bx
    cmp al,[bx-1]
    jz .r1
    mov [bx-1],al
    push ax                 ; RH4: always straight to the UART (FZED41L did it only while armed, waiting or recording):
    mov al,0xbf             ; the ROM's MIDI call also acted on the messages inside the FZ, sounding the voice
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
.r1: ret
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
; ---------- FZED41O (in the low area for room)
NEWTK:              ; FZED41O: a finished recording (si = the voice): mode NORMAL, the sustain / end loops off and all 8
    mov word [si+0x10],0x1d7    ; loops on the new take's start .. end, so nothing from the voice's last sample remains:
    mov word [si+0x12],0x0808   ; after Stretch or CHOP the old loop addresses pointed into the old sample's memory and
    push si                     ; a new take could play silent or very quiet. Stretch's saved state goes too.
    lea di,[si+0x14]
    mov cx,8
.l: mov ax,[si+8]
    mov dx,[si+0xa]
    mov [di],ax
    mov [di+2],dx
    mov ax,[si+0xc]
    mov dx,[si+0xe]
    mov [di+0x20],ax
    mov [di+0x22],dx
    add di,4
    loop .l
    pop si
    and byte [STSU],0x7f
    mov byte [STMV],0
    ret
