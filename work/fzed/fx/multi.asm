; ---------- banks / multi-voice: CCs routed by MIDI channel, per-voice records, PERF bank builder ----------
BKON equ 0x83C2
CCCH equ 0x83C3
CURV equ 0x83C4
CURCH equ 0x83C6
ACTIVE equ 0x83C7
ADDV equ 0x83C8
BKARM equ 0x83C9
DEASV equ 0x83CA
MRK equ 0x83CB
BKBANK equ 0x83CC
RV equ 0x83CE
RC equ 0x83DE
RA equ 0x83E6
BKTMP equ 0x83EE
LVVOI equ 0x83F0
LVG0 equ 0x83F2
CTX equ 0xC400
CTXSZ equ 0x198
LFOTMP equ 0xD0C0
MINIT:              ; startup: record 0 = the FZ's edit voice, voice mode
    xor ax,ax
    mov [BKON],al
    mov [ACTIVE],al
    mov byte [BKARM],1      ; disarmed until CC15 sits in the middle
    mov byte [ADDV],1      ; CC16 must first be below 64 before NEW VOICE can fire
    mov word [BKBANK],0
    mov [CURV],ax
    mov di,RV
    mov cx,8
.z: mov [di],ax
    add di,2
    loop .z
    mov al,[0xdea]
    mov [DEASV],al
    mov al,[0xdeb]
    and al,0x0f
    mov [CURCH],al
    mov [RC],al
    call L61DB
    mov [RV],si
    mov [CURV],si
    ret
CTXP:               ; bx = record index -> di = its context block
    push ax
    push dx
    mov ax,CTXSZ
    mul bx
    add ax,CTX
    mov di,ax
    pop dx
    pop ax
    ret
CTXSAVE:            ; save PERF's per-voice variables of record bx
    push si
    push es
    push ds
    pop es
    cld
    call CTXP
    mov si,0x8020
    mov cx,0x130
    rep movsb
    mov si,0x8158
    mov cx,0x64
    rep movsb
    mov al,[PREADY]
    stosb
    pop es
    pop si
    ret
CTXLOAD:            ; load record bx's per-voice variables
    push si
    push es
    push ds
    pop es
    cld
    call CTXP
    mov si,di
    mov di,0x8020
    mov cx,0x130
    rep movsb
    mov di,0x8158
    mov cx,0x64
    rep movsb
    lodsb
    mov [PREADY],al
    pop es
    pop si
    ret
RSWITCH:            ; make record bx the active one (voice CURV, channel CURCH)
    mov al,[ACTIVE]
    cmp al,bl
    jz .cv
    push bx
    mov bl,al
    xor bh,bh
    call CTXSAVE
    pop bx
    call CTXLOAD
    mov [ACTIVE],bl
.cv: push bx
    xor bh,bh
    shl bx,1
    mov ax,[bx+RV]
    mov [CURV],ax
    pop bx
    xor bh,bh
    mov al,[bx+RC]
    mov [CURCH],al
    ret
MROUTE:             ; after a CC is parsed (al = value): bank CCs 14-16; in bank mode switch to the channel's voice. CF=1 = consumed
    mov bl,[cs:LASTCC]
    cmp bl,14
    jnz .m15
    jmp BKSEL
.m15: cmp bl,15
    jnz .m16
    jmp BKADD
.m16: cmp bl,16
    jnz .m0
    jmp BKVOI
.m0: cmp byte [BKON],0
    jnz .bk
    clc
    ret
.bk: push ax
    call BKFIND             ; si = voice on this channel, bl = area
    jc .none
    mov dl,bl
    xor bx,bx               ; its record (find, or take a free one)
.f: shl bx,1
    cmp [bx+RV],si
    jz .got
    shr bx,1
    inc bx
    cmp bx,8
    jb .f
    xor bx,bx
.fr: shl bx,1
    cmp word [bx+RV],0
    jz .new
    shr bx,1
    inc bx
    cmp bx,8
    jb .fr
    mov bx,S_TM
    jmp .msg
.new: mov [bx+RV],si
    shr bx,1
    push dx
    push si
    call CTXP               ; fresh record: everything zero, LFO 2 idle
    push es
    push ds
    pop es
    cld
    xor ax,ax
    mov cx,CTXSZ
    rep stosb
    pop es
    call CTXP
    mov word [di+0x130+0x52],0x8000 ; LOUT (81AAh)
    call MXCLR              ; no matrix slots, no LFO 2 delay
    pop si
    pop dx
    jmp .set
