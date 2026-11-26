; ---------- EXT module 3: WAVETABLE (FZED41G; RH6: was 4), disk sector 54, tool. FZED 19 = 24-31 picks it; Render (CC118) runs it.
; Builds a wavetable in the edit voice: FRAMES single cycles of LENGTH words, each a step further along a sweep, then
; sets the voice up to scan it with the loop window (loop 0 = frame 1, Window Snap = WHOLE FRAMES) and sets Stretch to
; match: with 2, 4 or 8 segments every segment starts on a frame and each loop is one frame (Grain = 128 x segments /
; frames - 1, Snap off, crossfade 0; other segment counts become 8). Stretch is switched off (its loops are replaced);
; FZED 9 on rebuilds them on the frames.
;   CC113 TYPE:   0-31 SYNC (a sine hard-synced at 1 to 8 times), 32-63 PWM (pulse 50% down to 4%), 64-95 FOLD (a sine
;                 folded at 1 to 8 times gain), 96-127 MORPH (sine > triangle > saw > square)
;   CC114 FRAMES: 8, 16, 32, 64     CC115 LENGTH (FZED41I: 5 bands of 26): 82, 164, 327, 655, 1309 words a cycle:
;                                   A 440, 220, 110, 55, 27.5 Hz at 36 kHz (original key A4 ... A0: in tune to a few cents;
;                                   the FZ plays 3 octaves either side of it, so 82 covers the whole keyboard)
;   CC116 SWEEP:  how far the last frame goes along the sweep (127 = all the way; 0 = every frame the same)
; An empty edit voice gets new memory, as a preset wave does; a voice with a sample uses its own memory if it holds the
; table (else TOO BIG: start from NEW VOICE). A voice sharing its memory lets go of it first.
; Every frame starts at phase 0 (all start at 0 going up but PWM, which starts high), so the window can move between
; frames at the loop's end without a click of its own; 8 guard words after the last frame continue its cycle.
    dw 0x4036
    db 1, 2                 ; ABI 1, tool
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT WAVETABLE',0
    times 0x20-($-$$) db 0
    clc
    ret
    nop
    jmp near WTRUN          ; +23h
WTTY: db 0                  ; type 0-3
WTNF: dw 0                  ; frames
WTL: dw 0                   ; words a frame
WTB: db 0                   ; sweep 0-127
WTM: dw 0                   ; this frame's place along the sweep, 0-254
WTK: dw 0                   ; frame number
WTI: dw 0                   ; word in the frame
WTPH: dd 0                  ; phase (high word: 0-FFFFh a cycle)
WTIN: dd 0                  ; phase step
WTTOT: dd 0                 ; words in the table, guard words included
WTLT: dw 82,164,327,655,1309
WTKY: db 69,57,45,33,21
S_WTB: db 'TOO BIG',0
S_WTD: db 'TABLE READY',0

WTRUN:              ; si = the edit voice (raw CC values are 0-127)
    mov al,[FXREZ]          ; settings
    shr al,5
    mov [WTTY],al
    mov al,[FXIN]           ; FZED41I: LENGTH in 5 bands of 26 (82 words added)
    aam 26
    mov bl,ah
    mov cl,[FXDF]
    shr cl,5
    mov ax,8
    shl ax,cl
    mov [WTNF],ax
    xor bh,bh
    mov dl,[bx+WTKY]
    mov [WTKEY],dl
    shl bx,1
    mov cx,[bx+WTLT]
    mov [WTL],cx
    mul cx                  ; dx:ax = frames x length
    add ax,8
    adc dx,0
    mov [WTTOT],ax
    mov [WTTOT+2],dx
    mov al,[FXOUT]
    mov [WTB],al
    mov dx,1                ; phase step = 2^32 / L
    xor ax,ax
    div cx                  ; high word: 65536 / L
    mov bx,ax
    xor ax,ax
    div cx                  ; low word: remainder x 65536 / L
    mov [WTIN],ax
    mov [WTIN+2],bx
    call WVSH               ; (as the preset waves) a shared wave is let go first
    mov [WTV],si
    mov byte [WNEW],0
    cmp word [si+0x10],0
    jnz .hv
    push word [WTTOT+2]     ; empty voice: allocate the table, INIT envelopes / filter
    push word [WTTOT]
    push word 0
    push si
    APIC 117,8
    mov si,[WTV]
    or bx,bx
    jnz .big
    mov word [si+0x10],0x1d7
    mov ax,0x007f
    call INIT
    mov byte [WNEW],1
    mov si,[WTV]
