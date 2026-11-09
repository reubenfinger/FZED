; ---------- PERF40A tools (resident): overlay loader, choke, slice keys, copy voice, shared-wave guards
CHOKV equ 0x83F6            ; chop places' output byte: FFh = all outputs (slices overlap), 01h = output 1 (choke)
SLSEL equ 0x83F7            ; chop slice chosen with parameter 122 (0-based)
CPARM equ 0x83F8            ; bit 0: copy voice disarmed until parameter 126 goes below 64; bit 7 (PERF40G): slices keep
                            ; their own filter / envelopes / LFO 1 (per-slice mode)
VPICK equ 0x8004            ; PERF40H: voice picked (slot 0-63, FFh none) for VOICE SELECT
EXITR equ 0x8005            ; PERF40H: exit asked for from Gills: 1 = as ESC, 2 = as ENTER
L7F  equ 0x8006             ; PERF40H: 'EMPTY-REC READY' is on line 7
KEEPA equ 0x8007            ; PERF40I: ENTER keeps 0 the sound, 1 all of the edit voice, 2 all (bank voices too, PERF40J)
CHTO equ 0x8008             ; PERF40J: 1 = chops go into the target bank (CHOP INTO TARGET)
CHBASE equ 0x8009           ; PERF40J: word, places before this chop's slices in its bank
STMV equ 0x801D             ; PERF40M: 1 = STRETCH LEAD-IN CUT moved the voice's start to the first loop
STRS equ 0x801E             ; PERF40M: word + STRSH: the start STRETCH works from while it has moved the voice's start
STRSH equ 0x800F
CHMOD equ 0x800B            ; PERF40J: 1 = this chop is in a target bank (not its own CHOP bank)
STSEL equ 0x83F9            ; PERF40F STRETCH: control chosen with parameter 88
STN  equ 0x83FA             ; raw 0-127: segments, stretch (loop time), grain, crossfade, snap, sustain (+ on flag bit 7)
STT  equ 0x83FB
STG  equ 0x83FC
STX  equ 0x83FD
STZ  equ 0x83FE
STSU equ 0x83FF

OVCALL:             ; [sp] = 4000h + disk sector of the overlay, [sp+2] = routine in it, [sp+4] = caller. The overlay is
    push bp                 ; loaded into D400h unless both its signatures (D400h, D7BEh) are there already.
    mov bp,sp
    push ax
    mov ax,[bp+2]
    cmp [0xd400],ax
    jnz .ld
    cmp [0xd7be],ax
    jz .go
.ld: cmp byte [CAPON],0      ; the capture overlay is in D400h: never replace it
    jnz .no
    pusha
    call LVOFF              ; live FX keep their buffers in D400h: released first (as CHOP does)
    push word 0
    push word 0xd400
    mov ax,[bp+2]
    xor ah,ah
    push ax
    APIC 0xbf,6
    popa
    mov ax,[bp+2]
    cmp [0xd400],ax
    jnz .no
    cmp [0xd7be],ax
    jz .go
.no: pop ax
    pop bp
    add sp,4
    mov bx,S_OVD
    call NMSG
    stc
    ret
.go: pop ax
    pop bp
    add sp,2
    ret
MKBNDO: push word MKBND
    push word 0x402E
    jmp OVCALL

SHARED:             ; ZF=1 if another voice plays from the same wave memory as voice si (FZ COPY VOICE, or ours)
    push ax
    push cx
    push di
    mov di,0x2288
    mov cx,64
.l: cmp di,si
    jz .n
    cmp word [di+0x10],0
    jz .n
    mov ax,[di]
    cmp ax,[si]
    jnz .n
    mov ax,[di+2]
    xor ax,[si+2]
    and ax,0x1f
    jz .y
.n: add di,0xc0
    loop .l
    or sp,sp
.y: pop di
    pop cx
    pop ax
    ret

