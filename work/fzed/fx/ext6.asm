; ---------- EXT module 4: WAVETABLE 2 (RH6), disk sector 55, tool. FZED 19 = 32-39 picks it; Render (CC118) runs it.
; EXT WAVETABLE (module 3) with four other types: everything else (FRAMES, LENGTH, SWEEP, the memory, the voice set up
; for the loop window and Stretch) is the same, and the comments below are WAVETABLE's.
;   CC113 TYPE:   0-31 FEEDBACK FM (a sine modulating itself, from a sine to rasp and chaos), 32-63 CZ RESONANCE (a sine
;                 at 1 to 16 times, restarted every cycle and faded across it), 64-95 BYTEBEAT (logic on the sample
;                 count), 96-127 CHAOS (the logistic map, from periodic to chaotic as the sweep goes)
;   CC114 FRAMES, CC115 LENGTH, CC116 SWEEP as WAVETABLE's. FEEDBACK FM and CHAOS start again at every frame.
    dw 0x4037
    db 1, 2                 ; ABI 1, tool
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT WAVETABLE 2',0
    times 0x20-($-$$) db 0
    clc
    ret
    nop
    jmp near W2RUN          ; +23h
W2TY: db 0                  ; type 0-3
W2NF: dw 0                  ; frames
W2L: dw 0                   ; words a frame
W2B: db 0                   ; sweep 0-127
W2M: dw 0                   ; this frame's place along the sweep, 0-254
W2K: dw 0                   ; frame number
W2I: dw 0                   ; word in the frame
W2PH: dd 0                  ; phase (high word: 0-FFFFh a cycle)
W2IN: dd 0                  ; phase step
W2TOT: dd 0                 ; words in the table, guard words included
W2LT: dw 82,164,327,655,1309
W2KY: db 69,57,45,33,21
S_W2B: db 'TOO BIG',0
S_W2D: db 'TABLE 2 READY',0

W2RUN:              ; si = the edit voice (raw CC values are 0-127)
    mov al,[FXREZ]          ; settings
    shr al,5
    mov [W2TY],al
    mov al,[FXIN]           ; FZED41I: LENGTH in 5 bands of 26 (82 words added)
    aam 26
    mov bl,ah
    mov cl,[FXDF]
    shr cl,5
    mov ax,8
    shl ax,cl
    mov [W2NF],ax
    xor bh,bh
    mov dl,[bx+W2KY]
    mov [W2KEY],dl
    shl bx,1
    mov cx,[bx+W2LT]
    mov [W2L],cx
    mul cx                  ; dx:ax = frames x length
    add ax,8
    adc dx,0
    mov [W2TOT],ax
    mov [W2TOT+2],dx
    mov al,[FXOUT]
    mov [W2B],al
    mov dx,1                ; phase step = 2^32 / L
    xor ax,ax
    div cx                  ; high word: 65536 / L
    mov bx,ax
    xor ax,ax
    div cx                  ; low word: remainder x 65536 / L
    mov [W2IN],ax
    mov [W2IN+2],bx
    call WVSH               ; (as the preset waves) a shared wave is let go first
    mov [WTV],si
    mov byte [WNEW],0
    cmp word [si+0x10],0
    jnz .hv
    push word [W2TOT+2]     ; empty voice: allocate the table, INIT envelopes / filter
    push word [W2TOT]
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
.hv: cmp word [0xD7BE],0x4037  ; the FZ calls' stack must not have reached this module
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
    sub ax,[W2TOT]
    sbb dx,[W2TOT+2]
    jnc .ok
.big: mov bx,S_W2B
    jmp NMSG
.ok: xor ax,ax
    mov [W2K],ax
.fr: mov ax,[W2K]           ; frame k: m = k x 2B / (frames - 1)
    mov cx,[W2NF]
    cmp ax,cx
    jae .gd
    mov bl,[W2B]
    xor bh,bh
    shl bx,1
    mul bx
    dec cx
    div cx
    mov [W2M],ax
    call W2FRM
    inc word [W2K]
    jmp .fr
