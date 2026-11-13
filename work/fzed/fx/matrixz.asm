; PERF38Z: matrixw.asm + fairer slow destinations (one that was written last waits a turn, MXFAIR). PERF38W: matrixu.asm + parameters 3 / 4 (loop window) refused while capturing (PERF38U: matrixh.asm without MAINSP)
; ---------- PERF37: parameter select/value, LFO 2 delay + fade-in, 10-slot mod matrix per voice ----------
MISC equ 0xC210
LFDLY equ MISC+0x00         ; [8] LFO 2 delay (0-127) per record
LFFAD equ MISC+0x08         ; [8] LFO 2 fade-in
LFYNG equ MISC+0x10         ; [8] a young note was playing on the last pass
LFENV equ MISC+0x18         ; [8] words: interrupts since this voice's last new note (saturating)
LFTM3 equ MISC+0x28         ; [8] words: timer at the last LFO 2 pass
LREC equ MISC+0x38          ; record whose LFO 2 is running
PRAW equ MISC+0x39          ; WRITE: raw store for the parameter path
MXQ equ MISC+0x3A           ; matrix call: no LCD message, no base capture
MXSD equ MISC+0x3B          ; a slow destination was applied this pass
MXTM equ MISC+0x3C          ; word
MXST equ MISC+0x3E          ; word
PSEL equ MISC+0x40          ; [16] parameter chosen by CC10, per MIDI channel
EFSAVE equ MISC+0x50        ; [24] FZ effect depths at start (ESC restores)
CVEL equ MISC+0x70          ; [16] per MIDI channel: last note-on velocity
CNOTE equ MISC+0x80         ; last note number
CAT equ MISC+0x90           ; channel aftertouch
CMW equ MISC+0xA0           ; mod wheel (CC1)
CRND equ MISC+0xB0          ; random value picked at each note-on
CBEND equ MISC+0xC0         ; pitch bend (signed, -128..126)
CM2 equ MISC+0xD0           ; CC2
CM3 equ MISC+0xE0           ; CC3
CM4 equ MISC+0xF0           ; CC4
IQP equ 0xC3E4              ; [2] read positions in the ROM's event queues 0 and 2 (the FZ's own keyboard/wheel/aftertouch)
IQS equ 0xC3E6              ; [2] running status
IQD equ 0xC3E8              ; [2] first data byte
IQC equ 0xC3EA              ; [2] data count
RSTAT equ MISC+0x100        ; MIDI running status
RDCNT equ MISC+0x101
RD1 equ MISC+0x102
RNDS equ MISC+0x104         ; word
MXR equ MISC+0x106          ; record being evaluated
MXCH equ MISC+0x107
MXBLK equ MISC+0x108        ; word: its channel's controller block
MXNU equ MISC+0x10A         ; word: destinations used now
MXOLD equ MISC+0x10C        ; word: used now or on the last pass
MXI equ MISC+0x10E          ; word: slot index
MXD0 equ MISC+0x110         ; word: destination index
RAWCH equ MISC+0x116        ; PERF39D: MIDI channel of the last channel message, before voice-mode omni
MXLW equ MISC+0x114         ; PERF38Z: record x 8 + destination last given the slow-write slot
MXLF equ MISC+0x112
MXSAV equ MISC+0x113
MXLU equ MISC+0x118         ; [8] record uses LFO 2 as a source
MXUSE equ MISC+0x120        ; [8] words: destinations used on the last pass
LFRAW equ MISC+0x130        ; [8] words: LFO 2 before its depth (matrix source)
LWSNAP equ MISC+0x140       ; [8] loop window snap: 0-42 free, 43-85 zero-cross, 86-127 whole frames
LWL equ MISC+0x148          ; dword: window length
LWS equ MISC+0x14C          ; dword: span / scratch
MTX equ 0xD100
MXS equ MTX                 ; [8][10] source (0-15)
MXA equ MTX+0x50            ; [8][10] amount (64 = 0)
MXD equ MTX+0xA0            ; [8][10] destination (0-15)
MXB equ MTX+0xF0            ; [8][8] base value of slow destinations 8-15 (last value sent by the user)
MXL equ MTX+0x130           ; [8][8] last value the matrix applied
MXF equ MTX+0x170           ; [8][8] matrix sum on fast destinations 0-7
MSUM equ MTX+0x1B0          ; [16] words

