; ---------- FZED unison overlay (RH7): disk sector 57 (signature 4039h at D400h and D7BEh), loaded into D400h-D7BFh
; through OVCALL. FZED 35 UNISON / 36 DETUNE, and CC97's CHOP message (from CHSET, fx/multi.asm, for room).
; FZ calls run on the stack at DBFEh, which reaches down to about D7ECh: keep the top of the sector empty.
;
; UNISON (FZED 35, RH8: 5 bands of 26: 0-25 OFF, 26-51 DUAL, 52-77 2, 78-103 4, 104-127 8 = MONO; RH7 had 4 bands and
; DUAL whenever a voice was picked): the edit voice and N - 1 copies of it (empty voices,
; sharing its wave memory as COPY VOICE does) as N areas on this MIDI channel in the FZED bank, area i on generators
; i, i + N, ... (8 / N notes at once), and the bank played. UNSYNC (fx/multi.asm, main loop) keeps every copy equal to
; the edit voice, detuned by FZED 36 (0-127 fine steps of 1/256 semitone for the outermost layer: up to about 50
; cents). DUAL: 2 layers, layer 2 the voice picked (Voice Pick, not selected), not a copy (and
; not synced). RH8: every layer's area output level is cut (the ROM takes it off the amp envelope's level) by UNCT
; (RH13: 2 / DUAL 0, 4 16, 8 20) so the stack does not overload the FZ's output. OFF: the areas go, the copies are emptied, back to voice mode. Refused in a bank of your own (BANK ON)
; and while recording; this channel's own area in the FZED bank, if any, is replaced.
    dw 0x4039
UNSET:              ; from STRP (fx/tools40.asm): bl = 15 UNISON, 16 DETUNE; al = the value
    cmp bl,16
    jz .dt
    jmp UNBLD
.dt: mov [UNDT],al          ; the copies' detunes again: UNSYNC adds them from the next pass
    jmp UNDTS

CHMZ:               ; CC97's 'CHOP EVEN' / 'EVEN+ZERO' / 'TRANSIENT' (ZCM 0-2)
    mov al,[ZCM]
    mov ah,16
    mul ah
    add ax,S_ZM
    mov bx,ax
    jmp NMSG