.got: shr bx,1
.set: mov [bx+RA],dl
    mov al,[CCCH]
    mov [bx+RC],al
    call RSWITCH
    cmp byte [PREADY],0     ; first CC for this voice: set it up as PERF does at start
    jnz .ok
    call L61DB
    cmp word [si+0x10],0
    jz .ok
    call PSETUP
.ok: pop ax
    clc
    ret
.none: mov al,[CCCH]
    inc al
    mov di,S_NV+11
    call DEC2
    mov bx,S_NV
.msg: call NMSG
    pop ax
    stc
    ret
BKFIND:             ; playing bank: first area on MIDI channel CCCH -> si = voice, bl = area. CF=1 none
    mov bx,[0xdfe]
    cmp bx,0xe08
    jb .no
    mov cx,[bx]
    cmp cx,64
    ja .no
    xor di,di
.l: cmp di,cx
    jae .no
    mov al,[bx+di+0x142]
    cmp al,[CCCH]
    jz .y
    inc di
    jmp .l
.y: push di
    shl di,1
    mov si,[bx+di+0x202]
    pop di
    mov bx,di
    or si,si
    jz .no
    clc
    ret
.no: stc
    ret
BKPLAY:             ; play bank bx, areas on their own MIDI channels
    cli
    mov [0xdfe],bx
    mov word [0xe00],0
    mov ax,bx
    sub ax,0xe08
    xor dx,dx
    mov cx,0x290
    div cx
    mov [0xdfc],ax
    sti
    mov byte [0xdea],0xff
    mov [BKBANK],bx
    mov byte [BKON],1
    mov byte [CHPLAY],0
    jmp STAT2               ; PERF40H: line 2 shows the bank
BKBACK:             ; CC98 < 64: back to the bank in bank mode, else the voice itself
    cmp byte [BKON],0
    jnz .b
    jmp VDIRECT
.b: mov bx,[BKBANK]
    jmp BKPLAY
BKSEL:              ; CC14: 0-14 voice mode, then banks 1-8 (bands of about 14)
    mov ah,9
    mul ah
    shr ax,7
    or al,al
    jnz .b
    cmp byte [BKON],0
    jz .vm
    mov byte [BKON],0
    mov al,[DEASV]
    mov [0xdea],al
    call VDIRECT
    xor bx,bx               ; back to the FZ's edit voice (record 0)
    call RSWITCH
.vm: call STAT2            ; PERF40H: line 2 shows the voice
    stc
    ret
.b: dec al
    mov ah,0
    mov bx,ax
    mov ax,0x290
    mul bx
    add ax,0xe08
    mov bx,ax
    mov [BKBANK],bx
    cmp word [bx],0
    jnz .p
    mov al,bl               ; (bank index again for the message)
    sub bx,0xe08
    mov ax,bx
    xor dx,dx
    mov cx,0x290
    div cx
    inc al
    add al,'0'
    mov [S_BE+5],al
    mov bx,S_BE
    call NMSG
    stc
    ret
.p: call BKPLAY
    stc
    ret
BKVOI:              ; CC16: NEW VOICE rising edge
    jmp NEWVOICE
PBFIND:             ; bx = selected target, existing FZED bank, or new bank. CF=1 none
    mov bx,[BKBANK]
    or bx,bx
    jz .find
    cmp word [bx],0
    jz .name
    jmp .y
.find:
    mov bx,0xe08
    mov cx,8
.f: cmp word [bx+0x282],'FZ'
    jnz .n
    cmp word [bx+0x284],'ED'
    jnz .n
    cmp word [bx+0x286],' B'
    jz .y
.n: add bx,0x290
    loop .f
    mov bx,0xe08
    mov cx,8
.e: cmp word [bx],0
    jz .mk
    add bx,0x290
    loop .e
    stc
    ret
.mk:
.name:
    lea di,[bx+0x282]
    push es
    push ds
    pop es
    cld
    mov si,S_PB
    mov cx,12
.c: mov al,[cs:si]
    stosb
    inc si
    loop .c
    pop es
.y: mov [BKBANK],bx
    clc
    ret
BKADD:              ; CC15 0-31: put voice CC16 in the PERF bank on this MIDI channel; 32-95: re-arm; 96-127: clear
    cmp al,32               ; this channel. Once per arm; nothing until the pot has been in the middle after start.
    jb .hi
    cmp al,96
    jae .hi
    mov byte [BKARM],0
    stc
    ret
