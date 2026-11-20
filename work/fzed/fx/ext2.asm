; ---------- EXT module 2: EQ (FZED41C), disk sector 53, render effect. Three-band bass / mid / treble EQ.
; The sample is split by two one-pole low-passes, at about 300 Hz and 3 kHz for a 36 kHz voice (an 18 kHz voice
; halves them, 9 kHz quarters them): low = LP300, mid = LP3k - LP300, high = x - LP3k. With every gain at 64 the
; three bands add back to the original exactly (to the last bit, less the halving below).
;   CC113 = bass, CC114 = mid, CC115 = treble: 0 removes the band, 64 = unchanged, 127 = about +12 dB
;   CC116 = output level, the same scale. Peaks that would pass full scale are held at full scale.
; Worked at half scale (x/2) so no band can overflow; the filters carry 32-bit state. They start from the first
; word rendered and run on through the voice and its slices.
    dw 0x4035
    db 1, 1                 ; ABI 1, render effect
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT EQ',0
    times 0x20-($-$$) db 0
    jmp near EQINIT         ; +20h
    jmp near EQRUN          ; +23h
EQG: dw 0,0,0,0             ; gains bass, mid, treble, output (Q12: 4096 = unchanged)
EQL: dd 0                   ; low-pass at 300 Hz (half scale, Q16)
EQH: dd 0                   ; low-pass at 3 kHz
EQF: db 0                   ; 1 = filters to be started from the next word
EQGAIN:             ; al = 0-127 -> ax: 0 .. 4032 below 64, 4096 + 192 (v - 64) above
    xor ah,ah
    cmp al,64
    jae .u
    shl ax,6
    ret
.u: sub al,64
    mov dl,192
    mul dl
    add ax,4096
    ret
EQINIT:
    mov di,EQG
    mov si,FXREZ
    mov cx,4
.g: lodsb
    and al,0x7f
    call EQGAIN
    mov [di],ax
    inc di
    inc di
    loop .g
    mov byte [EQF],1
    clc
    ret
EQONE:              ; bx = filter state (dd), ax = input (half scale), k in dx -> ax = new output
    push ax
    sub ax,[bx+2]           ; d = x - y (both half scale: no overflow)
    imul dx                 ; dx:ax = d * k (Q15)
    shl ax,1
    rcl dx,1                ; dx:ax = d * k / 2^15 as Q16
    add [bx],ax
    adc [bx+2],dx
    pop ax
    mov ax,[bx+2]
    ret
EQRUN:              ; cx words at es:si
    cmp byte [EQF],0
    jz .l
    mov byte [EQF],0        ; start both filters from this word
    mov ax,[es:si]
    sar ax,1
    xor dx,dx
    mov [EQL],dx
    mov [EQL+2],ax
    mov [EQH],dx
    mov [EQH+2],ax
.l: push cx
    mov ax,[es:si]
    sar ax,1
    push ax                 ; x/2
    mov bx,EQL
    mov dx,1671             ; 1 - e^(-2 pi 300 / 36000), Q15
    call EQONE
    mov di,ax               ; low
    pop ax
    push ax
    mov bx,EQH
    mov dx,13356            ; 1 - e^(-2 pi 3000 / 36000)
    call EQONE
    mov bp,ax               ; LP3k
    pop ax
    sub ax,bp               ; high = x/2 - LP3k
    imul word [EQG+4]
    mov cx,ax
    mov bx,dx               ; bx:cx = high * treble
    mov ax,bp
    sub ax,di               ; mid = LP3k - low
    imul word [EQG+2]
    add cx,ax
    adc bx,dx
    mov ax,di
    imul word [EQG]
    add ax,cx
    adc dx,bx               ; dx:ax = sum, Q12, half scale
    mov cx,11               ; -> full scale: >> 11 (32-bit)
.s: sar dx,1
    rcr ax,1
    loop .s
    call EQSAT              ; ax = 16-bit, held at full scale
    imul word [EQG+6]       ; output level
    mov cx,12
.o: sar dx,1
    rcr ax,1
    loop .o
    call EQSAT
    mov [es:si],ax
    add si,2
    pop cx
    loop .l
    ret
EQSAT:              ; dx:ax signed 32-bit -> ax held to -32768 .. 32767
    push bx
    mov bx,ax
    sar bx,15               ; the sign ax would need in dx
    cmp bx,dx
    jz .k                   ; fits
    mov ax,0x7fff
    or dx,dx
    jns .k
    mov ax,0x8000
.k: pop bx
    ret

%if ($-$$) > 0x3A0
%error EXT module 2 reaches the top of its sector
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4035
    times 0x400-($-$$) db 0x5a
