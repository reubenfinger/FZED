; ---------- EXT module 5: ADDITIVE (RH4), disk sector 56, tool. FZED 19 = 40-47 picks it; Render (CC118) runs it.
; Builds FRAMES single cycles of 327 words (A2, 110 Hz at 36 kHz) from up to 96 harmonics. The table itself (memory,
; loops, keys, Window Snap FRAMES GLIDE, Stretch set to the frames) is made by EXT WAVETABLE (module 4: this module
; loads it with SYNC / no sweep / 327 words / the frames, and it loads this one back when it is done), then every frame
; is written again here. Each harmonic's level is worked out in log2 units (Q8: 256 = 6 dB), made linear, the levels
; scaled to sum to full scale (so the sum never clips) and every frame finally scaled to the same peak (30000).
;   CC113 SHAPE:      4 bands: SINE, SAW, SQUARE, PANEL (the FZ's own SIN SYNTHESIS levels, 48 bytes at 04DCh:
;                     harmonics 1-48). (A triangle's spectrum is SQUARE at brightness 32.)
;   CC114 BRIGHTNESS: 64 as the shape; lower tilts down to -12 dB / octave more, higher up to +12 dB / octave
;   CC115 ODD / EVEN: 64 both; lower takes the even harmonics down (0: none), higher the odd ones from 3 up (127: none)
;   CC116 FORMANT:    0 off; 1-127 a peak (+24 dB) from harmonic 1 to 96 (log spaced)
;   FZED 30 WIDTH:    the peak's half width, 1/16 to 2 octaves
;   FZED 31 COMB:     16 bands: off, then keep only harmonics h with (h - 1) mod N = k: N,k = 2,0 2,1 3,0 3,1 ...
;                     9,0 (N = 2 + (band - 1) / 2, k = (band - 1) & 1)
;   FZED 32 FRAMES:   8, 16, 32, 64 (as WAVETABLE's)
;   FZED 33 SWEEP:    64 none; across the frames the formant moves by up to 64 places and brightness by up to 32,
;                     down (lower) or up (higher)
; Every frame starts at phase 0 (all sines rising); the 8 guard words after the last frame are WAVETABLE's sine.
    dw 0x4038
    db 1, 2                 ; ABI 1, tool
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT ADDITIVE',0
    times 0x20-($-$$) db 0
    clc
    ret
    nop
    jmp near ADRUN          ; +23h
ADLEN equ 327               ; words a frame
ADLV equ LVBUF+0x40         ; 96 harmonic levels (words): log2 Q8, then linear (LVBUF+0-3Fh: 32 words being made)
ADNEG equ 0x8000            ; a harmonic that is off
ADSH: db 0                  ; shape 0-3
ADPS: db 0                  ; ADFRM's pass: 0 make, 1 scale
ADNF: dw 0                  ; frames
ADK: dw 0                   ; frame number
ADM: dw 0                   ; this frame's place along the sweep, 0-255
ADCNT: dw 0                 ; words in this frame (ADLEN, or the 8 guard words)
ADJ: dw 0                   ; words done in this pass
ADN: dw 0                   ; the word being made
ADDN: dw 0                  ; its phase step a harmonic
ADPH: dw 0
ADPK: dw 0                  ; the frame's peak
ADBE: dw 0                  ; this frame's brightness and formant place
ADPE: dw 0
ADMX: dw 0                  ; the loudest level
S_ADD: db 'ADDITIVE 00',0   ; the frame being written (RH5), then ADDITIVE OK

ADRUN:              ; si = the edit voice: WAVETABLE makes the table first, then ADPT2 (the controls kept on the stack)
    push word [FXREZ]
    push word [FXIN]
    push word [si+0xb0]
    mov byte [si+0xb0],0xff ; WAVETABLE puts the original key (45) here when it has made the table
    mov ch,[ADP+2]
    and ch,0xe0
    mov cl,0
    mov [FXREZ],cx          ; SYNC (a sine), the frames
    mov word [FXIN],52      ; 327 words, no sweep
    push word ADPT2
    push word 0x4038        ; WAVETABLE's return: OVCALL brings this module back at ADPT2
    push word OVCALL
    push word 0xD423
    push word 0x4037
    jmp OVCALL

ADPT2:              ; WAVETABLE done (or refused, with its message)
    mov si,[WTV]
    pop ax
    pop word [FXIN]
    pop word [FXREZ]
    cmp byte [si+0xb0],45
    jz .ok
    mov [si+0xb0],ax        ; refused: the voice's key as it was
    ret
.ok: mov cl,[ADP+2]        ; frames 8, 16, 32, 64
    shr cl,5
    mov ax,8
    shl ax,cl
    mov [ADNF],ax
    mov al,[FXREZ]
    shr al,5
    mov [ADSH],al
    xor ax,ax
    mov [ADK],ax
.fr: mov ax,[ADK]           ; frame k: m = k x 255 / (frames - 1)
    mov cx,[ADNF]
    cmp ax,cx
    jae .gd
    dec cx
    mov bx,255
    mul bx
    div cx
    mov [ADM],ax
    mov ax,[ADK]            ; RH5: progress, on the FZ and (STATUS OUT) the Gills: the main loop does not run meanwhile
    inc ax
    mov di,S_ADD+9
    call DEC2
    mov bx,S_ADD
    call NMSG
    call STSTAT
    call ADSPEC
    mov word [ADPK],1
    mov word [ADCNT],ADLEN
    call ADFRM
    inc word [ADK]
    jmp .fr
.gd: mov word [S_ADD+9],'OK'
    mov bx,S_ADD
    jmp NMSG

ADADD:              ; ax + bl -> 0-127
    xor bh,bh
    add ax,bx
    jns .p
    xor ax,ax
.p: cmp ax,127
    jbe .r
    mov ax,127
.r: ret

ADSPEC:             ; the levels of frame ADK (place ADM) into ADLV: linear, summing to 32767 at most
    mov al,[ADP+3]          ; sweep s = -64..63: brightness + s x m / 256, formant + s x m / 128
    sub al,64
    cbw
    imul word [ADM]
    push ax
    sar ax,8
    mov bl,[FXDF]
    call ADADD
    mov [ADBE],ax
    pop ax
    sar ax,7
    mov bl,[FXOUT]
    or bl,bl
    jnz .p1
    xor ax,ax               ; formant off (and off where the sweep takes it to 0)
    jmp short .pf
.p1: call ADADD
.pf: mov [ADPE],ax
    mov word [ADMX],ADNEG
    mov si,ADLV
    mov cx,1
.h: call ADLEV
    mov [si],ax
    cmp ax,[ADMX]
    jle .nm
    mov [ADMX],ax
.nm: inc si
    inc si
    inc cx
    cmp cx,96
    jbe .h
    xor bx,bx               ; linear, relative to the loudest; their sum (di:bx)
    xor di,di
    mov si,ADLV
    mov cx,96
.l: lodsw
    cmp ax,ADNEG
    jz .z
    sub ax,[ADMX]
    call ADEXP
    jmp short .s
.z: xor ax,ax
.s: mov [si-2],ax
    add bx,ax
    adc di,0
    loop .l
    xor cx,cx               ; scale to sum to 32767 at most: level' = (level >> k) x 32767 / (sum >> k)
.k: or di,di
    jnz .k1
    test bh,0x80
    jz .k2
.k1: shr di,1
    rcr bx,1
    inc cx
    jmp .k
.k2: or bx,bx
    jnz .k3
    inc bx
.k3: mov si,ADLV
    mov di,96
.n: mov ax,[si]
    shr ax,cl
    mov dx,32767
    mul dx
    div bx
    mov [si],ax
    inc si
    inc si
    dec di
    jnz .n
    ret

ADLEV:              ; cx = harmonic h -> ax = its level, log2 Q8 (ADNEG: off); keeps cx, si
    mov bx,cx
    call ADLOG
    mov di,ax               ; di = log2 h
    neg ax                  ; -log2 h: 1/h
    mov dl,[ADSH]
    dec dl
    jz .b                   ; 1 SAW
    js .si                  ; 0 SINE
    dec dl
    jz .sq                  ; 2 SQUARE
    cmp cx,48               ; 3 PANEL: the FZ's own 48 levels (04DCh)
    ja .off
    mov bx,cx
    mov bl,[bx+0x4DC-1]
    xor bh,bh
    or bx,bx
    jz .off
    call ADLOG
    jmp short .b
.si: cmp cx,1               ; the fundamental only (its -log2 1 is 0; 1 is odd: on through .sq)
    jnz .off
.sq: test cl,1              ; odd harmonics only
    jz .off
.b: push ax                 ; brightness: + (b - 64) / 32 x log2 h
    mov ax,di
    shr ax,2
    mov dx,[ADBE]
    sub dx,64
    imul dx
    sar ax,3
    pop dx
    add ax,dx
    mov dl,[FXIN]           ; odd / even: -(distance from 64) / 8 octaves of level, the far end off
    sub dl,64
    jz .f
    jl .ev
    test cl,1               ; above 64: the odd ones from 3
    jz .f
    cmp cx,1
    jz .f
    cmp dl,63
    jz .off
    jmp short .dc
.ev: test cl,1              ; below 64: the even ones
    jnz .f
    cmp dl,-64
    jz .off
    neg dl
.dc: xor dh,dh
    shl dx,5
    sub ax,dx
.f: mov bx,[ADPE]           ; formant at 2^(p x 6.5 / 127): + 4 x (1 - distance / half width) octaves of level
    or bx,bx
    jz .c
    push ax
    mov ax,13
    mul bx
    sub ax,di
    jns .d
    neg ax
.d: mov bl,[ADP]            ; half width 16 + 4 x width
    xor bh,bh
    shl bx,2
    add bx,16
    sub ax,bx
    jge .fo                 ; outside the peak
    neg ax
    mov dx,1024
    mul dx
    div bx
    pop dx
    add ax,dx
    jmp short .c
.fo: pop ax
.c: mov bl,[ADP+1]          ; comb: keep h if (h - 1) mod N = k
    shr bl,3
    jz .r
    dec bl                  ; N = 2 + (band - 1) / 2, k = (band - 1) & 1
    mov dl,bl
    and dl,1
    shr bl,1
    add bl,2
    push ax
    mov ax,cx
    dec ax
    div bl
    cmp ah,dl
    pop ax
    jnz .off
.r: ret
.off: mov ax,ADNEG
    ret

ADLOG:              ; bx = 1-255 -> ax = log2 bx (Q8, linear between powers of two); keeps bx, cx
    push cx
    xor ax,ax
    mov dx,bx
.l: shr dx,1
    jz .f
    inc ah
    jmp .l
.f: mov cl,ah
    mov dx,bx
    shl dx,8
    shr dx,cl
    add ax,dx
    sub ax,256
    pop cx
    ret

ADEXP:              ; ax = level, log2 Q8, 0 or below -> ax = linear Q15 (0 below -12 octaves of level); keeps cx
    push cx
    cmp ax,-3072
    jl .z
    neg ax
    mov cl,ah
    xor ah,ah
    shr ax,1
    neg ax
    add ax,255
    shl ax,7
    shr ax,cl
    jmp short .x
.z: xor ax,ax
.x: pop cx
    ret

ADFRM:              ; ADCNT words of frame ADK at WST + k x 327: made, then again scaled x 30000 / the peak
.p: xor ax,ax                ; (ADPS is 0 here: it toggles back after the second pass)
    mov [ADJ],ax
.ch: mov cx,[ADCNT]         ; the next chunk of up to 32 words
    sub cx,[ADJ]
    jz .np
    cmp cx,32
    jbe .c
    mov cx,32
.c: push cx
    cmp byte [ADPS],0
    jnz .rd
    mov ax,[ADJ]
    mov [ADN],ax
    mov di,LVBUF
.w: push cx
    push di
    call ADSMP
    pop di
    mov [di],ax
    inc di
    inc di
    cwd                     ; the peak
    xor ax,dx
    sub ax,dx
    cmp ax,[ADPK]
    jbe .k
    mov [ADPK],ax
.k: pop cx
    loop .w
    jmp short .wr
.rd: call ADADR
    call LVRD
    pop cx
    push cx
    mov si,LVBUF
.s: mov ax,[si]
    mov bx,30000
    imul bx
    idiv word [ADPK]
    mov [si],ax
    inc si
    inc si
    loop .s
.wr: call ADADR
    pop cx
    push cx
    call LVWR
    push ds
    pop es
    pop cx
    add [ADJ],cx
    jmp .ch
.np: xor byte [ADPS],1
    jnz .p
    ret

ADADR:              ; dx:ax = WST + k x 327 + j (keeps cx)
    push cx
    mov ax,ADLEN
    mul word [ADK]
    add ax,[ADJ]
    adc dx,0
    add ax,[WST]
    adc dx,[WST+2]
    pop cx
    ret

ADSMP:              ; ax = word ADN (ADN + 1 after): the harmonics' sines, level-weighted, summed
    push bp
    mov dx,[ADN]
    inc word [ADN]
    xor ax,ax
    mov bx,ADLEN
    div bx                  ; phase step a harmonic: n x 65536 / 327
    mov [ADDN],ax
    xor ax,ax
    mov [ADPH],ax
    xor di,di
    xor bp,bp
    mov si,ADLV
    mov cx,96
.h: mov ax,[ADPH]
    add ax,[ADDN]
    mov [ADPH],ax
    mov bx,[si]
    inc si
    inc si
    or bx,bx
    jz .nx
    push bx
    mov bl,ah               ; sine of the phase's top byte (SINR: from the quarter-wave SINQ)
    xor bh,bh
    shl bx,1
    call SINR
    pop bx
    imul bx
    add di,ax
    adc bp,dx
.nx: loop .h
    shl di,1
    rcl bp,1
    mov ax,bp
    pop bp
    ret
%if ($-$$) > 0x3B8              ; (the FZ calls' stack reaches down to about D7ECh: D7B8h-D7BDh stays clear)
%error EXT module 5 reaches the top of its sector
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4038
    times 0x400-($-$$) db 0x5a