FOFF: db 0,0x0f,0x10,0x0e,0x00,0x0a,0x0b,0x0c   ; fast destinations -> controller block byte
SLOWCC: db 76,126,87,88,89,90,117,94             ; 126 = loop window (internal)             ; slow destinations 8-15 -> PERF CC
MXBDEF: db 0,0,0,127,64,0,127,64

MXINIT:             ; startup
    call PINIT
    call SVINIT
    mov al,[0xbe0]          ; follow the FZ's own event queues from now on
    mov [IQP],al
    mov al,[0xde8]
    mov [IQP+1],al
    mov word [IQS],0
    push es
    push ds
    pop es
    cld
    xor al,al
    mov di,MISC
    mov cx,0x150
    rep stosb
    mov di,MTX
    mov cx,0x1d0
    rep stosb
    mov di,CNOTE
    mov cx,16
    mov al,60
    rep stosb
    mov si,0x5288
    mov di,EFSAVE
    mov cx,24
    rep movsb
    pop es
    mov ax,[0x40a]
    or ax,1
    mov [RNDS],ax
    xor bx,bx
.c: push bx
    call MXCLR
    pop bx
    inc bx
    cmp bx,8
    jb .c
    ret

MXCLR:              ; bx = record: no matrix slots, no LFO 2 delay/fade
    push si
    push di
    xor bh,bh
    mov byte [bx+LFDLY],0
    mov byte [bx+LFFAD],0
    mov byte [bx+LFYNG],0
    mov byte [bx+MXLU],0
    shl bx,1
    mov word [bx+LFENV],0xffff
    shr bx,1
    mov al,bl
    mov ah,10
    mul ah
    mov di,ax
    mov cx,10
.s: mov byte [di+MXS],0
    mov byte [di+MXA],64
    mov byte [di+MXD],0
    inc di
    loop .s
    mov di,bx
    shl di,3
    xor si,si
.b: mov al,[cs:si+MXBDEF]
    mov [di+MXB],al
    mov byte [di+MXL],0xff
    mov byte [di+MXF],0
    inc di
    inc si
    cmp si,8
    jb .b
    pop di
    pop si
    ret

RAND:               ; al = random byte
    push dx
    mov ax,[RNDS]
    mov dx,25173
    mul dx
    add ax,13849
    mov [RNDS],ax
    mov al,ah
    pop dx
    ret

PARSE:              ; MIDI in (running status): notes/pressure/bend/CC1-4 feed the matrix; CC10-110, 112-119 returned (CF=0, al = value)
    call L6331
    jc .r
    cmp al,0xf8
    jb .nr
    call RTB2
    jmp PARSE
.nr: cmp al,0x80
    jb .dat
    cmp al,0xf0
    jb .st
    mov byte [RSTAT],0      ; system common / SysEx: no running status
    jmp PARSE
.st: mov [RSTAT],al
    mov byte [RDCNT],0
    jmp PARSE
.dat: mov dl,[RSTAT]
    or dl,dl
    jz PARSE
    mov bl,dl
    and bx,0x0f             ; channel
    mov [RAWCH],bl          ; PERF39D: the channel it really arrived on (bank add / clear use it in voice mode too)
    cmp byte [BKON],0       ; voice mode: any channel feeds the voice's matrix (omni)
    jnz .chk
    mov bl,[CURCH]
    and bx,0x0f
.chk: and dl,0xf0
    cmp dl,0xd0
    jnz .nat
    mov [bx+CAT],al         ; channel pressure
    jmp PARSE
.nat: cmp dl,0xc0
    jz PARSE
    cmp byte [RDCNT],0
    jnz .d2
    mov [RD1],al
    mov byte [RDCNT],1
    jmp PARSE
.d2: mov byte [RDCNT],0
    mov ah,[RD1]            ; ah = first data byte, al = second
    cmp dl,0xa0             ; poly pressure: use as channel aftertouch
    jnz .npa
    mov [bx+CAT],al
    jmp PARSE
.npa: cmp dl,0x90
    jnz .non
    or al,al
    jz .nof                 ; velocity 0 = note off
    mov [bx+CVEL],al
    call PNON2
    mov [bx+CNOTE],ah
    call RAND
    mov [bx+CRND],al
    jmp PARSE
.non: cmp dl,0xe0
    jnz .npb
    sub al,64               ; bend MSB -> -128..126
    shl al,1
    mov [bx+CBEND],al
    jmp PARSE