.hv: cmp word [0xD7BE],0x4036  ; the FZ calls' stack must not have reached this module
    jnz .big
    mov bx,[si]             ; the stored wave start / end
    mov cx,[si+2]
    and cx,0x1f
    mov [WST],bx
    mov [WST+2],cx
    mov ax,[si+4]
    mov dx,[si+6]
    and dx,0x1f
    sub ax,bx
    sbb dx,cx
    jc .big
    sub ax,[WTTOT]
    sbb dx,[WTTOT+2]
    jnc .ok
.big: mov bx,S_WTB
    jmp NMSG
.ok: xor ax,ax
    mov [WTK],ax
.fr: mov ax,[WTK]           ; frame k: m = k x 2B / (frames - 1)
    mov cx,[WTNF]
    cmp ax,cx
    jae .gd
    mov bl,[WTB]
    xor bh,bh
    shl bx,1
    mul bx
    dec cx
    div cx
    mov [WTM],ax
    call WTFRM
    inc word [WTK]
    jmp .fr
.gd: mov word [WTL],8       ; the 8 guard words after the last frame: its cycle again (WTM is still its place)
    call WTFRM
    mov si,[WTV]            ; the voice: loop 0 = frame 1, sustain / end loop 0, play range = the frames
    xor bx,bx
    mov [si+0x12],bx
    mov [si+0x54],bx
    mov ax,[WST]
    mov cx,[WST+2]
    mov dx,[si+0xa]
    and dx,0xffe0
    or dx,cx
    mov [si+8],ax
    mov [si+0xa],dx
    mov [si+0x14],ax
    mov [si+0x16],cx
    mov bx,[WTL0]
    add ax,bx
    adc cx,0
    mov [si+0x34],ax        ; loop end = start + one frame (no next / jump flags)
    mov [si+0x36],cx
    mov ax,[WTTOT]
    mov dx,[WTTOT+2]
    sub ax,8
    sbb dx,0
    add ax,[WST]
    adc dx,[WST+2]
    mov cx,[si+0xe]
    and cx,0xffe0
    or dx,cx
    mov [si+0xc],ax         ; play end = start + frames x length (Stretch's segments fall on frames)
    mov [si+0xe],dx
    mov word [si+0x64],1022
    mov word [si+0xae],0x155d       ; highest key 93, lowest 21
    mov al,[WTKEY]
    xor ah,ah
    mov [si+0xb0],ax                ; original key, rate 36k
    cmp byte [BKON],0
    jnz .ms
    mov byte [CHPLAY],0     ; RH3: voice mode: after a chop the keys still played the chop's slices: let them go
    call VDIRECT            ; (as VOICE SELECT does), so the keys play the new table
    cmp byte [WNEW],0
    jz .od
    call AFTER
    jmp short .ms
.od: inc byte [RETN]       ; (RETN is 0 here: 1 keeps the sound)
    call PSETUP
    dec byte [RETN]
.ms: mov bl,[ACTIVE]        ; Window Snap: whole frames (this voice)
    xor bh,bh
    mov byte [bx+LWSNAP],127
    and byte [STSU],0x7f    ; Stretch: off (its loops were replaced), set to the frames
    mov al,[STN]            ; segments N = 2 + raw x 14 / 256
    mov ah,14
    mul ah
    mov cl,ah
    add cl,2
    mov al,cl
    dec al
    test al,cl
    jz .sn                  ; 2, 4 or 8 (a power of two)
    mov byte [STN],127
    mov cl,8
.sn: mov ax,128             ; Grain = 128 x N / frames - 1
    mul cl
    xor dx,dx
    div word [WTNF]
    dec ax
    mov [STG],al
    mov byte [STX],0        ; crossfade 0
    mov byte [STZ],0        ; snap off
    mov bx,S_WTD
    jmp NMSG
WTKEY: db 0
WTL0: dw 0

WTFRM:              ; frame WTK, WTL words (the first WTL words of a cycle), at WST + WTK x frame length
    mov ax,[WTL]
    cmp ax,8
    jz .k
    mov [WTL0],ax
.k: xor ax,ax
    mov [WTPH],ax
    mov [WTPH+2],ax
    mov [WTI],ax
.ch: mov cx,[WTL]           ; the next chunk of up to 128 words
    sub cx,[WTI]
    jz .r
    cmp cx,128
    jbe .c
    mov cx,128
.c: push cx
    mov di,LVBUF
.w: push cx
    push di
    mov ax,[WTPH+2]
    call WTVAL
    mov dx,26214            ; 0.8 of full scale
    imul dx
    shl ax,1
    rcl dx,1
    pop di
    mov [di],dx
    add di,2
    mov ax,[WTIN]
    add [WTPH],ax
    mov ax,[WTIN+2]
    adc [WTPH+2],ax
    pop cx
    loop .w
    mov ax,[WTK]            ; address = WST + k x frame length + word
    mul word [WTL0]
    add ax,[WTI]
    adc dx,0
    add ax,[WST]
    adc dx,[WST+2]
    pop cx
    push cx
    call LVWR
    push ds
    pop es
    pop cx
    add [WTI],cx
    jmp .ch
.r: ret

WTVAL:              ; ax = phase -> ax = sample (Q15) of type WTTY at place m = WTM (0-254)
    mov bl,[WTTY]
    mov cx,[WTM]
    or bl,bl
    jnz .t1
    mov bx,cx               ; SYNC: sine at phase x r, r = 1 + 7m / 256 (Q8)
    shl bx,3
    sub bx,cx
    add bx,256
    mul bx
    mov al,ah
    mov ah,dl
    jmp WSIN
.t1: dec bl               ; (1 PWM)
    jnz .t2
    mov bx,cx               ; PWM: high while phase < 8000h - 120m
    shl bx,7
    shl cx,3
    sub bx,cx
    mov cx,0x8000
    sub cx,bx
    cmp ax,cx
    mov ax,32767
    jb .r
    neg ax
.r: ret
.t2: dec bl               ; (2 FOLD)
    jnz .mo
    call WSIN                ; FOLD: sine x (1 + 7m / 256) folded back inside full scale (worked in Q12)
    sar ax,3
    mov bx,cx
    shl bx,3
    sub bx,cx
    add bx,256
    imul bx
    mov al,ah
    mov ah,dl               ; within 8 x 4095
.fl: cmp ax,4095
    jle .f1
    neg ax
    add ax,8190
    jmp .fl
.f1: cmp ax,-4095
    jge .f2
    neg ax
    sub ax,8190
    jmp .fl
.f2: shl ax,3
    ret
.mo: mov bx,cx              ; MORPH: 3m = shape (0 sine, 1 triangle, 2 saw, 3 square) x 256 + the mix to the next
    add bx,cx
    add bx,cx
    push ax
    mov cl,bh
    call WTSH               ; this shape
    pop dx
    push ax
    mov ax,dx
    inc cl
    call WTSH               ; the next
    pop dx
    push dx
    sar ax,1
    sar dx,1
    sub ax,dx               ; (next - this) / 2
    xor bh,bh
    imul bx                 ; x f (0-255)
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl               ; (next - this) x f / 256
    pop dx
    add ax,dx
    ret

WTSH:               ; ax = phase, cl = shape 0-3 -> ax (keeps bx cx)
    cmp cl,1
    jb WSIN
    jz .tr
    cmp cl,2
    jz .r                   ; saw: the phase as a signed number (0 going up, the drop half way)
    cmp ax,0x8000           ; square
    mov ax,32767
    jb .r
    neg ax
.r: ret
.tr: add ax,0x4000          ; triangle (from 0 going up)
    test ax,0x8000
    jz .t1
    not ax
.t1: shl ax,1
    xor ax,0x8000
    ret

WSIN:               ; ax = phase -> ax = sine (Q15), interpolated (as the wave overlay's; keeps si di bp)
    push bx
    push cx
    mov bl,ah
    xor bh,bh
    shl bx,1
    mov cl,al
    call SINR
    add bx,2
    and bx,0x1fe
    push ax
    call SINR
    mov dx,ax
    pop ax
    sub dx,ax
    push ax
    mov al,cl
    xor ah,ah
    imul dx
    mov al,ah
    mov ah,dl
    pop dx
    add ax,dx
    pop cx
    pop bx
    ret

%if ($-$$) > 0x3B8              ; (the FZ calls' stack reaches down to about D7ECh: D7B8h-D7BDh stays clear)
%error EXT module 4 reaches the top of its sector
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4036
    times 0x400-($-$$) db 0x5a