.gd: mov word [W2L],8       ; the 8 guard words after the last frame: its cycle again (W2M is still its place)
    call W2FRM
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
    mov bx,[W2L0]
    add ax,bx
    adc cx,0
    mov [si+0x34],ax        ; loop end = start + one frame (no next / jump flags)
    mov [si+0x36],cx
    mov ax,[W2TOT]
    mov dx,[W2TOT+2]
    add ax,[WST]            ; RH11: play end = the table's end, its 8 guard words included: a loop ending exactly on
                            ; the play end stopped the note on the FZ (the last frame at Window Position 127)
    adc dx,[WST+2]
    mov cx,[si+0xe]
    and cx,0xffe0
    or dx,cx
    mov [si+0xc],ax         ; play end = start + frames x length + 8 (Stretch's segments within 7 words of a frame)
    mov [si+0xe],dx
    mov word [si+0x64],1022
    mov word [si+0xae],0x155d       ; highest key 93, lowest 21
    mov al,[W2KEY]
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
    div word [W2NF]
    dec ax
    mov [STG],al
    mov byte [STX],0        ; crossfade 0
    mov byte [STZ],0        ; snap off
    mov bx,S_W2D
    jmp NMSG
W2KEY: db 0
W2L0: dw 0

W2FRM:              ; frame W2K, W2L words (the first W2L words of a cycle), at WST + W2K x frame length
    mov ax,[W2L]
    cmp ax,8
    jz .k
    mov [W2L0],ax
.k: xor ax,ax
    mov [W2PH],ax
    mov [W2PH+2],ax
    mov [W2I],ax
.ch: mov cx,[W2L]           ; the next chunk of up to 128 words
    sub cx,[W2I]
    jz .r
    cmp cx,128
    jbe .c
    mov cx,128
.c: push cx
    mov di,LVBUF
.w: push cx
    push di
    mov ax,[W2PH+2]
    call W2VAL
    mov dx,26214            ; 0.8 of full scale
    imul dx
    shl ax,1
    rcl dx,1
    pop di
    mov [di],dx
    add di,2
    mov ax,[W2IN]
    add [W2PH],ax
    mov ax,[W2IN+2]
    adc [W2PH+2],ax
    pop cx
    loop .w
    mov ax,[W2K]            ; address = WST + k x frame length + word
    mul word [W2L0]
    add ax,[W2I]
    adc dx,0
    add ax,[WST]
    adc dx,[WST+2]
    pop cx
    push cx
    call LVWR
    push ds
    pop es
    pop cx
    add [W2I],cx
    jmp .ch
.r: ret

W2VAL:              ; ax = phase -> ax = sample (Q15) of type W2TY at place m = W2M (0-254). RH6: WAVETABLE 2's four
    mov bl,[W2TY]           ; types. A frame starts at phase 0: the feedback and the chaos start again there.
    mov cx,[W2M]
    or ax,ax
    jnz .s
    mov [W2Y],ax
    mov word [W2X],0x8000
.s: or bl,bl
    jnz .t1
    push ax                 ; FEEDBACK FM: sine(phase + y x 100m / 32768): m 0 a sine, 254 about 2.4 radians of
    mov ax,cx               ; feedback (from rasp into chaos)
    mov dx,100
    mul dx
    imul word [W2Y]
    shl ax,1
    rcl dx,1
    pop ax
    add ax,dx
    call W2SIN
    mov [W2Y],ax
    ret
.t1: dec bl
    jnz .t2
    push ax                 ; CZ RESONANCE: a sine at r x phase (r = 1 + 15m / 256: 1 to about 16), restarted every
    mov bx,cx               ; cycle and faded by a ramp falling from full to 0 across it (Casio CZ phase distortion)
    shl bx,4
    sub bx,cx
    add bx,256
    mul bx
    mov al,ah
    mov ah,dl
    call W2SIN
    pop dx
    not dx
    shr dx,1
    imul dx
    shl ax,1
    rcl dx,1
    mov ax,dx
    ret
.t2: dec bl
    jnz .ch
    mov bl,ah               ; BYTEBEAT: t = phase >> 8 (0-255 a cycle): ((t x a) xor ((t x b) >> 2)) and 255,
    mov al,cl               ; a = 1 + m / 16, b = 3 + m / 8
    shr al,4
    inc ax
    mul bl
    push ax
    mov al,cl
    shr al,3
    add al,3
    mul bl
    shr ax,2
    pop dx
    xor ax,dx
    xor ah,ah
    sub ax,128
    shl ax,8
    ret
.ch: mov ax,[W2X]           ; CHAOS: the logistic map x = r x (1 - x), r = 3.5 + m / 512 (3.5 to 4), a step a word
    mov dx,ax
    neg dx
    mul dx
    mov ax,cx
    shr ax,1
    add ax,896
    mul dx
    mov al,ah
    mov ah,dl
    mov [W2X],ax
    sub ax,0x8000
    ret
W2Y: dw 0                   ; FEEDBACK FM: the last sample
W2X: dw 0                   ; CHAOS: x (Q16)

W2SIN:               ; ax = phase -> ax = sine (Q15), interpolated (as the wave overlay's; keeps si di bp)
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
    dw 0x4037
    times 0x400-($-$$) db 0x5a