.npb: cmp dl,0xb0
    jz .isb
    cmp dl,0x80             ; note off
    jnz PARSE
.nof: call PNOFF
    jmp PARSE
.isb:
    cmp ah,10
    jae .cc
    cmp ah,1
    jnz .c2
    mov [bx+CMW],al
    jmp PARSE
.c2: cmp ah,2
    jnz .c3
    mov [bx+CM2],al
    jmp PARSE
.c3: cmp ah,3
    jnz .c4
    mov [bx+CM3],al
    jmp PARSE
.c4: cmp ah,4
    jnz .c5
    mov [bx+CM4],al
    jmp PARSE
.c5: cmp ah,5               ; CC5 = glide time
    jnz .c9
    call PSETT
    jmp PARSE
.c9: cmp ah,9               ; CC9 = preset wave load (CC111 picks it)
    jnz PARSE
    call WVCC
    jmp PARSE
.cc: cmp ah,111
    jnz .n111
    call WVSEL
    jmp PARSE
.n111:
    cmp ah,120              ; CC120 all sound off / CC123 all notes off: panic on this channel
    jz .pn
    cmp ah,123
    jnz .n123
.pn: mov al,[RSTAT]
    call PANIC
    jmp PARSE
.n123: cmp ah,120
    jae PARSE
    mov [CCCH],bl
    mov [cs:LASTCC],ah
    xor ah,ah
    clc
.r: ret

MXCAP:              ; user sent a CC that is a slow matrix destination: it becomes that destination's base
    cmp byte [MXQ],0
    jnz .r
    mov dl,[cs:LASTCC]
    call SVUNMAP
    xor bx,bx
.f: cmp dl,[cs:bx+SLOWCC]
    jz .h
    inc bx
    cmp bx,8
    jb .f
.r: ret
.h: mov dl,bl
    mov bl,[ACTIVE]
    xor bh,bh
    shl bx,3
    add bl,dl
    mov [bx+MXB],al
    mov byte [bx+MXL],0xff  ; re-apply base + modulation on the next pass
    ret

PARAM:              ; CC11 = value of the parameter chosen with CC10 on this channel
    mov bl,[CCCH]
    and bx,0x0f
    mov bl,[bx+PSEL]
    xor bh,bh
    or bl,bl
    jnz .p1
    cmp byte [PREADY],0     ; 0: LFO 1 delay, one control (v*v/3 x 2 ms: 0 .. 10.8 s)
    jz .r
    call L61S               ; PERF40G: the chosen slice in per-slice mode
    mul al
    mov cx,3
    xor dx,dx
    div cx
    mov [si+0x9c],ax
.r: ret
.p1: cmp bl,3
    jae .p3
    mov dl,[ACTIVE]         ; 1: LFO 2 delay, 2: LFO 2 fade-in (this voice)
    xor dh,dh
    mov di,dx
    cmp bl,1
    jnz .pf
    mov [di+LFDLY],al
    ret
.pf: mov [di+LFFAD],al
    ret
.p3: cmp bl,5
    jae .p5
    cmp byte [CAPON],0      ; PERF38W: loop window snap / position change the take's loop: not while capturing
    jnz .r
    mov dl,[ACTIVE]         ; 3: loop window snap, 4: loop window position (this voice)
    xor dh,dh
    mov di,dx
    cmp bl,3
    jnz .pw
    mov [di+LWSNAP],al
    ret
.pw: shl di,3
    mov [di+MXB+1],al       ; base of matrix destination 9 (loop window)
    mov byte [di+MXL+1],0xff
    cmp byte [PREADY],0
    jz .r
    mov byte [cs:LASTCC],126
    call L61DB
    call WRITEL
    mov byte [cs:LASTCC],11
    ret
.p5: cmp bl,10
    jae .p10
    jmp PPARAM              ; 5 glide time, 6 glide mode
