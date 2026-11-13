; ---------- PERF38H: pattern source, XOVER FUZZ curve, 3-tap reflections, curve built in steps, LCD pacing ----------
; RAM: D0DCh-D0FFh (free after LFOTMP) and D2D0h-D2DFh. LVBUF moved to D2F0h-D3EFh so B800h-B8FFh holds code.
; Code is spread over the free space: fx5a.asm (6000h-7FFFh), fx5b.asm (main, after the matrix), fx5.asm (B800h-BDFFh),
; fx5x.asm (DC00h section).
PATN equ 0xD0DC             ; pattern 0-15 (PERF parameter 8 / 8)
PATR equ 0xD0DD             ; rate (parameter 9): 0-63 free-running, 64-127 MIDI clock divisions
PATS equ 0xD0DE             ; smoothing (parameter 87)
PSTEP equ 0xD0DF            ; step 0-15
PV equ 0xD0E0               ; output level 0-127, smoothed
PRTG equ 0xD0E1             ; 1 = restart at step 0 (a note from silence, free-running only)
PACC equ 0xD0E2             ; word: timer units into this step
PLAST equ 0xD0E4            ; word: timer at the last pass
PCNT equ 0xD0E6             ; word: MIDI clocks mod 768 (FA start -> FFFFh, so the first clock is 0)
LCDP equ 0xD0E8             ; word: FX value message waiting for the LCD
LCDE equ 0xD0EA             ; 1 = the CC echo line is waiting
GAPF equ 0xD0EB             ; 1 = CC112 selects XOVER FUZZ (run as TapeHack, FXM 1, with its own curve)
LCDT equ 0xD0EC             ; word: timer at the last paced LCD write
CBK equ 0xD0EE              ; word: next entry of the curve being built in steps (FFFFh = none)
CGIN equ 0xD0F0             ; word: FXGIN for the curve being built
CGOUT equ 0xD0F2            ; word: FXGOUT
TGSN equ 0xD0F4             ; word: Tube2 gain scaling that goes with the curve being built
GAPT equ 0xD0F6             ; word: xover threshold
GAPM equ 0xD0F8             ; word: 32767 - threshold
CKEY equ 0xD0FA             ; THT holds the curve for: mode (+16 xover), CC115, CC116
CVAL equ 0xD0FD             ; 1 = CKEY is valid
RSHC equ 0xD0FF             ; PERF38K: ring table built for this shape (80h + 40h square), 0 = none
GAPC equ 0xD0FE             ; CC116 for the xover curve being built
CBKEY equ 0xD2D0            ; key of the curve being built
SVMOFF equ 0xD2D3           ; PERF38I: 1 = the filter map was cleared on leaving the filter
PGTM equ 0xD2D4              ; word: timer at the last glide step
PGINT equ 0x1200            ; glide step every 0x1200 timer units (about 45 ms, the old idle-loop pace)
CSH equ 0xD400              ; curve being built (513 words, D400h-D801h; KSB is idle in the curve modes)
LCDINT equ 0x1800           ; at most one paced LCD write per 0x1800 timer units (about 60 ms)
GAPA equ 26000              ; fuzz level
FMBUF equ 0xD3F0            ; PERF38I: FX name line (16 bytes, after LVBUF)

; ---- pattern: a 16-step level sequence read by the matrix as source 12 (level - 127: 0 on full steps, down to -127
; on empty ones; route it to LEVEL or CUTOFF with a positive amount) and source 13 (level 0..127).
PATIQ:              ; MATRIX pass (about every 1.2 ms): once for all records, then the ROM queue scan as before
    call PATTICK
    jmp IQSCAN
PATTICK:
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[PGTM]
    cmp ax,PGINT
    jb .g0
    mov [PGTM],dx
    call GLDEC              ; PERF38I: glide steps here, once per channel
.g0: mov al,[PATR]
    cmp al,64
    jb .free
    sub al,64               ; clock: step = clocks / division, 16 steps
    shr al,3
    mov bl,al
    xor bh,bh
    mov cl,[cs:bx+PSYN]
    mov ax,[PCNT]
    cmp ax,768
    jb .c
    xor ax,ax
.c: div cl
    and al,15
    mov [PSTEP],al
    mov ax,[0x40a]
    mov [PLAST],ax
    jmp short .lvl
.free: mov ax,[0x40a]
    cmp byte [PRTG],0
    jz .nr
    mov byte [PRTG],0
    mov byte [PSTEP],0
    mov word [PACC],0
    mov [PLAST],ax
.nr: mov dx,ax
    sub ax,[PLAST]
    mov [PLAST],dx
    push ax
    mov al,[PATR]           ; step = 1200 + 16 r^2 timer units (12 ms .. 0.62 s)
    mul al
    shl ax,4
    add ax,1200
    mov bx,ax
    pop ax
    add ax,[PACC]
    jnc .a
    sub ax,bx               ; PERF38I: carried past 16 bits: take the step now, keep the rest
    jmp short .sp
