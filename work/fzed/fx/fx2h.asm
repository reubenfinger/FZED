; ---------- PERF38C: FX mode order, rectifier, decimator, bit mangle, crush range ----------
; CC112 is cut into 14 bands (PERF38F), the effects that run best live first, render-only ones last:
;  0 TapeHack  1 wavefolder  2 rectifier  3 decimator  4 linear crush  5 bit mangle  6 echo / comb  7 position
;  8 ring mod  9 Tube2  10 Karplus-Strong  11 filter  12 Tape>Pockey2  13 Pockey2.
;  FXM keeps the old internal numbers (new ones 9-13).
RCK equ 0xC3EC              ; rectifier: gain on the negative half (Q15, +1 none .. -1 full-wave)
RCDC equ 0xC3EE             ; rectifier: DC trim subtracted
DCN equ 0xC3F0              ; decimator: hold length in words (1-64)
MGM equ 0xC3F2              ; bit mangle: XOR mask
DCTMP equ 0xC3F4            ; decimator, live: the held clean word

FXMOF:              ; al = internal FX mode for CC112 (keeps bx cx dx)
    push bx
    mov al,[FXMODE]
    mov ah,15
    mul ah
    shr ax,7
    mov bx,ax
    mov al,[bx+FXMT]
    xor ah,ah
    pop bx
    ret
FXMT: db 1,5,14,9,10,3,11,12,13,4,7,6,8,2,0   ; PERF38H: 15 bands, 14 = XOVER FUZZ

CRB:                ; crush bits for CC113 value al: 2 + 14 v^2 / 127^2 (most of the travel is 2-9 bits)
    xor ah,ah
    mul al
    mov cx,14
    mul cx
    mov cx,16129
    div cx
    add al,2
    ret

FXBITS:             ; CC113 value al -> bits shown on the LCD (crush: CRB; Pockey2: 4-16)
    push ax
    call FXMOF
    cmp al,3
    pop ax
    jz CRB
    mov ah,13
    mul ah
    shr ax,7
    add al,4
    ret

CRPAR:              ; FXPAR, crush: CMASK / CHALF from the CRB bit count
    cmp byte [FXM],3
    jnz .r
    mov al,[FXREZ]
    call CRB
    mov cl,16
    sub cl,al
    mov ax,0xffff
    shl ax,cl
    mov [CMASK],ax
    xor ax,ax
    or cl,cl
    jz .h
    dec cl
    mov ax,1
    shl ax,cl
.h: mov [CHALF],ax
.r: ret

NXPAR:              ; FXPAR: rectifier (CC115 amount, CC116 DC trim: 127 none), decimator (CC115 hold), mangle (CC115/116)
    mov al,[FXIN]
    xor ah,ah
    mov cx,65534
    mul cx
    mov cx,127
    div cx
    mov bx,32767
    sub bx,ax
    mov [RCK],bx
    mov al,127
    sub al,[FXOUT]
    xor ah,ah
    mov cx,16383
    mul cx
    mov cx,127
    div cx
    mov [RCDC],ax
    mov al,[FXIN]
    xor ah,ah
    mul al
    mov cx,63
    mul cx
    mov cx,16129
    div cx
    inc ax
    mov [DCN],ax
    mov al,[FXIN]
    xor ah,ah
    shl ax,9
    mov bl,[FXOUT]
    xor bh,bh
    shl bx,2
    or ax,bx
    mov [MGM],ax
    ret

MIXW:               ; ax = wet, FXD = dry -> mixed with CC117 (keeps bx cx)
    cmp word [FXW],16384
    jz .r
    push bx
    mov bx,[FXD]
    sub ax,bx
    jo .o
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    xchg ax,dx
    pop bx
.r: ret
.o: call MIXOV
    jmp .j

FXLX:               ; rectifier: negative half x k (k = 1 .. -1), minus the DC trim
.l: mov ax,[es:si]
    mov [FXD],ax
    or ax,ax
    jns .p
    imul word [RCK]
    shl ax,1
    rcl dx,1
    mov ax,dx
.p: sub ax,[RCDC]
    jno .m
    mov ax,0x8000
.m: call MIXW
    mov [es:si],ax
    add si,2
    loop .l
    ret

FXLD:               ; decimator: each word = the first word of its DCN-word block (FXPOS = place in the block)
.l: mov ax,[es:si]
    mov [FXD],ax
    cmp word [FXPOS],0
    jnz .h
    mov [FXHELD],ax
.h: mov ax,[FXHELD]
    inc word [FXPOS]
    mov bx,[FXPOS]
    cmp bx,[DCN]
    jb .n
    mov word [FXPOS],0
.n: call MIXW
    mov [es:si],ax
    add si,2
    loop .l
    ret

FXLB:               ; bit mangle: XOR with the mask
.l: mov ax,[es:si]
    mov [FXD],ax
    xor ax,[MGM]
    call MIXW
    mov [es:si],ax
    add si,2
    loop .l
    ret

DCPREP:             ; live decimator: block place and held clean word for the chunk at clean offset dx:ax
    push dx
    push ax
    mov cx,[DCN]
    mov ax,dx
    xor dx,dx
    div cx
    pop ax
    push ax
    div cx
    mov [FXPOS],dx
    pop ax
    pop bx
    or dx,dx
    jz .r
    sub ax,dx
    sbb bx,0
    mov dx,bx
    add ax,[LVSRC]
    adc dx,[LVSRC+2]
    mov di,DCTMP
    mov cx,1
    call LVRDX
    mov ax,[DCTMP]
    mov [FXHELD],ax
.r: push ds
    pop es
    ret

; ---------- PERF38E: MIDI panic, voice INIT on demand, retain the voice at start ----------
RETN: db 0                  ; 1 while PERF starts on an existing voice: PSETUP keeps its filter / envelopes
VIARM: db 0                 ; voice INIT: 1 = waiting for the value to drop below 64
S_PN: db 'ALL NOTES OFF   ',0
S_VI: db 'VOICE INIT      ',0

PANIC:              ; CC120 / CC123 on channel al: sustain off and a note-off for every key (the FZ's own notes),
    push ax         ; PERF's held-note and glide state cleared
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    and al,0x0f
    mov [cs:PNCH],al
    xor ax,ax
    push ax
    mov al,64
    push ax
    mov al,[cs:PNCH]
    or al,0xb0
    push ax
    push word 0x33
    call L6004
    add sp,8
    xor cx,cx
.k: push cx
    xor ax,ax
    push ax
    push cx
    mov al,[cs:PNCH]
    or al,0x80
    push ax
    push word 0x33
    call L6004
    add sp,8
    pop cx
    inc cx
    cmp cx,128
    jb .k
    push es
    push ds
    pop es
    mov di,PHELD            ; every channel: nothing held, no glide left
    mov cx,16
    xor ax,ax
    cld
    rep stosb
    mov di,PG
    mov cx,16
    rep stosw
    pop es
    mov bx,S_PN
    call NMSG
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PNCH: db 0

VINIT:              ; PERF parameter 7: value >= 120 once per arm (below 64 re-arms): voice INIT
    cmp al,64
    jae .hi
    mov byte [cs:VIARM],0
    ret
.hi: cmp al,120
    jb .r
    cmp byte [cs:VIARM],0
    jnz .r
    mov byte [cs:VIARM],1
    call L61DB
    cmp word [si+0x10],0
    jz .r
    push word VFULL         ; PERF40B: the full init is in the tools overlay
    push word 0x402E
    jmp OVCALL
.r: ret