.p10:
    cmp bl,65
    ja .p66
    cmp byte [PREADY],0     ; 10-65: voice bytes +76h..+ADh (same order as CC10-65)
    jz .r
    call L61S               ; PERF40G: (a rate keeps the direction bit of the voice it goes to)
    mov di,bx
    add di,0x76-10
    cmp di,0x78             ; sustain / end step: 0-7
    jz .ix
    cmp di,0x79
    jz .ix
    cmp di,0x8a
    jz .ix
    cmp di,0x8b
    jz .ix
    cmp di,0x7a             ; envelope rates: keep the direction bit
    jb .wr
    cmp di,0x81
    jbe .rt
    cmp di,0x89             ; envelope levels: x2 (0-254)
    jbe .lv
    cmp di,0x8c
    jb .wr
    cmp di,0x93
    jbe .rt
    cmp di,0x9b
    jbe .lv
    cmp di,0xa6             ; key follow / rate scaling / velocity: signed, 64 = 0
    jb .wr
    sub al,64
    cbw
    shl ax,1
    cmp ax,127
    jle .s1
    mov al,127
.s1: jmp .wr
.ix: cmp al,7
    jbe .wr
    mov al,7
    jmp .wr
.rt: and al,0x7f
    xor al,0x7f             ; same direction as the ADSR controls: 0 fastest, 127 slowest
    jnz .rn
    inc al
.rn: push bx
    mov bx,di
    mov ah,[bx+si]
    pop bx
    and ah,0x80
    or al,ah
    jmp .wr
.lv: shl al,1
.wr: mov [cs:LASTCC],bl
    mov byte [PRAW],1
    call WRITEL
    mov byte [PRAW],0
    mov byte [cs:LASTCC],11
    ret
.p66: cmp bl,86             ; 66-86: FZ effect depths (mod wheel 66-72, foot 73-79, aftertouch 80-86)
    ja .p90
    mov [bx+0x5288-66+3],al
    ret
.pq: jmp PATPAR              ; 87 pattern smoothing
.p90: cmp bl,90             ; 90-99 source, 100-109 amount, 110-119 destination of slots 1-10; 120 clear
    jb .pq
    cmp bl,120
    ja PTOOL                ; PERF40A: 121-127 tools
    jz .clr
    push ax
    mov al,bl
    sub al,90
    xor ah,ah
    mov cl,10
    div cl                  ; al = field, ah = slot
    mov dx,ax
    mov al,[ACTIVE]
    mov cl,10
    mul cl
    add al,dh
    xor ah,ah
    mov di,ax
    pop ax
    cmp dl,1
    jz .am
    shr al,3
    or dl,dl
    jnz .ds
    mov [di+MXS],al
    ret
.am: mov [di+MXA],al
    ret
.ds: mov [di+MXD],al
    cmp al,12               ; LFO 2 rate/depth, FX mix/param: start from their current value
    jb .r
    mov cl,al
    mov bl,[ACTIVE]
    xor bh,bh
    shl bx,1
    mov dx,[bx+MXUSE]
    mov ax,1
    shl ax,cl
    test dx,ax
    jnz .r                  ; already modulated: keep its base
    shl bx,2
    sub cl,8
    add bl,cl
    mov al,[LRATE]
    cmp cl,4
    jz .bs
    mov al,[LDEPTH]
    cmp cl,5
    jz .bs
    mov al,[FXMIX]
    cmp cl,6
    jz .bs
    mov al,[FXRF]
.bs: mov [bx+MXB],al
    ret
.clr: cmp al,64
    jb .r
    mov bl,[ACTIVE]
    xor bh,bh
    jmp MXCLR

LFENVUP:            ; LFO 2: count time since this voice's last new note (for delay / fade-in)
    mov bl,[LREC]
    xor bh,bh
    shl bx,1
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[bx+LFTM3]
    mov [bx+LFTM3],dx
    shr ax,5                ; interrupts (about 3,240 per second)
    add ax,[bx+LFENV]
    jnc .s
    mov ax,0xffff
.s: mov [bx+LFENV],ax
    shr bx,1
    mov al,[bx+LFDLY]
    or al,[bx+LFFAD]
    jz .r
    mov di,0x5420           ; a new note of this voice restarts the delay
    mov cx,8
    xor dl,dl
.y: cmp byte [di],0xff
    jz .yn
    cmp [di+0xa],si
    jnz .yn
    cmp word [di+6],8
    jae .yn
    mov dl,1
.yn: add di,0x3a
    loop .y
    or dl,dl
    jz .yo
    cmp byte [bx+LFYNG],0
    jnz .yo
    shl bx,1
    mov word [bx+LFENV],0
    shr bx,1
.yo: mov [bx+LFYNG],dl
.r: ret