.hi: cmp byte [BKARM],0
    jz .go
    stc
    ret
.go: mov byte [BKARM],1
    mov [BKTMP],al
    call PBFIND
    jnc .pb
    mov bx,S_NBX
    call NMSG
    stc
    ret
.pb: mov al,[RAWCH]          ; area for this channel already?
    mov cx,[bx]
    xor di,di
.s: cmp di,cx
    jae .ns
    cmp [bx+di+0x142],al
    jz .fs
    inc di
    jmp .s
.ns: mov di,0xffff
.fs: cmp byte [BKTMP],96
    jae .clr
    push bx
    call L61DB
    pop bx
    cmp word [si+0x10],0
    jnz .ve
    mov bx,S_VE
    call NMSG
    stc
    ret
.ve: cmp di,0xffff
    jnz .put
    mov di,[bx]
    cmp di,64
    jb .ap
    stc
    ret
.ap: inc word [bx]
.put: mov al,[si+0xae]
    mov [bx+di+2],al
    mov al,[si+0xaf]
    mov [bx+di+0x42],al
    mov al,[si+0xb0]
    mov [bx+di+0x102],al
    mov byte [bx+di+0x82],0x7f
    mov byte [bx+di+0xc2],0
    mov byte [bx+di+0x1c2],0
    mov byte [bx+di+0x182],0xff
    mov al,[RAWCH]
    mov [bx+di+0x142],al
    push di
    shl di,1
    mov [bx+di+0x202],si
    pop di
    mov bx,S_CVX
    call NMSG
    stc
    ret
.clr: cmp di,0xffff         ; remove this channel's area: shift the later ones down
    jz .cm
    mov cx,[bx]
    dec cx
    mov [bx],cx
.sh: cmp di,cx
    jae .cm
    push bx
    mov si,8
    lea bp,[bx+2]
.t: mov al,[ds:bp+di+1]
    mov [ds:bp+di],al
    add bp,0x40
    dec si
    jnz .t
    pop bx
    push di
    shl di,1
    mov ax,[bx+di+0x204]
    mov [bx+di+0x202],ax
    pop di
    inc di
    jmp .sh
.cm: mov al,[RAWCH]
    inc al
    mov di,S_CC+2
    call DEC2
    mov bx,S_CC
    call NMSG
    stc
    ret
BKKEY:              ; bank mode: CC66 highest, CC67 lowest, CC68 original key of this voice's area (3 octaves, as for voices)
    mov bx,[0xdfe]
    cmp bx,0xe08
    jb .r
    push bx
    xor bh,bh
    mov bl,[ACTIVE]
    mov cl,[bx+RA]
    pop bx
    xor ch,ch
    add bx,cx               ; bx = bank + area
.set: and al,0x7f
    cmp dl,66
    jnz .k1
    mov [bx+2],al
    jmp .cl
.k1: cmp dl,67
    jnz .k2
    mov [bx+0x42],al
    jmp .cl
.k2: mov [bx+0x102],al
.cl: mov al,[bx+0x102]
    mov ah,[bx+2]
    cmp ah,al
    jae .h1
    mov ah,al
.h1: mov cl,al
    add cl,36
    jnc .h0
    mov cl,127
.h0: cmp cl,127
    jbe .h2
    mov cl,127
.h2: cmp ah,cl
    jbe .h3
    mov ah,cl
.h3: mov [bx+2],ah
    mov ah,[bx+0x42]
    cmp ah,al
    jbe .l1
    mov ah,al
.l1: mov cl,al
    sub cl,36
    jnc .l2
    xor cl,cl
.l2: cmp ah,cl
    jae .l3
    mov ah,cl
.l3: mov [bx+0x42],ah
.r: ret
LFOALL:             ; LFO 2 for every voice record that has a destination (bank mode), else just the active voice
    push word [CURV]
    mov al,[CURCH]
    push ax
    xor bx,bx
.l: shl bx,1
    mov ax,[bx+RV]
    shr bx,1
    or ax,ax
    jz .n
    cmp bl,[ACTIVE]
    jnz .ot
    push bx
    mov [CURV],ax
    mov al,[bx+RC]
    mov [CURCH],al
    mov [LREC],bl
    call LFO2
    pop bx
    jmp .n