.a: mov [PACC],ax
.st: mov ax,[PACC]
    cmp ax,bx
    jb .lvl
    sub ax,bx
.sp: mov [PACC],ax
    inc byte [PSTEP]
    and byte [PSTEP],15
    jmp .st
.lvl: mov cl,[PSTEP]
    mov bl,[PATN]
    and bx,15
    cmp bl,14
    jb .msk
    mov al,cl               ; 14 ramp up, 15 ramp down
    jz .up
    xor al,15
.up: shl al,3
    or al,7
    jmp short .sm
.msk: shl bx,2
    mov ax,[cs:bx+PTAB]
    mov dx,[cs:bx+PTAB+2]
    shr ax,cl
    shr dx,cl
    test al,1
    mov al,0
    jz .sm
    mov al,80
    test dl,1
    jz .sm
    mov al,127
.sm: mov cl,[PATS]          ; at most 128 >> (smooth / 16) per pass
    shr cl,4
    mov dl,128
    shr dl,cl
    sub al,[PV]
    jz .r
    jns .p
    neg al
    cmp al,dl
    jbe .n
    mov al,dl
.n: sub [PV],al
    ret
.p: cmp al,dl
    jbe .q
    mov al,dl
.q: add [PV],al
.r: ret
LVRUNX:             ; main loop: paced LCD, a step of a curve being built, then live FX as before
    call LCDCHK
    cmp byte [LVON],2
    jz .on
    mov word [CBK],0xffff   ; live not running: a curve in steps is dropped (KSB may be used)
    jmp LVRUNW
.on: cmp word [CBK],0xffff
    jz .w
    call CBSTEP
.w:
%ifdef LVMEASURE
    call LVRUNW
    jmp LVMEAS
%else
    jmp LVRUNW
%endif

LVLEAD:             ; FZED: from LVRUN, the chase cursor is 512 words ahead of the playhead: put it back on the
    mov al,[LVPHS]          ; playhead's chunk for the next chase, and give this pass to the sweep
    mov [LVCSG],al
    mov ax,[LVPHO]
    and ax,0xff80
    mov [LVCPOS],ax
    mov ax,[LVPHO+2]
    mov [LVCPOS+2],ax
    jmp LVRUN.sw

