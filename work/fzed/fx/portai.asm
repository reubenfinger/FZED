; ---------- PERF38: mono portamento (glide) through pitch bend ----------
; PERF parameter 5 = glide time, 6 = glide mode (0-42 off, 43-85 legato: only while a note is held, 86-127 always).
; MIDI CC5 also sets the time. While glide is on the FZ bend depth is 127 (about +/-16 semitones); the player's bend,
; the matrix and LFO 2 are scaled back to the depth set before, and the glide is added on top.
PGT equ 0xC394              ; glide time 0-127
PGM equ 0xC395              ; 0 off, 1 legato, 2 always
PK equ 0xC396               ; glide factor per matrix pass (Q16)
PBDEP equ 0xC398            ; bend depth before glide was switched on
PBON equ 0xC399
PG equ 0xC39A               ; [16] words: glide offset per channel, 1/8 semitone x 256
PHELD equ 0xC3BA            ; [16] notes held per channel
PHN equ 0xC3CA              ; [16] 1 once a note has been played on the channel

PINIT:
    xor ax,ax
    mov di,PGT
    mov cx,(PHN+16-PGT)/2
.c: mov [di],ax
    add di,2
    loop .c
    mov al,64
    call PSETT
    ret

PSETT:              ; al = glide time 0-127 -> PK = 1 - e^(-1.2 ms / T), T = 1 + t^2/32 ms
    and ax,0x7f
    mov [PGT],al
    mul al
    shr ax,2
    add ax,10               ; T in 1/8 ms (1.25 ms + t^2/32)
    mov cx,ax
    mov ax,0x9999           ; 629145 = 65536 * 1.2 ms * 8
    mov dx,0x0009
    div cx
    cmp ax,32767
    jbe .s
    mov ax,32767
.s: mov [PK],ax
    ret

PPARAM:             ; PERF parameters 5 (time) and 6 (mode), 7 voice INIT, 8/9 pattern; bl = id, al = value
    cmp bl,8
    jb .n8
    jmp PATPAR
.n8:
    cmp bl,7
    jnz .n7
    jmp VINIT
.n7: cmp bl,5
    jnz .m
    jmp PSETT
.m: cmp bl,6
    jnz .r
    mov ah,0
    cmp al,43
    jb .s
    inc ah
    cmp al,86
    jb .s
    inc ah
.s: mov [PGM],ah
    or ah,ah
    jz .off
    cmp byte [PBON],0
    jnz .r
    mov al,[0x5288]         ; on: remember the bend depth, open it to 127
    mov [PBDEP],al
    mov byte [0x5288],127
    mov byte [PBON],1
.r: ret
.off: jmp PRESTORE

PRESTORE:           ; glide off / leaving PERF: bend depth back, glide gone, bend back to the player's
    cmp byte [PBON],0
    jz .r
    mov al,[PBDEP]
    mov [0x5288],al
    mov byte [PBON],0
    xor bx,bx
.l: mov ax,bx
    mov cl,0x18
    mul cl
    add ax,0x52a0
    mov di,ax
    mov al,[bx+CBEND]
    mov [di],al
    push bx
    shl bx,1
    mov word [bx+PG],0
    pop bx
    inc bx
    cmp bx,16
    jb .l
.r: ret

PNON:               ; note-on, bx = channel, ah = new note (keeps all registers)
    cmp byte [PGM],0
    jz .h
    cmp byte [bx+PHN],0
    jz .ng
    cmp byte [PGM],1
    jnz .go
    cmp byte [bx+PHELD],0
    jnz .go
.ng: push bx                ; a note that does not glide starts at its own pitch
    shl bx,1
    mov word [bx+PG],0
    pop bx
    jmp .h
.go: push ax
    push cx
    push dx
    push bx
    mov al,[bx+CNOTE]       ; glide from the previous note (plus whatever is left of the last glide)
    sub al,ah
    cbw
    mov cx,2064             ; semitones -> 1/8 semitone x 256 at depth 127
    imul cx
    shl bx,1
    mov cx,[bx+PG]
    push dx
    mov dx,cx
    sar dx,15
    add ax,cx
    pop cx
    adc dx,cx
    cmp dx,0                ; clamp to +/-127 x 256
    jl .neg
    jg .hi
    cmp ax,32512
    jbe .st
.hi: mov ax,32512
    jmp .st
.neg: cmp dx,-1
    jl .lo
    cmp ax,-32512
    jae .st
.lo: mov ax,-32512
.st: mov [bx+PG],ax
    pop bx
    pop dx
    pop cx
    pop ax
.h: mov byte [bx+PHN],1
    cmp byte [bx+PHELD],127
    jae .r
    inc byte [bx+PHELD]
.r: ret

GLDEC:              ; PERF38I: one glide step for every channel, called from PATTICK at the glide pace (PGINT), so a
    cmp byte [PGM],0    ; channel shared by several records still steps once
    jz .r
    mov bx,30
.l: mov ax,[bx+PG]
    or ax,ax
    jz .n
    mov cx,ax
    imul word [PK]          ; dx = glide * k
    or dx,dx
    jnz .d
    mov dx,1                ; at least one step towards 0
    or cx,cx
    jns .d
    mov dx,-1
.d: mov ax,cx
    sub ax,dx
    xor cx,ax               ; crossed zero: stop
    jns .k
    xor ax,ax
.k: mov [bx+PG],ax
.n: sub bx,2
    jns .l
.r: ret

PNOFF:              ; note-off, bx = channel
    cmp byte [bx+PHELD],0
    jz .r
    dec byte [bx+PHELD]
.r: ret

PTICK:              ; each matrix pass, record MXR / channel MXCH: glide towards 0, write the bend byte
    cmp byte [PGM],0
    jnz .on
    ret
.on:                        ; (PERF38I: the glide step itself is GLDEC, once per channel at the glide pace)
.z: mov bl,[MXCH]
    and bx,0x0f
    mov al,[bx+CBEND]       ; the player's bend
    cbw
    mov cx,ax
    test word [MXOLD],0x10
    jz .nm
    mov bl,[MXR]
    xor bh,bh
    shl bx,3
    mov al,[bx+MXF+4]       ; matrix sum on pitch
    cbw
    add cx,ax
.nm: push cx
    mov dl,4
    call MXLFP              ; LFO 2's pitch-bend part
    pop ax
    add ax,cx
    mov cl,[PBDEP]          ; back to the depth the player had
    xor ch,ch
    imul cx
    mov cx,127
    idiv cx
    mov bl,[MXCH]
    and bx,0x0f
    shl bx,1
    mov dx,[bx+PG]
    mov cl,8
    sar dx,cl
    add ax,dx
    call CLAMP
    mov bx,[MXBLK]
    mov [bx],al
    ret