LFGAIN:             ; ax (-127..127) x delay/fade-in gain of record LREC
    push bx
    push cx
    push dx
    mov bl,[LREC]
    xor bh,bh
    mov cl,[bx+LFDLY]
    mov ch,[bx+LFFAD]
    or cx,cx
    jz .x
    push ax
    shl bx,1
    mov bx,[bx+LFENV]       ; t
    mov al,cl
    mul al
    shl ax,1                ; delay = d*d*2 interrupts (127: about 10 s)
    sub bx,ax
    jae .fd
    pop ax
    xor ax,ax
    jmp .x
.fd: mov al,ch
    mul al
    shl ax,1                ; fade = f*f*2
    or ax,ax
    jz .full
    cmp bx,ax
    jae .full
    mov cx,ax
    mov ax,bx
    xor dx,dx
    mov dl,ah               ; t*256/fade
    mov ah,al
    xor al,al
    div cx
    mov cx,ax               ; 0..255
    pop ax
    imul cx
    sar ax,8
    jmp .x
.full: pop ax
.x: pop dx
    pop cx
    pop bx
    ret

LFRSAVE:            ; LFRAW[LREC] = ax
    push bx
    mov bl,[LREC]
    xor bh,bh
    shl bx,1
    mov [bx+LFRAW],ax
    pop bx
    ret

LFXADD:             ; cl (signed) + matrix sum on fast destination dl of record LREC, clamped to -127..127
    push bx
    push ax
    mov bl,[LREC]
    xor bh,bh
    shl bx,3
    add bl,dl
    mov al,[bx+MXF]
    cbw
    mov bx,ax
    mov al,cl
    cbw
    add ax,bx
    call CLAMP
    mov cl,al
    pop ax
    pop bx
    ret

CLAMP:              ; ax -> -127..127
    cmp ax,127
    jle .a
    mov ax,127
    ret
.a: cmp ax,-127
    jge .b
    mov ax,-127
.b: ret

MXLV:               ; record MXR: ax = its LFO 2 output, bl = its destination. CF=1 if idle
    push di
    mov bl,[MXR]
    xor bh,bh
    cmp bl,[ACTIVE]
    jnz .o
    mov ax,[LOUT]
    mov bl,[LDEST]
    jmp .c
.o: call CTXP
    mov ax,[di+0x130+0x52]
    mov bl,[di+0x130+0x4b]
.c: pop di
    cmp ax,0x8000
    jnz .k
    stc
    ret
.k: clc
    ret

MXSRC:              ; al = source -> ax (record MXR, channel MXCH)
    mov bl,[MXCH]
    xor bh,bh
    mov ah,0
    cmp al,1
    jnz .s2
    mov al,[bx+CVEL]
    ret
.s2: cmp al,2
    jnz .s3
    mov al,[bx+CAT]
    ret
.s3: cmp al,3
    jnz .s4
    mov al,[bx+CMW]
    ret
.s4: cmp al,4
    jnz .s5
    mov bl,[MXR]
    shl bx,1
    mov ax,[bx+LFRAW]
    ret
.s5: cmp al,5
    jnz .s6
    mov bl,[MXR]
    shl bx,1
    mov ax,[bx+LFRAW]
    add ax,127
    shr ax,1
    ret
.s6: cmp al,6
    jnz .s7
    mov al,[bx+CRND]
    cbw
    ret
.s7: cmp al,7
    jnz .s8
    mov al,[bx+CNOTE]
    sub al,60
    cbw
    shl ax,1
    jmp CLAMP
.s8: cmp al,8
    jnz .s9
    mov al,[bx+CBEND]
    cbw
    ret
.s9: cmp al,9
    jnz .s10
    mov al,[bx+CM2]
    ret
.s10: cmp al,10
    jnz .s11
    mov al,[bx+CM3]
    ret
.s11: cmp al,11
    jnz .s12
    mov al,[bx+CM4]
    ret
.s12: jmp PATSRC            ; 12 pattern, 13 pattern + (fx5.asm)

MXLFP:              ; dl = fast destination -> cx = LFO 2's part on it (record MXR)
    xor cx,cx
    push ax
    push bx
    call MXLV
    jc .x
    cmp dl,1
    jnz .l3
    cmp bl,1
    jnz .x
    mov cx,ax
    jmp .x