%ifdef LVMEASURE
; ---- measurement build only (build with LVMEASURE=1 sh build.sh): words of live processing per second on line 3,
; 'LV nnnnnn W/S'. Counts LVNN (words done by the pass's last LVCHK) while live runs or bypasses; one second =
; 103680 units of the ROM timer word 040Ah (32 per interrupt at the measured 3240 interrupts per second).
LVMEAS:
    mov al,[LVON]
    cmp al,2
    jb .t
    cmp al,3
    ja .t
    mov ax,[LVNN]
    mov word [LVNN],0
    add [cs:.w],ax
    adc word [cs:.w+2],0
.t: mov ax,[0x40a]
    mov dx,ax
    sub ax,[cs:.last]
    mov [cs:.last],dx
    add [cs:.el],ax
    adc word [cs:.el+2],0
    cmp word [cs:.el+2],1
    jb .r
    ja .p
    cmp word [cs:.el],0x9500
    jb .r
.p: sub word [cs:.el],0x9500
    sbb word [cs:.el+2],1
    mov ax,[cs:.w]
    mov dx,[cs:.w+2]
    mov word [cs:.w],0
    mov word [cs:.w+2],0
    mov di,.s+8
    mov cx,6
    call DECN
    mov bx,.s
    jmp NMSG
.r: ret
.w: dw 0,0
.el: dw 0,0
.last: dw 0
.s: db 'LV 000000 W/S',0
%endif

; ---- curve tables: one entry function for every curve mode, full builds (render, mode change) and builds in steps
FXMOFP:             ; FXPAR: internal mode; XOVER FUZZ (14) runs as TapeHack with GAPF = 1
    call FXMOF
    mov byte [GAPF],0
    cmp al,14
    jnz .r
    mov byte [GAPF],1
    mov al,1
.r: ret

CKNOW:              ; al ah dl = key of the curve the settings ask for; +32 = Tube2's live curve (LVON = 2)
    mov al,[GAPF]
    shl al,4
    or al,[FXM]
    cmp al,7
    jnz .k
    cmp byte [LVON],2
    jnz .k
    or al,0x20
.k: mov ah,[FXIN]
    mov dl,[FXOUT]
    ret

CINIT:              ; snapshot what the entries use
    mov ax,[FXGIN]
    mov [CGIN],ax
    mov ax,[FXGOUT]
    mov [CGOUT],ax
    cmp byte [FXM],7
    jnz .ng
    jmp TUINIT
.ng: cmp byte [GAPF],0
    jz .r
    mov al,[FXIN]           ; threshold = 2 v^2
    mul al
    shl ax,1
    mov [GAPT],ax
    neg ax
    add ax,32767
    mov [GAPM],ax
    mov al,[FXOUT]
    mov [GAPC],al
.r: ret

CENT:               ; cx = entry k -> ax
    cmp byte [FXM],7
    jnz .n7
    call TUENT
    cmp byte [LVON],2       ; live (render turns live off first): the slew stage at zero slew is built in
    jnz .r7
    jmp TUBAKE
.r7: ret
.n7: cmp byte [GAPF],0
    jz .t2
    jmp GAPENT
.t2: jmp THENT
CBLD:               ; entries cx .. bp-1 into [di]
.l: cmp cx,bp
    jae .r
    push cx
    push di
    push bp
    call CENT
    pop bp
    pop di
    pop cx
    mov [di],ax
    add di,2
    inc cx
    jmp .l
.r: ret

THBUILD:            ; full curve now (render, live start, mode change): THT[0..513], key recorded
    call CINIT
    mov di,THT
    xor cx,cx
    mov bp,513
    call CBLD
    mov ax,[di-2]
    mov [di],ax
    mov ax,[TGSN]
    mov [TGS],ax
    call CKNOW
    mov [CKEY],ax
    mov [CKEY+2],dl
    mov byte [CVAL],1
    mov word [CBK],0xffff
    ret

CURVEQ:             ; live, a curve mode, after FXPAR: rebuild only when CC112/115/116 changed it
    call CKNOW
    cmp byte [CVAL],0
    jz THBUILD
    cmp al,[CKEY]
    jnz THBUILD             ; another curve mode: at once
    cmp ah,[CKEY+1]
    jnz .ch
    cmp dl,[CKEY+2]
    jnz .ch
    mov word [CBK],0xffff   ; back to the curve already in THT
    ret
.ch: cmp word [CBK],0xffff
    jnz .r                  ; one is being built: it is checked again when it is done
    mov [CBKEY],ax
    mov [CBKEY+2],dl
    call CINIT
    mov word [CBK],0
.r: ret

CBSTEP:             ; one step: 32 entries into CSH; after the last, THT takes them all at once
    call CKNOW
    cmp al,[CBKEY]
    jz .go
    mov word [CBK],0xffff
    ret
.go: mov cx,[CBK]
    mov bp,cx
    add bp,32
    cmp bp,513
    jbe .b
    mov bp,513
.b: mov di,cx
    shl di,1
    add di,CSH
    push bp
    call CBLD
    pop bp
    mov [CBK],bp
    cmp bp,513
    jb .r
    push es
    push ds
    pop es
    cld
    mov si,CSH
    mov di,THT
    mov cx,513
    rep movsw
    mov ax,[di-2]
    stosw
    pop es
    mov ax,[TGSN]
    mov [TGS],ax
    mov ax,[CBKEY]
    mov [CKEY],ax
    mov al,[CBKEY+2]
    mov [CKEY+2],al
    mov word [CBK],0xffff
    jmp CURVEQ              ; settings moved on meanwhile: start the next one
.r: ret

; ---- Tube2 live: no slew stage. The live curve (CKNOW +32) holds the static curve with FXLU's slew stage at zero
; slew, its clamp and x1.923 built in, so a live word is one lookup (and the mix). Render keeps FXLU.
TUBAKE:             ; ax = static curve value -> live curve value (FXLU with slew = 0, TGSN for the curve being built)
    mov di,ax
    mov cx,ax
    or cx,cx
    jns .a
    neg cx
.a: imul cx
    shl ax,1
    rcl dx,1
    mov ax,dx               ; (t * 16384) << 2 >> 16 = t: the zero-slew factor needs no multiply
    imul word [TGSN]
    shl ax,1
    rcl dx,1
    sub di,dx
    cmp di,17039            ; clamp +/-0.52, then x 1.923
    jle .c1
    mov di,17039
.c1: cmp di,-17039
    jge .c2
    mov di,-17039
.c2: mov ax,di
    mov bx,2521
    imul bx
    not dx
    neg ax
    sbb dx,-1
    add dx,di
    shl ax,1
    rcl dx,1
    mov ax,dx
    ret
FXLV7:              ; Tube2, fully wet (LPW): live = the live curve only; render = FXLU
    cmp byte [LVON],2
    jz .l
    jmp FXLU
.l: mov bx,[es:si]
    xor bx,0x8000
    mov dx,bx
    and dx,127
    shr bx,6
    and bx,0xfffe
    mov ax,[bx+THT+2]
    sub ax,[bx+THT]
    imul dx
    shl ax,1                ; (dx:ax >> 7), low word
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    mov [es:si],ax
    add si,2
    loop .l
    ret
FXLV7M:             ; Tube2 with dry/wet mix (LPM): live = the live curve, then the mix as FXLU; render = FXLU
    cmp byte [LVON],2
    jz .l
    jmp FXLU
.l: mov bx,[es:si]
    xor bx,0x8000
    mov dx,bx
    and dx,127
    shr bx,6
    and bx,0xfffe
    mov ax,[bx+THT+2]
    sub ax,[bx+THT]
    imul dx
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    mov bx,[es:si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov [es:si],dx
    add si,2
    loop .l
    ret
.of: call MIXOV
    jmp .j