PTOOL:              ; parameters 121-127 (CC10 chooses, CC11 sets): 121 output of every slice, 122 slice, 123 move
    cmp bl,121              ; slice, 124 slice lowest key, 125 slice highest key, 126 copy voice, 127 slice output
    jnz .s
    call OUTB               ; 121 OUTPUT: OFF = all outputs (slices overlap), 1-8 = that mono out only (each slice
    mov [CHOKV],ah          ; cuts off the last one on the same out); the next chop uses it too
    xor bx,bx
    cmp [CHBANK],bx
    jz .cm
    call ADDCB              ; (PERF40J: this chop's places)
    push cx
    mov cl,[CHCNT]
    xor ch,ch
    jcxz .c2
.cl: mov [bx+0x182],ah
    inc bx
    loop .cl
.c2: pop cx
.cm: mov bx,S_OUT
    jmp OUTM
.s: cmp bl,126
    jnz .k0
    push word COPYV         ; PERF40F: copy voice is in tools overlay 2 (sector 47)
    push word 0x402F
    jmp OVCALL
.k0: push word SLTOOL        ; 122-125, 127: slice keys and output, in the tools overlay
    push word 0x402E
    jmp OVCALL
.r: ret

STRP:               ; PERF40F parameters 88 (STRETCH control 0-9) and 89 (its value, in tools overlay 2)
    cmp bl,88
    jnz .s9
    and al,31
    mov [STSEL],al
    ret
.s9: cmp bl,89
    jnz .r
    cmp byte [STSEL],11     ; PERF40H: 11 voice pick, 12 voice select, 13 exit: tools overlay 3
    jb .s
    cmp byte [STSEL],16     ; PERF40L: 16-18 (next, order, skew) are STRETCH too
    jb .v
.s: push word STRETCH       ; (PERF40L: tools overlay 4)
    push word 0x4031
    jmp OVCALL
.v: push word VTOOL
    push word 0x4030
    jmp OVCALL
.r: ret

OUTB:               ; al = 0-127 -> ah = output byte (FFh all, else bit n-1 for out n), cl = 0 (OFF) or 1-8
    mov ah,9
    mul ah
    shl ax,1
    mov cl,ah               ; 0-8
    xor ch,ch
    mov ah,0xff
    jcxz .r
    push cx
    dec cx
    mov ah,1
    shl ah,cl
    pop cx
.r: ret
OUTM:               ; bx = message 'xxxxxxOFF' / output number at +7 ('OUTPUT 3'), cl = 0-8
    jcxz .m
    mov al,cl
    add al,'0'
    mov [bx+7],al
    mov word [bx+8],'  '
    jmp NMSG
.m: mov word [bx+7],'OF'
    mov byte [bx+9],'F'
.m2: jmp NMSG
WVSH:               ; preset wave: si = edit voice. If it shares its wave memory, it lets go of it (WDEL) so the
    call L61DB              ; wave goes into new memory and the other voice keeps its sound
    cmp word [si+0x10],0
    jz .r
    call SHARED
    jnz .r
    call WDEL
.r: ret

PSW:                ; PERF40G WRITEL: in per-slice mode, a filter / envelope / LFO 1 control (CC or parameter 10-56,
    push bx                 ; CC73-75, CC78-85) is written to the chop slice chosen with SLICE, not the source voice
    test byte [CPARM],0x80
    jz .n
    mov bl,[CHCNT]
    mov bh,[cs:LASTCC]
    cmp bh,10
    jb .n
    cmp bh,56
    jbe .y
    cmp bh,73
    jb .n
    cmp bh,75
    jbe .y
    cmp bh,78
    jb .n
    cmp bh,85
    ja .n
.y: cmp bl,[SLSEL]
    jbe .n                  ; (no chop, or the slice isn't there)
    mov bl,[SLSEL]
    xor bh,bh
    shl bx,1
    mov bx,[bx+CHV]
    push word [CURV]
    mov [CURV],bx
    call WRITEL0
    pop word [CURV]
    pop bx
    ret
.n: pop bx
    jmp WRITEL0
L61S:               ; PERF40G: L61DB, but the chosen chop slice in per-slice mode (LFO 1 delay)
    call L61DB
    test byte [CPARM],0x80
    jz .r
    push bx
    mov bl,[SLSEL]
    cmp bl,[CHCNT]
    jae .p
    xor bh,bh
    shl bx,1
    mov si,[bx+CHV]
.p: pop bx
.r: ret
CHPMV:              ; PERF40G CHPROP: copy 54h-ADh, or in per-slice mode 54h-75h and A5h-ADh only
    test byte [CPARM],0x80
    jnz .sp
    mov cx,0xae-0x54
    jmp MOVB
.sp: mov cx,0x76-0x54
    call MOVB
    add si,0xa5-0x76
    add di,0xa5-0x76
    mov cx,0xae-0xa5
    jmp MOVB

CHBSELO: push word CHBSEL   ; PERF40J: choose the chop's bank (tools overlay 3)
    push word 0x4030
    jmp OVCALL
ADDCB: add bx,[CHBANK]      ; PERF40J: bx = slice + this chop's bank + its first place
    add bx,[CHBASE]
    ret
CHCHAN: mov al,[RAWCH]      ; PERF40J: slices' MIDI channel: Gills' (target bank) or the FZ's (own CHOP bank)
    cmp byte [CHMOD],0
    jnz .r
    mov al,[0xdeb]
    and al,0x0f
.r: ret
CHNMD: mov di,[CHBANK]      ; PERF40J: where the CHOP name's 'Vnn' goes; for a target bank, spare bytes (800Ch-800Eh)
    cmp byte [CHMOD],0
    jz .r
    mov di,0x800C-0x287
.r: ret
NORMO: push word NORMCC     ; PERF40H: normalise is in tools overlay 3
    push word 0x4030
    jmp OVCALL
L7CHK:              ; PERF40H: line 7 'EMPTY-REC READY' cleared once the edit voice has sound
    cmp byte [L7F],0
    jz .r
    pusha
    call L61DB
    cmp word [si+0x10],0
    jz .p
    mov byte [L7F],0
    mov bx,S_BL
    xor cx,cx
    mov dx,7
    call PRT
.p: popa
.r: ret
STAT2:              ; PERF40H: line 2 = 'V05 TST A' (voice mode: the edit voice) or 'B2  FZED BANK' (bank mode)
    call L7CHK
    cmp byte [BKON],0
    jz .v
    mov bx,[0xdfe]
    mov word [S_L2],'B0'
    mov al,[0xdfc]
    add [S_L2+1],al
    inc byte [S_L2+1]
    mov word [S_L2+2],'  '
    lea si,[bx+0x282]
    jmp VLINE.nm
.v: call L61DB
    mov al,'V'
VLINE:              ; si = voice, al = first character: 'V05 name' on line 2 ('V05 EMPTY' for an empty voice)
    mov [S_L2],al
    mov ax,si
    sub ax,0x2288
    mov cl,0xc0
    div cl
    inc ax
    mov di,S_L2+1
    call DEC2
    mov byte [S_L2+3],' '
    cmp word [si+0x10],0
    jz .e
    add si,0xb2
    jmp .nm
.e: mov si,S_EMP
.nm: mov di,S_L2+4
    mov cx,12
.c: mov al,[si]
    cmp al,' '
    jb .b
    cmp al,'~'
    jbe .k
.b: mov al,' '
.k: mov [di],al
    inc si
    inc di
    loop .c
    mov bx,S_L2
    xor cx,cx
    mov dx,2
    jmp PRT
NOTE3:              ; PERF40H: al = key -> 3 characters at [di]: 'C_2', 'C#2' (36 = C2, as Casio); octave -1 'C-1' / 'C#-'
    xor ah,ah
    mov bl,12
    div bl
    mov bl,ah
    xor bh,bh
    shl bx,1
    mov bx,[cs:bx+NOTET]
    mov [di],bx
    dec al
    js .m
    add al,'0'
    mov [di+2],al
    ret
.m: mov byte [di+2],'-'
    cmp bh,'_'
    jnz .r
    mov word [di+1],'-1'
.r: ret
NOTET: db 'C_C#D_D#E_F_F#G_G#A_A#B_'
S_L2: db 'V00 EMPTY       ',0
S_OVD: db 'TOOLS NOT LOADED',0
S_OUT: db 'OUTPUT OFF',0