.ot: cmp byte [BKON],0
    jz .n
    call CTXP
    cmp byte [di+0x130+0x4b],0  ; its LDEST (81A3h)
    jnz .run
    cmp byte [bx+MXLU],0        ; or LFO 2 feeds its matrix
    jz .n
.run: push bx
    mov [LREC],bl
    mov [CURV],ax
    mov al,[bx+RC]
    mov [CURCH],al
    mov [BKTMP],di
    push es
    push ds
    pop es
    cld
    mov si,0x81a0           ; active LFO -> LFOTMP, this one's -> live
    mov di,LFOTMP
    mov cx,0x1c
    rep movsb
    mov si,[BKTMP]
    add si,0x130+0x48
    mov di,0x81a0
    mov cx,0x1c
    rep movsb
    mov si,LFOTMP+0x0e      ; MIDI clock timing is shared
    mov di,0x81ae
    mov cx,6
    rep movsb
    pop es
    call LFO2
    push es
    push ds
    pop es
    cld
    mov di,[BKTMP]
    add di,0x130+0x48
    mov si,0x81a0
    mov cx,0x1c
    rep movsb
    mov si,LFOTMP
    mov di,0x81a0
    mov cx,0x1c
    rep movsb
    pop es
    pop bx
.n: inc bx
    cmp bx,8
    jb .l
    pop ax
    mov [CURCH],al
    pop word [CURV]
    ret
MRESTORE:           ; ESC / ENTER: the other touched voices back too (al = 0 ENTER, 1 ESC)
    mov [MRK],al
    xor bh,bh
    mov bl,[ACTIVE]
    call CTXSAVE
    xor bx,bx
.l: shl bx,1
    mov ax,[bx+RV]
    shr bx,1
    or ax,ax
    jz .n
    cmp bl,[ACTIVE]
    jz .n
    push bx
    call CTXLOAD
    push bx
    shl bx,1
    mov ax,[bx+RV]
    mov [CURV],ax
    pop bx
    mov al,[bx+RC]
    mov [CURCH],al
    call LFOOFF
    cmp byte [PREADY],0
    jz .nx
    cmp byte [MRK],0        ; PERF40J: ENTER with KEEP ALL: bank voices keep their loops, start / end, play mode too
    jnz .do
    cmp byte [KEEPA],2
    jz .nx
.do: call L61DB
    push es
    push ds
    pop es
    cld
    push si
    lea di,[si+0x14]
    mov si,BUF
    mov cx,0x40             ; ENTER: loops back
    cmp byte [MRK],0
    jz .c
    mov cx,0x9e             ; ESC: all sound settings back
.c: rep movsb
    pop si
    pop es
    cmp byte [MRK],0
    jz .k
    mov ax,[LSV]
    mov [si+0x12],ax
.k: mov ax,[ORIG]
    mov [si+0x10],ax
    mov cx,4
    xor bx,bx
.g: mov ax,[bx+GSAVE]
    mov [si+bx+8],ax
    add bx,2
    loop .g
.nx: pop bx
.n: inc bx
    cmp bx,8
    jb .l
    xor bh,bh
    mov bl,[ACTIVE]
    call CTXLOAD
    call RSWITCH
    cmp byte [BKON],0
    jz .r
    mov al,[DEASV]
    mov [0xdea],al
.r: ret
S_BE: db 'BANK 0 EMPTY',0
S_NARM: db 'NOT ARMED',0     ; PERF40N: (moved from the low code for room)
S_NEVF: db 'NO EMPTY VOICE',0
S_CVX: db 'VOICE ADDED',0
S_CC: db 'CH00 CLEARED',0
S_NV: db 'NO VOICE CH00',0
S_TM: db 'TOO MANY VOICES',0
S_NBX: db 'NO FREE BANK',0
S_VE: db 'VOICE EMPTY',0
S_RS: db 'REC: VOICE MODE',0
S_PB: db 'FZED BANK   '
LVRUNW:             ; live FX stays on its own voice whichever voice the CCs are editing
    cmp byte [LVON],0
    jz .r
    push word [CURV]
    mov ax,[LVVOI]
    mov [CURV],ax
    call LVRUN
    pop word [CURV]
.r: ret
S_EMP: db 'EMPTY       '           ; PERF40H (line 2 / line 7 texts, kept here for room)
S_BL: db '                ',0
S_MOS: db 'ONE-SHOT',0      ; FZED: loop / play mode names
S_MOG: db 'ORIGINAL',0