UNBLD:
    mov ah,15
    mul ah
    shl ax,1
    mov al,ah               ; band 0-14 (value x 15 / 128: the Gills' 15 steps)
    cmp al,[UNBD]
    jz .r                   ; (a pot moving within one band)
    push ax
    call UNOFF
    pop ax
    xor ah,ah
    mov si,ax
    mov ah,[si+UNIT]
    mov [UNSM],ah           ; the interval for the upper layers (semitones)
    mov [UNBW],al
    mov bx,UNBT
    xlat                    ; N (DUAL: 82h)
    mov [UNDU],al
    and al,0x7f
    cmp al,2
    jb .r
    mov [UNNW],al
    mov cl,0                ; RH13: 2 / DUAL no cut, 4 16, 8 20 (RH8's 96 / 160 / 208 far too quiet; RH12's 24 / 40
    cmp al,4                ; still lost MONO's power)
    jb .ct
    mov cl,16
    jz .ct
    mov cl,20
.ct: mov [UNCT],cl
    cmp byte [BKON],0
    jnz .bk
    cmp byte [RST],0
    jnz .r
    call L61DB
    cmp word [si+0x10],0
    jnz .ve
    mov bx,S_VE
    jmp NMSG
.bk: mov bx,S_UBK
    jmp NMSG
.ve: mov [UNE],si
    call PBFIND
    jnc .pb
    mov bx,S_NBX
    jmp NMSG
.pb: mov [UNBK],bx
    mov al,[RAWCH]
    mov [UNCH],al
    call UNDEL              ; this channel's areas out of the bank (none of them copies yet: UNN is 1)
    mov cl,[UNNW]           ; generators: pattern 255 / (2^N - 1), shifted by the layer
    mov ax,1
    shl ax,cl
    dec ax
    xchg ax,cx
    mov ax,255
    div cl
    mov [UNPT],al
    mov word [UNSV],0
    xor dx,dx               ; dl = layer
.ly: mov si,[UNE]
    or dl,dl
    jz .ad                  ; layer 0: the edit voice
    cmp dl,1
    jnz .cp
    cmp byte [UNDU],0x82
    jnz .cp
    mov al,[VPICK]          ; DUAL: a voice picked, with sound, not the edit voice
    cmp al,64
    jae .np
    mov ah,0xc0
    mul ah
    add ax,0x2288
    cmp ax,si
    jz .np
    mov di,ax
    cmp word [di+0x10],0
    jz .np
    mov si,di
    mov [UNSV],si
    jmp short .ad
.cp: mov di,0x2288          ; a copy: the first empty voice
    mov cx,64
.f: cmp word [di+0x10],0
    jz .fd
    add di,0xc0
    loop .f
    jmp short .pl           ; no empty voice: fewer layers
.fd: push di
    push ds
    pop es
    cld
    mov cx,0xc0
    rep movsb
    pop si
.ad: mov bx,[UNBK]          ; the area: as CC15's (fx/ov7.asm), on this channel, its generators
    mov di,[bx]
    cmp di,64
    jae .pl
    inc word [bx]
    mov al,[si+0xae]
    mov [bx+di+2],al
    mov al,[si+0xaf]
    mov [bx+di+0x42],al
    mov al,[si+0xb0]        ; keynote centre: the voice's original key, less the interval on the upper layers (DUAL's
    mov cl,dl               ; layer 2; layers N/2 .. N-1): the ROM plays note - centre from the voice's own key
    shl cl,1
    cmp cl,[UNNW]
    jb .ce
    or dl,dl
    jz .ce
    sub al,[UNSM]
.ce: mov [bx+di+0x102],al
    mov byte [bx+di+0x82],0x7f
    mov byte [bx+di+0xc2],0
    mov al,[UNCT]
    mov [bx+di+0x1c2],al    ; RH8: the stack's level cut
    mov al,[UNPT]
    mov cl,dl
    shl al,cl
    mov [bx+di+0x182],al
    mov al,[UNCH]
    mov [bx+di+0x142],al
    shl di,1
    mov [bx+di+0x202],si
    inc dl
    cmp dl,[UNNW]
    jb .ly
.pl: mov [UNN],dl           ; the layers made (1: none, back as it was)
    cmp dl,2
    jb .r
    push dx
    call UNDTS
    mov bx,[UNBK]
    call BKPLAY
    call UNSYNC
    pop dx
    mov al,[UNBW]
    mov [UNBD],al           ; this band is on
    push ds
    pop es
    cld
    mov di,S_UN+7
    mov si,S_UDU
    cmp word [UNSV],0
    jnz .m1
    mov al,dl
    add al,'0'
    stosb
    jmp short .m2
.m1: movsw
    movsw
.m2: mov al,' '
    stosb
    xor bx,bx
    mov bl,[UNBW]
    mov bl,[bx+UNIN]
    lea si,[bx+S_UIN]
    movsw
    movsw
    xor al,al
    stosb
    mov bx,S_UN
.m: jmp NMSG
.np: call UNDEL             ; DUAL with no voice picked: the edit voice's area out again (UNN is 1: no voice emptied); nothing made
    mov bx,S_UNP
    jmp NMSG
.r: ret

UNDTS:              ; each copy's detune into the last word of its name: the k-th copy (k = 1, 2, ...) j x DETUNE /
    cmp byte [UNN],2        ; (N / 2) fine steps, j = (k + 1) / 2, odd k up, even k down (8 layers: +1 -1 +2 -2 +3 -3 +4
    jb .r                   ; quarters of DETUNE; 2: + DETUNE)
    mov dh,[UNN]
    shr dh,1
    mov bx,[UNBK]
    xor di,di
    xor dl,dl
.e: cmp di,[bx]
    jae .r
    mov al,[bx+di+0x142]
    cmp al,[UNCH]
    jnz .n
    push di
    shl di,1
    mov si,[bx+di+0x202]
    pop di
    cmp si,[UNE]
    jz .n
    cmp si,[UNSV]
    jz .n
    inc dl
    mov al,dl
    inc al
    shr al,1                ; j; CF: k even (down)
    sbb ch,ch
    mul byte [UNDT]
    div dh
    cbw
    or ch,ch
    jz .p
    neg ax
.p: mov [si+0xbe],ax
.n: inc di
    jmp .e
.r: ret

UNOFF:              ; the stack (if any) away: its areas out of the bank, its copies emptied, back to voice mode
    cmp byte [UNN],2
    jb .r
    call UNDEL
    mov byte [UNN],1
    mov byte [UNBD],0
    mov word [UNSV],0
    mov byte [BKON],0
    mov al,[DEASV]
    mov [0xdea],al
    call VDIRECT
    xor bx,bx
    call RSWITCH
    mov bx,S_UOF
    jmp NMSG
.r: ret

UNDEL:              ; channel UNCH's areas out of bank UNBK; their voices that are this stack's copies emptied
    mov bx,[UNBK]
    xor di,di
.e: cmp di,[bx]
    jae .r
    mov al,[bx+di+0x142]
    cmp al,[UNCH]
    jz .rm
    inc di
    jmp .e
.rm: push di
    shl di,1
    mov si,[bx+di+0x202]
    pop di
    cmp byte [UNN],2        ; only when a stack is on: then every voice here but these two is one of its copies
    jb .sh
    cmp si,[UNE]
    jz .sh
    cmp si,[UNSV]
    jz .sh
    push di
    push ds
    pop es
    mov di,si
    mov cx,0xc0
    xor al,al
    cld
    rep stosb
    pop di
.sh: mov cx,[bx]            ; the later areas down one
    dec cx
    mov [bx],cx
    push di
.s: cmp di,cx
    jae .sd
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
    jmp .s
.sd: pop di
    jmp .e
.r: ret
; RH9: 15 bands: OFF, DUAL, DUAL SUB / 5TH / MIN7 / MAJ7 / OCT, 2, 4, 4 SUB / 5TH / MIN7 / MAJ7 / OCT, MONO
UNBT: db 1,0x82,0x82,0x82,0x82,0x82,0x82,2,4,4,4,4,4,4,8   ; band -> layers (82h: DUAL)
UNIT: db 0,0,-12,7,10,11,12,0,0,-12,7,10,11,12,0          ; band -> the upper layers' interval, semitones
UNIN: db 0,0,4,8,12,16,20,0,0,4,8,12,16,20,0              ; band -> its name in S_UIN
S_UIN: db '    SUB 5TH MIN7MAJ7OCT '
UNSM: db 0
UNBW: db 0
UNDU: db 0
UNCT: db 0
UNNW: db 0
UNPT: db 0
S_ZM: db 'CHOP EVEN      ',0,'CHOP EVEN+ZERO ',0,'CHOP TRANSIENT ',0
S_UN: db 'UNISON 0       ',0
S_UOF: db 'UNISON OFF',0
S_UBK: db 'UNISON: BANK ON',0
S_UDU: db 'DUAL'
S_UNP: db 'DUAL: NO PICK',0
%if ($-$$) > 0x3A0
%error unison overlay reaches the top of its sector (keep D7A0h-D7BDh clear for the FZ-call stack margin)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4039
    times 0x400-($-$$) db 0x5a