.l3: cmp dl,3
    jnz .l4
    cmp bl,6
    jnz .x
    add ax,127
    shr ax,1
    neg ax
    mov cx,ax
    jmp .x
.l4: cmp dl,4
    jnz .l5
    cmp bl,7
    jnz .x
    mov cx,ax
    jmp .x
.l5: cmp dl,5
    jb .x
    mov bh,dl
    sub bh,2
    cmp bl,bh
    jnz .x
    add ax,127
    shr ax,1
    mov cx,ax
.x: pop bx
    pop ax
    ret

MATRIX:             ; main loop: every record's matrix (about every 1.2 ms)
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[MXTM]
    cmp ax,0x80
    jae .go
    ret
.go: mov [MXTM],dx
    call PATIQ              ; PERF38H: pattern step first
    mov byte [MXSD],0
    push word [CURV]
    mov al,[CURCH]
    push ax
    xor bx,bx
.rl: push bx
    call MXREC
    pop bx
    inc bx
    cmp bx,8
    jb .rl
    pop ax
    mov [CURCH],al
    pop word [CURV]
    ret

MXREC:              ; bx = record
    mov [MXR],bl
    shl bx,1
    mov ax,[bx+RV]
    shr bx,1
    or ax,ax
    jnz .on
    ret
.on: mov al,[bx+RC]
    and al,0x0f
    mov [MXCH],al
    mov ah,0x18
    mul ah
    add ax,0x52a0
    mov [MXBLK],ax
    push es
    push ds
    pop es
    cld
    mov di,MSUM
    xor ax,ax
    mov cx,16
    rep stosw
    pop es
    mov word [MXNU],0
    mov byte [MXLF],0
    mov al,[MXR]
    mov ah,10
    mul ah
    mov [MXI],ax
    mov cx,10
.sl: push cx
    mov di,[MXI]
    mov al,[di+MXS]
    mov dl,[di+MXD]
    and dl,0x0f
    or al,al
    jz .sn
    or dl,dl
    jz .sn
    cmp al,4
    jz .lf
    cmp al,5
    jnz .nl
.lf: mov byte [MXLF],1
.nl: push dx
    call MXSRC              ; ax = source value
    mov di,[MXI]
    mov cx,ax
    mov al,[di+MXA]
    sub al,64
    cbw
    shl ax,1                ; amount -128..126
    imul cx
    sar ax,7
    pop dx
    xor dh,dh
    mov bx,dx
    shl bx,1
    add [bx+MSUM],ax
    mov ax,1
    mov cl,dl
    shl ax,cl
    or [MXNU],ax
.sn: inc word [MXI]
    pop cx
    loop .sl
    mov bl,[MXR]
    xor bh,bh
    mov al,[MXLF]
    mov [bx+MXLU],al
    shl bx,1
    mov ax,[bx+MXUSE]
    or ax,[MXNU]
    mov [MXOLD],ax
    mov ax,[MXNU]
    mov [bx+MXUSE],ax
    cmp word [MXOLD],0      ; nothing routed now or last pass: both destination loops would do nothing
    jnz .w
    jmp PTICK
.w: mov word [MXD0],1       ; fast destinations 1-7: written every pass while used
.fd: mov bx,[MXD0]
    mov ax,1
    mov cl,bl
    shl ax,cl
    test [MXOLD],ax
    jz .fn
    shl bx,1
    mov ax,[bx+MSUM]
    call CLAMP
    mov bl,[MXR]
    xor bh,bh
    shl bx,3
    add bx,[MXD0]
    mov [bx+MXF],al
    mov dl,[MXD0]
    call MXLFP
    add ax,cx
    cmp byte [MXD0],4
    jnz .nb
    mov bl,[MXCH]           ; pitch: the player's bend + LFO 2 + matrix
    xor bh,bh
    push ax
    mov al,[bx+CBEND]
    cbw
    mov cx,ax
    pop ax
    add ax,cx
.nb: call CLAMP
    cmp byte [MXD0],5
    jb .sg
    or ax,ax
    jns .sg
    xor ax,ax               ; LFO depth slots: 0..127
.sg: mov bx,[MXD0]
    mov bl,[cs:bx+FOFF]
    xor bh,bh
    add bx,[MXBLK]
    mov [bx],al
.fn: inc word [MXD0]
    cmp word [MXD0],8
    jb .fd
    call PTICK              ; glide on the pitch-bend byte
.sd: mov bx,[MXD0]          ; slow destinations 8-15: through PERF's own CC code, one per pass, >= 15 ms apart
    mov ax,1
    mov cl,bl
    shl ax,cl
    test [MXOLD],ax
    jz .snx
    shl bx,1
    mov ax,[bx+MSUM]
    mov bl,[MXR]
    xor bh,bh
    shl bx,3
    add bx,[MXD0]           ; (PERF38Z: record x 8 + destination 8..15, tables indexed -8)
    mov dl,[bx+MXB-8]
    xor dh,dh
    add ax,dx
    or ax,ax
    jns .p0
    xor ax,ax
.p0: cmp ax,127
    jle .p1
    mov ax,127
.p1: cmp al,[bx+MXL-8]
    jz .snx
    cmp byte [MXSD],0
    jnz .snx
    mov cx,[0x40a]
    mov dx,cx
    sub cx,[MXST]
    cmp cx,0x20*48
    jb .snx
    mov cl,bl               ; PERF38Z: the destination given the last slot waits one turn (MXFAIR, ZF=1: skip)
    call MXFAIR
    jz .snx
    mov [MXST],dx
    mov byte [MXSD],1
    mov [bx+MXL-8],al
    mov bx,[MXD0]
    mov bl,[cs:bx+SLOWCC-8]
    call SVMAPCC
    mov [cs:LASTCC],bl
    call MXAPPLY
.snx: inc word [MXD0]
    cmp word [MXD0],16
    jb .sd
    ret

MXAPPLY:            ; al = value for CC LASTCC on record MXR, through PERF's normal CC code
    push ax
    mov al,[ACTIVE]
    mov [MXSAV],al
    mov bl,[MXR]
    xor bh,bh
    call RSWITCH
    mov byte [MXQ],1
    pop ax
    cmp byte [PREADY],0
    jz .nr
    call DISPATCH
.nr: mov byte [MXQ],0
    mov bl,[MXSAV]
    xor bh,bh
    jmp RSWITCH

MXOFF:              ; leaving: matrix offsets off, slow destinations back to their base
    call PRESTORE
    xor bx,bx
.l: push bx
    shl bx,1
    mov ax,[bx+MXUSE]
    mov dx,[bx+RV]
    shr bx,1
    or ax,ax
    jz .n
    or dx,dx
    jz .n
    mov [MXR],bl
    mov [MXOLD],ax
    mov al,[bx+RC]
    and al,0x0f
    mov ah,0x18
    mul ah
    add ax,0x52a0
    mov di,ax
    xor al,al
    mov [di],al
    mov [di+0xa],al
    mov [di+0xb],al
    mov [di+0xc],al
    mov [di+0xe],al
    mov [di+0xf],al
    mov [di+0x10],al
    mov word [MXD0],8
.s: mov bx,[MXD0]
    mov ax,1
    mov cl,bl
    shl ax,cl
    test [MXOLD],ax
    jz .sn
    mov bl,[MXR]
    xor bh,bh
    shl bx,3
    add bx,[MXD0]
    sub bx,8
    mov al,[bx+MXB]
    cmp al,[bx+MXL]
    jz .sn
    push ax
    mov bx,[MXD0]
    mov bl,[cs:bx+SLOWCC-8]
    call SVMAPCC
    mov [cs:LASTCC],bl
    pop ax
    call MXAPPLY
.sn: inc word [MXD0]
    cmp word [MXD0],16
    jb .s
.n: pop bx
    inc bx
    cmp bx,8
    jb .l
    ret

EFREST:             ; ESC: FZ effect depths back
    push es
    push ds
    pop es
    cld
    mov si,EFSAVE
    mov di,0x5288
    mov cx,24
    rep movsb
    pop es
    ret

LOOPWIN:            ; al = position 0-127: slide the active loop through the sample, keeping its length
    push ax
    xor bh,bh
    mov bl,[LIDX]
    shl bx,2
    mov ax,[bx+LBUF+0x20]   ; L = end - start
    mov dx,[bx+LBUF+0x22]
    and dx,0x1f
    mov cx,[bx+LBUF+2]
    and cx,0x1f
    sub ax,[bx+LBUF]
    sbb dx,cx
    jc .x
    mov [LWL],ax
    mov [LWL+2],dx
    mov ax,[AEL]            ; whole = end - start of the sample
    mov dx,[AEH]
    sub ax,[GSAVE]
    sbb dx,[GSAVE+2]
    mov cx,ax
    mov di,dx               ; di:cx = whole
    sub ax,[LWL]
    sbb dx,[LWL+2]          ; span = whole - L
    jc .x
    mov [LWS],ax
    mov [LWS+2],dx
    pop ax
    push ax
    mov dl,[ACTIVE]
    push bx
    mov bl,dl
    xor bh,bh
    mov dl,[bx+LWSNAP]
    pop bx
    cmp dl,86
    jae .fr
    ; free / zero-cross: offset = span * p / 127
    push dx
    xor ah,ah
    mov [LWS+2+2],ax        ; (scratch word after LWS: p)
    mov cx,ax
    mov ax,[LWS]
    mul cx                  ; dx:ax = lo * p
    push ax
    push dx
    mov ax,[LWS+2]
    mul cx                  ; ax = hi * p (small)
    pop dx
    add dx,ax               ; dx:(stack) = span*p, < 2^28
    mov ax,dx
    xor dx,dx
    mov cx,127
    div cx                  ; high word of the quotient
    mov di,ax
    pop ax                  ; remainder dx : low word
    div cx
    mov dx,di               ; dx:ax = offset
    pop cx                  ; cl = snap
    add ax,[GSAVE]
    adc dx,[GSAVE+2]
    cmp cl,43
    jb .set
    push ax
    push dx
    call ZCNEAR             ; zero-cross start (within 256 words)
    pop cx                  ; old dx
    pop di                  ; old ax
    ; keep start <= GSAVE + span
    push ax
    push dx
    mov ax,[GSAVE]
    mov dx,[GSAVE+2]
    add ax,[LWS]
    adc dx,[LWS+2]
    mov cx,ax
    mov di,dx               ; di:cx = latest start
    pop dx
    pop ax
    cmp dx,di
    jb .set
    ja .cl
    cmp ax,cx
    jbe .set
.cl: mov ax,cx
    mov dx,di
    jmp .set
.fr: ; whole frames: n = whole / L, index = p * (n-1) / 127, start = GSAVE + index * L
    mov ax,cx               ; di:cx = whole
    mov dx,di
    mov cx,[LWL]
    mov di,[LWL+2]
.sh: or di,di               ; scale both until L fits 15 bits
    jnz .s1
    test cx,0x8000
    jz .dv
.s1: shr di,1
    rcr cx,1
    shr dx,1
    rcr ax,1
    jmp .sh
.dv: or cx,cx
    jz .x
    cmp dx,cx
    jb .d1
    mov ax,0xffff           ; more than 65535 frames
    jmp .d2
.d1: div cx                 ; ax = n
.d2: or ax,ax
    jz .x
    dec ax                  ; n-1
    pop cx
    push cx
    xor ch,ch               ; p
    mul cx                  ; dx:ax = p*(n-1)
    add ax,63
    adc dx,0
    mov cx,127
    div cx                  ; ax = frame index
    mov cx,ax
    mul word [LWL]          ; dx:ax = index * L lo
    push ax
    push dx
    mov ax,[LWL+2]
    mul cx
    pop dx
    add dx,ax
    pop ax                  ; dx:ax = index * L
    add ax,[GSAVE]
    adc dx,[GSAVE+2]
.set: ; start = dx:ax, end = start + L (flag bits kept)
    mov cx,[bx+LBUF+2]
    and cx,0xffe0
    push dx
    and dx,0x1f
    or dx,cx
    mov [bx+LBUF],ax
    mov [bx+LBUF+2],dx
    pop dx
    add ax,[LWL]
    adc dx,[LWL+2]
    mov cx,[bx+LBUF+0x22]
    and cx,0xffe0
    and dx,0x1f
    or dx,cx
    mov [bx+LBUF+0x20],ax
    mov [bx+LBUF+0x22],dx
    pop ax
    jmp SLIDEALL
.x: pop ax
    ret


ENVFIX:             ; bl = 0-3 DCA ADSR, 4-7 DCF ADSR: put sustain/end back on steps 2/3 so the ADSR controls behave
    push di
    lea di,[si+0x78]
    test bl,4
    jz .a
    add di,0x12
.a: mov byte [di],1
    mov byte [di+1],2
    mov byte [di+0x0c],0    ; release (step 3) always fades to silence
    pop di
    ret

