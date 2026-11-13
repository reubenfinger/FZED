; ---------- render engine: Pockey2 + TapeHack (loaded at 8400h) ----------
FXMODE equ 0x8310
FXREZ equ 0x8311
FXDF equ 0x8312
FXIN equ 0x8313
FXOUT equ 0x8314
FXMIX equ 0x8315
FXARM equ 0x8316
FXM equ 0x8317
FXW equ 0x8318
FXFREQ equ 0x831A
FXOS equ 0x831C
FXMASK equ 0x831E
FXPOS equ 0x8320
FXHELD equ 0x8322
FXPREV equ 0x8324
FXLAST equ 0x8326
FXN equ 0x8328
FXT equ 0x832C
FXTL equ 0x8330
FXPC equ 0x8332
FXD equ 0x8334
FXGIN equ 0x8336
FXGOUT equ 0x8338
FXA equ 0x833A
FXSG equ 0x833C
FXF equ 0x833E
FXW2 equ 0x8340
FXLP equ 0x8342
LVON equ 0x8344
LVDIRTY equ 0x8345
LVV equ 0x8346
LVPOS equ 0x8348
LVLEN equ 0x834C
LVSRC equ 0x8350
LVLP equ 0x8354
LVRS equ 0x8356
LVRE equ 0x835A
LVN equ 0x835E
LVBUF equ 0xD2F0            ; PERF38H: D2F0h-D3EFh (B800h-B8FFh holds code)
FXRF equ 0x8360
FXRSH equ 0x8361
FXRII equ 0x8362
FXRIF equ 0x8364
FXRPI equ 0x8366
FXRPF equ 0x8368
RTAB equ 0xBE00            ; = THT (PERF38H: ring mode never uses the curve)
LVCP equ 0x8370
CHG0 equ 0x8374
CHSBV equ 0x8378
LVDV equ 0x8379
LVDS equ 0x837A
LVSEGI equ 0x837B
LVCLN equ 0x837C
LVCS equ 0x8380
LVCD equ 0x8384
LVCL equ 0x8388
LVSO equ 0x838C
LVSD equ 0x8390
LVSL equ 0x8394
LVWAS equ 0x8398
LVPM equ 0x8399
LVEV equ 0x839A
LVCNT equ 0x839C
LVCSG equ 0x839D
LVPHS equ 0x839E
LVCPOS equ 0x83A0
LVPHO equ 0x83A4
LVSV equ 0x83A8
KSP equ 0x83AE
KSFB equ 0x83B0
KSIN equ 0xC3E0          ; Karplus-Strong input gain (keeps resonant peaks near +6 dB)
KSI equ 0x83B2
LVNN equ 0x83B4
LVKS equ 0x83B6
FXTP equ 0x83B8
TPAD equ 0x83BA
TPOW equ 0x83BC
TGS equ 0x83BE
LVTMP equ 0x83C0
KSB equ 0xD400
THT equ 0xBE00
FXINIT:
    mov byte [FXMODE],5      ; TapeHack (PERF38C order)
    mov byte [FXREZ],79     ; 12 bit
    mov byte [FXDF],0
    mov byte [FXIN],13      ; x1.0
    mov byte [FXOUT],127
    mov byte [FXMIX],127
    mov byte [FXARM],0
    mov byte [LVON],0
    mov byte [LVDIRTY],0
    mov byte [FXRF],80      ; ring carrier about 68 Hz
    mov byte [CHSBV],0
    mov byte [LVWAS],0
    mov byte [FXRSH],0
    jmp FX5INIT
FXCC:               ; CC94 ring freq, 95 ring shape, 112 mode, 113 bits, 114 DeFreq, 115 input, 116 output, 117 mix, 118 render, 119 live
    mov bl,[cs:LASTCC]
    cmp bl,96
    jae .hi96
    cmp byte [LVON],0
    jz .r0
    mov byte [LVDIRTY],1
.r0: push ax
    call FXMOF
    mov bh,al
    pop ax
    cmp bh,6
    jnz .rg
    cmp bl,94               ; Karplus-Strong: CC94 note, CC95 feedback
    jnz .k95
    mov [FXRF],al
    mov di,S_KN+8
    call DEC3
    mov bx,S_KN
    jmp NMSGD
.k95: mov [FXRSH],al
    mov ah,100
    mul ah
    mov bl,127
    div bl
    mov di,S_KF+8
    call DEC3
    mov bx,S_KF
    jmp NMSGD
.rg: cmp bl,94
    jnz .c95
    mov [FXRF],al
    xor ah,ah
    shl ax,1
    mov bx,ax
    mov ax,[cs:bx+FREQT]    ; Hz x 16 -> Hz x 10
    mov cx,10
    mul cx
    mov cx,16
    div cx
    xor dx,dx
    mov di,S_RF+9
    mov cx,5
    call DECN
    mov al,[S_RF+9]
    mov [S_RF+10],al
    mov byte [S_RF+9],'.'
    mov bx,S_RF
    jmp NMSGD
.c95: mov [FXRSH],al
    mov bx,S_RS0
    cmp al,64
    jb .sm
    mov bx,S_RS1
.sm: jmp NMSGD
.hi96: cmp bl,119
    jnz .n119
    jmp LVCC
.n119: cmp bl,118
    jnz .set
    jmp .go
.set: cmp byte [LVON],0
    jz .s0
    mov byte [LVDIRTY],1    ; live: rebuild the curve on the next pass
.s0: sub bl,112
    xor bh,bh
    mov [bx+FXMODE],al
    or bl,bl
    jnz .m1
    call FXMOF
    jmp FMNAME              ; PERF38I: packed names (fx5ai.asm)
.m1: cmp bl,1
    jnz .m2
    call FXBITS
    mov di,S_FR+5
    call DEC2
    mov bx,S_FR
    jmp NMSGD
.m2: cmp bl,2
    jnz .m3
    mov di,S_FD+7
    call DEC3
    mov bx,S_FD
    jmp NMSGD
.m3: cmp bl,3
    jnz .m4
    call ISTUBE
    jnz .m3t
    mov bx,S_TP
    jmp .tl
.m3t: mov ah,100
    mul ah
    mov bl,127
    div bl
    mov di,S_FI+7
    call DEC3
    mov al,[S_FI+9]
    mov [S_FI+10],al
    mov byte [S_FI+9],'.'
    mov bx,S_FI
    jmp NMSGD
.m4: mov bl,[cs:LASTCC]
    cmp bl,116
    jnz .m4m
    call ISTUBE
    jnz .m4m
    mov bx,S_TA
.tl: push bx                ; Tube2: 'TUBE PAD nnn%' / 'TUBE AMT nnn%'
    mov ah,100
    mul ah
    mov bl,127
    div bl
    pop bx
    lea di,[bx+9]
    push bx
    call DEC3
    pop bx
    jmp NMSGD
.m4m: mov ah,100
    mul ah
    mov bl,127
    div bl
    mov bl,[cs:LASTCC]
    cmp bl,116
    jnz .m5
    mov di,S_FO+7
    call DEC3
    mov bx,S_FO
    jmp NMSGD
.m5: mov di,S_FX+4
    call DEC3
    mov bx,S_FX
    jmp NMSGD
.go: cmp al,64
    jae .hi
    mov byte [FXARM],0
    ret
.hi: cmp al,120
    jb .r
    cmp byte [FXARM],0
    jnz .r
    mov byte [FXARM],1
    call CHOK
    jc .r
    jmp FXRUN
.r: ret
DEC3:               ; al (0-255) -> three digits at [di]
    xor ah,ah
    mov bl,100
    div bl
    add al,'0'
    mov [di],al
    mov al,ah
    inc di
    jmp DEC2
FXRUN:
    call LVOFF              ; render works on the original sample
    mov bx,S_FW
    call NMSG
    call FXPAR
    cmp byte [FXM],12       ; echo / position: rendered through the live engine
    jb .r2
    jmp FXREN2
.r2:
    call L61DB
    mov bl,[si+0xb1]        ; the voice's rate scales DeFreq and blur like overallscale
    and bx,3
    shl bx,1
    mov ax,[cs:bx+FXOST]
    mov [FXOS],ax
    mov ax,[cs:bx+FXFTT]
    mov [FXF],ax
    mov al,[FXDF]           ; freq = DeFreq^3 * F >> 32
    mul al
    xor dh,dh
    mov dl,[FXDF]
    mul dx
    mov cx,ax
    mov bx,dx
    mul word [FXF]
    push dx
    mov ax,bx
    mul word [FXF]
    pop bx
    add ax,bx
    adc dx,0
    mov [FXFREQ],dx
    call THNEED
    jnz .nt
    call THBUILD
.nt: xor ax,ax
    mov [FXN],ax
    mov [FXN+2],ax
    mov [FXT],ax
    mov [FXT+2],ax
    mov ax,[0x40a]
    mov [FXTL],ax
    mov word [FXLP],FXLG    ; inner loop: generic, or a fast loop (TapeHack, ring, crush without DeFreq)
    mov al,[FXM]
    cmp al,9                ; rectifier, decimator, bit mangle
    jae .fast
    cmp al,1
    jz .fast
    cmp al,4
    jz .fast
    cmp al,5
    jz .fast
    cmp al,7
    jz .fast
    cmp al,3
    jnz .lp
    cmp word [FXFREQ],1
    ja .lp
.fast: mov ax,[LVLP]
    mov [FXLP],ax
.lp: push si
    call FXONE
    pop si
    cmp si,[CHOWN]
    jnz .dn
    xor bx,bx
    mov cl,[CHCNT]
    xor ch,ch
    jcxz .dn
.sl: push bx
    push cx
    mov si,[bx+CHV]
    call FXONE
    pop cx
    pop bx
    add bx,2
    loop .sl
.dn: call FXTICK
    mov ax,[FXT]            ; T = timer interrupts (about 3240 per second, measured)
    mov dx,[FXT+2]
    mov cx,5
.t5: shr dx,1
    rcr ax,1
    loop .t5
    mov [FXT],ax
    mov [FXT+2],dx
    cmp dx,324              ; seconds x 10 = T / 324
    jb .sv
    mov ax,0xffff
    xor dx,dx
    jmp .sx
.sv: mov cx,324
    div cx
.sx: xor dx,dx
    mov di,S_FT+11
    mov cx,4
    call DECN
    mov al,[S_FT+11]
    mov [S_FT+12],al
    mov byte [S_FT+11],'.'
    mov ax,[FXN]            ; samples per second = N * 3240 / T
    mov cx,3240
    mul cx
    push ax
    push dx
    mov ax,[FXN+2]
    mul cx
    pop dx
    add dx,ax
    pop ax
    mov bx,[FXT]
    mov cx,[FXT+2]
.nm: jcxz .nd
    shr cx,1
    rcr bx,1
    shr dx,1
    rcr ax,1
    jmp .nm
.nd: or bx,bx
    jz .z
    cmp dx,bx
    jae .big
    div bx
    jmp .ps
.z: xor ax,ax
    jmp .ps
.big: mov ax,0xffff
.ps: xor dx,dx
    mov di,S_FT+4
    mov cx,5
    call DECN
    mov bx,S_FT
    jmp NMSG
FXPAR:              ; all render/live parameters from the CCs; LVLP = fast loop for this mode (0 = none)
    call FXMOFP              ; 0 Pockey2, 1 TapeHack, 2 Tape>Pockey2, 3 crush, 4 ring, 5 wavefolder, 6 Karplus-Strong, 7 Tube2, 8 filter,
    mov [FXM],al            ; 9 rectifier, 10 decimator, 11 bit mangle
    mov al,[FXREZ]          ; bits 4..16: Pockey2 encoded mask and crush mask / half step
    mov ah,13
    mul ah
    shr ax,7
    add al,4
    mov cl,16
    sub cl,al
    mov ax,0xffff
    shl ax,cl
    mov [FXMASK],ax
    mov [CMASK],ax
    xor ax,ax
    or cl,cl
    jz .h0
    dec cl
    mov ax,1
    shl ax,cl
.h0: mov [CHALF],ax
    call CRPAR
    mov al,[FXMIX]          ; wet, Q14
    xor ah,ah
    mov cx,16384
    mul cx
    mov cx,127
    div cx
    mov [FXW],ax
    mov cx,16384
    sub cx,ax
    mov [FXW2],cx
.m: mov al,[FXIN]
    xor ah,ah
    mov cx,2560
    mul cx
    mov cx,127
    div cx
    mov [FXGIN],ax
    mov al,[FXOUT]
    xor ah,ah
    mov cx,476
    mul cx
    mov [FXGOUT],ax
    call RINGPAR
    mov bl,[FXRF]           ; Karplus-Strong period (CC94 = note at the original key) and feedback (CC95)
    xor bh,bh
    shl bx,1
    mov ax,[bx+KSPT]
    call L61DB
    mov cl,[si+0xb1]
    and cl,3
    shr ax,cl
    cmp ax,2
    jae .kp
    mov ax,2
.kp: mov [KSP],ax
    mov al,[FXRSH]          ; loop gain 32440 - 2*(127-v)^2: v 127 = 0.99, 100 = 0.95, 64 = 0.75, 0 = 0.01
    mov ah,127
    sub ah,al
    mov al,ah
    mul al
    shl ax,1
    mov dx,32440
    sub dx,ax
    mov [KSFB],dx
    mov ax,32768            ; input gain 4*(1 - loop gain), at most 1 (resonant peaks up to +12 dB)
    sub ax,dx
    cmp ax,8192
    jae .kx
    shl ax,2
    jmp .ki
.kx: mov ax,32767
.ki: mov [KSIN],ax
    call NXPAR
    call NXPAR2
    call SVPAR
    mov bl,[FXM]
    xor bh,bh
    shl bx,1
    mov ax,[bx+LPW]
    cmp word [FXW],16384
    jz .w
    mov ax,[bx+LPM]
.w: mov [LVLP],ax
    ret
LPW: dw 0,FXLT,FXLT,FXLC,FXLR,FXLT,1,FXLU,SVLV,FXLXW,FXLDW,FXLBW,FXLEW,FXLQW
LPM: dw 0,FXLTM,FXLTM,FXLCM,FXLRM,FXLTM,1,FXLU,SVLV,FXLX,FXLD,FXLB,FXLE,FXLQ
RINGPAR:            ; carrier step (16.16 per sample) from CC94 and the voice rate, locked to the active loop; RTAB shape
    call L61DB
    mov bl,[FXRF]
    xor bh,bh
    shl bx,1
    mov ax,[cs:bx+FREQT]
    mov cx,4096
    mul cx
    mov cl,[si+0xb1]
    and cl,3
    mov bx,36000
    shr bx,cl
    div bx
    mov [FXRII],ax
    xor ax,ax
    div bx
    mov [FXRIF],ax
    cmp word [si+0x12],0x0808   ; loop lock: whole carrier cycles in the active loop
    jz .tab
    xor bh,bh
    mov bl,[LIDX]
    shl bx,2
    mov ax,[bx+si+0x34]
    mov dx,[bx+si+0x36]
    and dx,0x1f
    mov cx,[bx+si+0x16]
    and cx,0x1f
    sub ax,[bx+si+0x14]
    sbb dx,cx
    jc .tab
    or dx,dx
    jnz .tab
    or ax,ax
    jz .tab
    mov bx,ax
    mov ax,[FXRIF]
    mul bx
    mov cx,dx
    mov ax,[FXRII]
    mul bx
    add ax,cx
    adc dx,0
    add ax,0x8000
    adc dx,0
    or dx,dx
    jnz .cy
    inc dx
.cy: cmp dx,bx
    jae .tab
    xor ax,ax
    div bx
    mov [FXRII],ax
    xor ax,ax
    div bx
    mov [FXRIF],ax
.tab: cmp byte [FXM],4      ; ring mode only: RTAB shares THT's memory since PERF38H
    jnz .tr
    mov al,[FXRSH]          ; PERF38K: rebuilt only when the shape changes or a curve has used the memory
    and al,0x40
    or al,0x80
    cmp byte [CVAL],0
    jnz .bt
    cmp al,[RSHC]
    jz .tr
.bt: mov [RSHC],al
    mov byte [CVAL],0
    mov di,RTAB
    xor bx,bx
    mov cx,256
.t: call SINR
    cmp byte [FXRSH],64
    jb .s
    mov ax,32767
    cmp bx,256
    jb .s
    mov ax,-32767
.s: mov [di],ax
    add di,2
    add bx,2
    loop .t
.tr: ret
LVCC:               ; CC119 >= 64 live on; < 64 off = bypass (swept back to clean, copy kept for an instant restart)
    cmp al,64
    jae .on
    mov al,[LVON]
    cmp al,1
    jnz .o2
    jmp LVOFF               ; still copying: release
.o2: cmp al,2
    jnz .r
    mov byte [LVON],3
    call LVSETLEN
    mov bx,S_L0
    jmp NMSG
.on: call FXPAR
    cmp word [LVLP],0
    jnz .md
    mov bx,S_LP
    jmp NMSG
.md: mov al,[LVON]
    cmp al,3
    jb .nw
    mov byte [LVON],2       ; copy still there: back on at once
    mov byte [LVDIRTY],1
    mov bx,S_L1
    jmp NMSG
.nw: or al,al
    jnz .r
    call CHOK
    jc .r
    cmp word [si+0x10],0
    jz .r
    mov [LVVOI],si          ; live FX belongs to this voice
    mov ax,[GSAVE]
    mov [LVG0],ax
    mov ax,[GSAVE+2]
    mov [LVG0+2],ax
    mov ax,[AEL]            ; clean copy of the whole original range GSAVE..AE
    mov dx,[AEH]
    and dx,0x1f
    sub ax,[LVG0]
    sbb dx,[LVG0+2]
    jc .r
    mov [LVLEN],ax
    mov [LVLEN+2],dx
    mov di,0x2288           ; free voice slot for the copy
    mov cx,64
.fv: cmp di,si
    jz .fn
    cmp word [di+0x10],0
    jz .got
.fn: add di,0xc0
    loop .fv
    mov bx,S_LV
    jmp NMSG
.got: push di
    push word [LVLEN+2]
    push word [LVLEN]
    push word 0
    push di
    APIC 117,8
    pop di
    or bx,bx
    jz .al
    mov bx,S_LM
    jmp NMSG
.al: mov [LVV],di
    mov ax,[di+8]
    mov [LVSRC],ax
    mov dx,[di+0xa]
    and dx,0x1f
    mov [LVSRC+2],dx
    xor ax,ax
    mov [LVCP],ax           ; the copy is made a block at a time by the main loop
    mov [LVCP+2],ax
    mov [LVPOS],ax
    mov [LVPOS+2],ax
    mov [LVSEGI],al
    mov [LVDV],al
    mov [LVDS],al
    mov byte [LVON],1
    mov bx,S_LC
    jmp NMSG
.r: ret
LVOFF:              ; release: processed parts back from the copy, copy voice deleted
    mov al,[LVON]
    or al,al
    jnz .go
    jmp .r
.go: cmp al,1
    jz .del
    cmp byte [LVDV],0
    jz .sl
    mov ax,[LVSRC]
    mov [LVCS],ax
    mov ax,[LVSRC+2]
    mov [LVCS+2],ax
    mov ax,[LVG0]
    mov [LVCD],ax
    mov ax,[LVG0+2]
    mov [LVCD+2],ax
    mov ax,[LVLEN]
    mov [LVCL],ax
    mov ax,[LVLEN+2]
    mov [LVCL+2],ax
    call LVCOPY
.sl: cmp byte [LVDS],0
    jz .del
    call LVSOK
    jnc .del
    xor bx,bx
.s1: cmp bl,[CHCNT]
    jae .del
    push bx
    call LVSLICE            ; LVSO/LVSD/LVSL for slice bl
    mov ax,[LVSRC]
    add ax,[LVSO]
    mov [LVCS],ax
    mov ax,[LVSRC+2]
    adc ax,[LVSO+2]
    mov [LVCS+2],ax
    mov ax,[LVSD]
    mov [LVCD],ax
    mov ax,[LVSD+2]
    mov [LVCD+2],ax
    mov ax,[LVSL]
    mov [LVCL],ax
    mov ax,[LVSL+2]
    mov [LVCL+2],ax
    call LVCOPY
    pop bx
    inc bl
    jmp .s1
.del: mov byte [LVON],0
    call L61DB
    push word [si+8]
    push word 0
    push word [LVV]
    APIC 169,4
    call L61DB
    pop ax
    cmp ax,[si+8]
    jz .m
    call ADDREF             ; (the FZ moved this voice's data)
.m: mov bx,S_LR
    call NMSG
.r: push ds
    pop es
    ret
LVCOPY:             ; LVCL words from wave LVCS to wave LVCD, 128 at a time through LVBUF (256 bytes since PERF38G)
.l: mov ax,[LVCL]
    or ax,[LVCL+2]
    jz .r
    mov cx,128
    cmp word [LVCL+2],0
    jnz .c
    cmp [LVCL],cx
    jae .c
    mov cx,[LVCL]
.c: push cx
    mov ax,[LVCS]
    mov dx,[LVCS+2]
    call LVRD
    pop cx
    push cx
    mov ax,[LVCD]
    mov dx,[LVCD+2]
    call LVWR
    pop cx
    add [LVCS],cx
    adc word [LVCS+2],0
    add [LVCD],cx
    adc word [LVCD+2],0
    sub [LVCL],cx
    sbb word [LVCL+2],0
    jmp .l
.r: push ds
    pop es
    ret
LVSOK:              ; CF=1 when the chop slices can be live-processed (made from this voice's clean data)
    cmp byte [CHCNT],0
    jz .no
    cmp byte [CHSBV],0
    jz .no
    mov ax,[LVG0]
    cmp ax,[CHG0]
    jnz .no
    mov ax,[LVG0+2]
    cmp ax,[CHG0+2]
    jnz .no
    stc
    ret
.no: clc
    ret
LVSLM:              ; CF=1 when slices are being played and can be processed
    cmp byte [CHPLAY],0
    jz .no
    jmp LVSOK
.no: clc
    ret
LVSLICE:            ; bl = slice: LVSO = clean offset, LVSD = slice data start, LVSL = length
    push bx
    xor bh,bh
    mov si,bx
    shl si,2
    mov ax,[si+SBND]
    mov dx,[si+SBND+2]
    sub ax,[CHG0]
    sbb dx,[CHG0+2]
    mov [LVSO],ax
    mov [LVSO+2],dx
    mov ax,[si+SBND+4]
    mov dx,[si+SBND+6]
    sub ax,[si+SBND]
    sbb dx,[si+SBND+2]
    mov [LVSL],ax
    mov [LVSL+2],dx
    shl bx,1
    mov si,[bx+CHV]
    mov ax,[si+8]
    mov [LVSD],ax
    mov ax,[si+0xa]
    and ax,0x1f
    mov [LVSD+2],ax
    pop bx
    ret
LVSEG:              ; current segment: the voice's start..end, or slice LVSEGI when slices are playing. CF=1 none
    call LVSLM
    jnc .v
    mov bl,[LVSEGI]
    cmp bl,[CHCNT]
    jb .s
    xor bl,bl
    mov [LVSEGI],bl
.s: call LVSLICE
    clc
    ret
.v: mov byte [LVSEGI],0xff
    call L61DB
    mov ax,[si+8]           ; start..end relative to GSAVE, inside the copy
    mov dx,[si+0xa]
    and dx,0x1f
    sub ax,[LVG0]
    sbb dx,[LVG0+2]
    jnc .s1
    xor ax,ax
    xor dx,dx
.s1: mov [LVSO],ax
    mov [LVSO+2],dx
    mov bx,ax
    mov cx,dx
    mov ax,[si+0xc]
    mov dx,[si+0xe]
    and dx,0x1f
    add ax,1
    adc dx,0
    sub ax,[LVG0]
    sbb dx,[LVG0+2]
    jc .bad
    cmp dx,[LVLEN+2]
    jb .e1
    ja .e0
    cmp ax,[LVLEN]
    jbe .e1
.e0: mov ax,[LVLEN]
    mov dx,[LVLEN+2]
.e1: sub ax,bx
    sbb dx,cx
    jc .bad
    mov [LVSL],ax
    mov [LVSL+2],dx
    mov ax,[LVG0]
    add ax,bx
    mov [LVSD],ax
    mov ax,[LVG0+2]
    adc ax,cx
    mov [LVSD+2],ax
    clc
    ret
.bad: stc
    ret
LVSETLEN:           ; LVCLN = words to sweep clean (voice range, or all slices)
    call LVSLM
    jnc .v
    mov bl,[CHCNT]
    xor bh,bh
    shl bx,2
    mov ax,[bx+SBND]
    mov dx,[bx+SBND+2]
    sub ax,[SBND]
    sbb dx,[SBND+2]
    jmp .st
.v: call LVSEG
    mov ax,[LVSL]
    mov dx,[LVSL+2]
.st: mov [LVCLN],ax
    mov [LVCLN+2],dx
    ret
LVFINDPH:           ; playhead of the first note playing the voice (or a slice): LVPHS = segment, LVPHO = offset. CF=1 none
    mov al,[LVSEGI]
    mov [LVSV],al
    call LVSLM
    sbb al,al
    mov [LVPM],al
    call L61DB
    mov [LVEV],si
    mov di,0x5420
    mov dl,1
.g: cmp byte [di],0xff
    jz .n
    mov ax,[di+0xa]
    cmp byte [LVPM],0
    jnz .sm
    cmp ax,[LVEV]
    jnz .n
    jmp .hit
.sm: xor bx,bx
.f: cmp bl,[CHCNT]
    jae .n
    push bx
    xor bh,bh
    shl bx,1
    cmp ax,[bx+CHV]
    pop bx
    jz .fs
    inc bl
    jmp .f
.fs: mov [LVSEGI],bl
.hit: push di
    push dx
    call LVSEG
    pop dx
    push dx
    call GAREAD
    jc .x
    sub cx,[LVSD]
    sbb dx,[LVSD+2]
    jc .x
    cmp dx,[LVSL+2]
    jb .ok
    ja .x
    cmp cx,[LVSL]
    jae .x
.ok: mov [LVPHO],cx
    mov [LVPHO+2],dx
    mov al,[LVSEGI]
    mov [LVPHS],al
    pop dx
    pop di
    mov al,[LVSV]
    mov [LVSEGI],al
    clc
    ret
.x: pop dx
    pop di
.n: add di,0x3a
    shl dl,1
    jnz .g
    mov al,[LVSV]
    mov [LVSEGI],al
    stc
    ret
LVRUN:              ; main loop: copy step, or re-render 128 words: 3 of 4 chunks chase the playhead, 1 sweeps
    mov al,[LVON]
    or al,al
    jnz .a
    jmp .r
.a: mov ah,[RST]
    cmp ah,1
    jb .ok
    cmp ah,3
    ja .ok
    jmp .r
.ok: cmp al,1
    jnz .n1
    jmp LVCPY
.n1: cmp al,4
    jnz .n4
    jmp .r
.n4: cmp byte [LVDIRTY],0
    jz .nd
    mov byte [LVDIRTY],0
    call FXPAR
    cmp word [LVLP],0
    jnz .p1
    jmp LVOFF               ; switched to Pockey2: release
.p1: call THNEED
    jnz .nd
    call CURVEQ             ; PERF38H: only a changed curve, built in steps
.nd: inc byte [LVCNT]
    test byte [LVCNT],3
    jz .sw
    call LVFINDPH
    jc .sw
    mov al,[LVPHS]          ; chase cursor: keep it within 512 words ahead of the playhead
    cmp al,[LVCSG]
    jnz .jp
    mov ax,[LVCPOS]
    mov dx,[LVCPOS+2]
    sub ax,[LVPHO]
    sbb dx,[LVPHO+2]
    jc .jp
    or dx,dx
    jnz .jp
    cmp ax,512
    jb .kp
.jp: mov al,[LVPHS]
    mov [LVCSG],al
    mov ax,[LVPHO]
    and ax,0xff80           ; chunks on 128-word steps (the filter's map)
    mov [LVCPOS],ax
    mov ax,[LVPHO+2]
    mov [LVCPOS+2],ax
.kp: push word [LVPOS]      ; swap in the chase cursor
    push word [LVPOS+2]
    mov al,[LVSEGI]
    push ax
    mov al,[LVCSG]
    mov [LVSEGI],al
    mov ax,[LVCPOS]
    mov [LVPOS],ax
    mov ax,[LVCPOS+2]
    mov [LVPOS+2],ax
    mov byte [SVSTR],1      ; filter state: chase stream
    call LVCHK
    mov byte [SVSTR],0
    mov al,[LVSEGI]
    mov [LVCSG],al
    mov ax,[LVPOS]
    mov [LVCPOS],ax
    mov ax,[LVPOS+2]
    mov [LVCPOS+2],ax
    pop ax
    mov [LVSEGI],al
    pop word [LVPOS+2]
    pop word [LVPOS]
    cmp byte [SVSKD],0      ; filter chase found its chunk done: sweep instead
    jz .r
    mov byte [SVSKD],0
.sw: call LVCHK             ; sweep cursor (counts towards bypass being complete)
    cmp byte [LVON],3
    jnz .r
    mov ax,[LVNN]
    sub [LVCLN],ax
    sbb word [LVCLN+2],0
    jnc .r
    mov byte [LVON],4
    mov al,[LVSEGI]
    cmp al,0xff
    jz .cv
    mov byte [LVDS],0
    jmp .cs
.cv: mov byte [LVDV],0
.cs: mov bx,S_LI
    call NMSG
.r: push ds
    pop es
    ret
LVCHK:              ; process (or, in bypass, restore) up to 128 words at LVSEGI/LVPOS; LVNN = words done
    mov word [LVNN],0
    call LVSEG
    jnc .sg
    jmp .r
.sg: mov ax,[LVPOS]         ; n = min(128, length - pos)
    mov dx,[LVPOS+2]
    mov bx,[LVSL]
    mov cx,[LVSL+2]
    sub bx,ax
    sbb cx,dx
    jc .nx
    jnz .big
    cmp bx,128
    jbe .nn
.big: mov bx,128
.nn: call SVSWN             ; filter sweep: stop at a loop end
    or bx,bx
    jnz .go
.nx: jmp .next
.go: call SVSKIP            ; filter: chunk already done with these settings
    jnc .go2
    mov [LVN],bx
    jmp .adv
.go2: mov byte [LVKS],0
    cmp byte [LVON],2
    jnz .ks0
    cmp byte [FXM],6        ; Karplus-Strong: chunk no longer than one period
    jnz .ks0
    mov cx,[KSP]
    inc cx
    cmp word [LVSL+2],0
    jnz .ks1
    cmp [LVSL],cx
    jbe .ks0                ; segment shorter than a period: copy only
.ks1: dec cx
    cmp bx,cx
    jbe .ks2
    mov bx,cx
.ks2: mov byte [LVKS],1
.ks0: mov [LVN],bx
    add ax,[LVSO]           ; clean source offset of this chunk
    adc dx,[LVSO+2]
    push ax
    push dx
    add ax,[LVSRC]
    adc dx,[LVSRC+2]
    mov cx,bx
    call LVRD
    pop dx
    pop ax
    cmp byte [LVON],2       ; bypass: write the clean words back unchanged
    jnz .wr
    cmp byte [LVKS],0
    jz .np
    call LVKSCH
    jmp .dd
.np: cmp byte [FXM],6
    jz .dd                  ; (Karplus-Strong segment too short: left unprocessed)
    cmp byte [FXM],7
    jnz .nt7
    push ax
    push dx
    call TUPREP
    pop dx
    pop ax
.nt7: cmp byte [FXM],10       ; decimator: place in the block, held word
    jnz .nt10
    push ax
    push dx
    call DCPREP
    pop dx
    pop ax
.nt10: cmp byte [FXM],12       ; echo: the delayed clean words
    jnz .n12
    push ax
    push dx
    call ECPREP2
    pop dx
    pop ax
.n12: cmp byte [FXM],13       ; position: the moved clean words
    jnz .n13
    push ax
    push dx
    call POPREP
    pop dx
    pop ax
.n13: mov cx,ax               ; ring phase at this clean offset (same every pass, no seams)
    mov di,dx
    mul word [FXRIF]
    mov [FXRPF],ax
    mov bx,dx
    mov ax,cx
    mul word [FXRII]
    add bx,ax
    mov ax,di
    mul word [FXRIF]
    add bx,ax
    mov [FXRPI],bx
    push es
    push ds
    pop es
    mov si,LVBUF
    mov cx,[LVN]
    call [LVLP]
    pop es
.dd: cmp byte [LVSEGI],0xff
    jz .dv
    mov byte [LVDS],1
    jmp .wr
.dv: mov byte [LVDV],1
.wr: call SVNOWR            ; filter sweep, first time round a loop: run through only
    jc .adv
    mov ax,[LVSD]          ; write over the voice / slice
    mov dx,[LVSD+2]
    add ax,[LVPOS]
    adc dx,[LVPOS+2]
    mov cx,[LVN]
    call LVWR
    call SVMARK
.adv: mov ax,[LVN]
    mov [LVNN],ax
    add [LVPOS],ax
    adc word [LVPOS+2],0
    call SVSWADV
    jmp .r
.next: xor ax,ax
    mov [LVPOS],ax
    mov [LVPOS+2],ax
    cmp byte [LVSEGI],0xff
    jz .r
    mov al,[LVSEGI]
    inc al
    cmp al,[CHCNT]
    jb .s2
    xor al,al
.s2: mov [LVSEGI],al
.r: push ds
    pop es
    ret
LVKSCH:             ; Karplus-Strong on LVBUF: y = x + fb * (y[-P] + y[-P-1]) / 2, history read from the voice
    mov ax,[LVPOS]          ; history start = pos - P - 1, wrapped inside the segment
    mov dx,[LVPOS+2]
    sub ax,[KSP]
    sbb dx,0
    sub ax,1
    sbb dx,0
    jnc .h1
    add ax,[LVSL]
    adc dx,[LVSL+2]
.h1: mov bx,[LVSL]          ; words before the segment end
    mov cx,[LVSL+2]
    sub bx,ax
    sbb cx,dx
    mov si,[LVN]
    inc si                  ; n + 1 history words
    or cx,cx
    jnz .one
    cmp bx,si
    jae .one
    push si                 ; wraps: part 1 up to the end, part 2 from the start
    push bx
    add ax,[LVSD]
    adc dx,[LVSD+2]
    mov cx,bx
    mov di,KSB
    call LVRDX
    pop bx
    pop si
    sub si,bx
    shl bx,1
    lea di,[bx+KSB]
    mov ax,[LVSD]
    mov dx,[LVSD+2]
    mov cx,si
    call LVRDX
    jmp .cm
.one: add ax,[LVSD]
    adc dx,[LVSD+2]
    mov cx,si
    mov di,KSB
    call LVRDX
.cm: push es
    push ds
    pop es
    mov si,LVBUF
    mov bx,KSB
    mov cx,[LVN]
.l: mov ax,[bx]
    sar ax,1
    mov dx,[bx+2]
    sar dx,1
    add ax,dx
    imul word [KSFB]
    shl ax,1
    rcl dx,1
    push dx
    mov ax,[si]
    imul word [KSIN]
    shl ax,1
    rcl dx,1
    mov ax,dx
    pop dx
    add dx,ax
    jno .ok
    mov dx,0x7fff
    or ax,ax
    jns .ok
    mov dx,0x8000
.ok: cmp word [FXW],16384
    jz .st
    push bx
    mov ax,dx
    mov bx,[si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    pop bx
.st: mov [si],dx
    add si,2
    add bx,2
    loop .l
    pop es
    ret
.of: call MIXOV
    jmp .j
LVCPY:              ; making the clean copy, 128 words per main-loop pass (MIDI keeps flowing)
    mov ax,[LVLEN]
    mov dx,[LVLEN+2]
    sub ax,[LVCP]
    sbb dx,[LVCP+2]
    mov cx,128
    or dx,dx
    jnz .c
    cmp ax,cx
    jae .c
    mov cx,ax
.c: jcxz .done
    push cx
    mov ax,[LVG0]
    mov dx,[LVG0+2]
    add ax,[LVCP]
    adc dx,[LVCP+2]
    call LVRD
    pop cx
    push cx
    mov ax,[LVSRC]
    mov dx,[LVSRC+2]
    add ax,[LVCP]
    adc dx,[LVCP+2]
    call LVWR
    pop cx
    add [LVCP],cx
    adc word [LVCP+2],0
    jmp .r
.done: mov byte [LVON],2
    mov byte [LVDIRTY],1
    mov bx,S_L1
    call NMSG
.r: push ds
    pop es
    ret
LVSET:              ; wave word address dx:ax -> es:si window, bl = port 22h value
    shl ax,1
    rcl dx,1
    mov si,ax
    in al,0x22
    and al,0xc0
    and dl,0x3f
    or al,dl
    mov bl,al
    out 0x22,al
    mov ax,0x1000
    mov es,ax
    ret
LVRD:               ; cx words from wave dx:ax into LVBUF
    mov di,LVBUF
LVRDX:              ; cx words from wave dx:ax into [di] (PERF38H: runs up to the bank edge, two words a turn)
    push di
    call LVSET
    pop di
    cld
.l: call LVRUNN             ; ax = words in this run, cx = words after it
    xchg ax,cx
    push es                 ; rep movsw reads DS:SI: DS on the sample window, ES on PERF's memory
    push ds                 ; (the FZ's interrupt handlers load their own DS)
    pop es
    pop ds
    rep movsw
    push es
    push ds
    pop es
    pop ds
    mov cx,ax
    jcxz .r
    call LVBK
    jmp .l
.r: ret
LVWR:               ; cx words from LVBUF to wave dx:ax (PERF38H: rep movsw up to the bank edge)
    call LVSET
    mov di,si
    mov si,LVBUF
    cld
.l: xchg si,di
    call LVRUNN
    xchg si,di
    xchg ax,cx
    rep movsw
    mov cx,ax
    jcxz .r
    call LVBK
    jmp .l
.r: ret
SINR:               ; PERF38K: bx = 2k (k 0..255) -> ax = sine table value, from the quarter-wave SINQ (keeps bx)
    push bx
    shr bx,1
    push bx
    and bx,127
    cmp bl,64
    jbe .a
    neg bx
    add bx,128
.a: shl bx,1
    mov ax,[cs:bx+SINQ]
    pop bx
    test bl,128
    jz .p
    neg ax
.p: pop bx
    ret
LVRUNN:             ; si = window offset, cx = words wanted -> ax = words before the bank edge (at most cx), cx -= ax
    mov ax,si
    neg ax
    shr ax,1
    jnz .a
    mov ax,0x8000
.a: cmp ax,cx
    jbe .b
    mov ax,cx
.b: sub cx,ax
    ret
LVBK:               ; next 64K bank
    mov al,bl
    mov ah,al
    and ah,0xc0
    inc al
    and al,0x3f
    or al,ah
    mov bl,al
    out 0x22,al
    ret
DECN:               ; dx:ax -> cx decimal digits ending at [di]
.l: push cx
    mov cx,10
    mov bx,ax
    mov ax,dx
    xor dx,dx
    div cx
    xchg ax,bx
    div cx
    add dl,'0'
    mov [di],dl
    dec di
    mov dx,bx
    pop cx
    loop .l
    ret
FXTICK:
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[FXTL]
    mov [FXTL],dx
    add [FXT],ax
    adc word [FXT+2],0
    ret
THNEED:             ; ZF=1 when the mode uses the curve table (TapeHack, TapeHack>Pockey2, wavefolder)
    mov al,[FXM]
    cmp al,1
    jz .y
    cmp al,2
    jz .y
    cmp al,7
    jz .y
    cmp al,5
.y: ret
ISTUBE:             ; ZF=1 when CC112 selects Tube2 (keeps al)
    push ax
    call FXMOF
    cmp al,7
    pop ax
    ret
THENT:              ; TapeHack / wavefolder curve entry: cx = k (|x| = 64k) -> ax (THBUILD / CBLD in fx5.asm)
    mov ax,cx
    mul word [CGIN]
    cmp byte [FXM],5
    jnz .th
    shr dx,1                ; wavefolder: u = |x| * gain (Q15), triangle fold, period 4.0
    rcr ax,1
    shr dx,1
    rcr ax,1
    and dx,1                ; dx = sign of the folded value
    cmp ax,0x8000
    jb .fm
    neg ax                  ; magnitude 0..1.0
.fm: mov bx,dx
    mul word [CGOUT]
    or bx,bx
    jz .st
    neg dx
    jmp .st
.th: mov bx,dx
    mov dx,14210
    mul dx
    push dx
    mov ax,bx
    mov dx,14210
    mul dx
    pop bx
    add ax,bx
    adc dx,0
    or dx,dx
    jz .ip
    mov ax,[STAB+512]
    jmp .sv
.ip: mov bx,ax
    shr bx,8
    shl bx,1
    and ax,0xff
    mov dx,[bx+STAB+2]
    sub dx,[bx+STAB]
    imul dx
    mov al,ah
    mov ah,dl
    add ax,[bx+STAB]
.sv: mul word [CGOUT]
    shl ax,1
    rcl dx,1
.st: mov ax,dx
    ret
FXONE:              ; render voice si between start and end, in chunks of up to 256 words inside one bank
    cmp byte [FXM],8
    jnz .nsv
    jmp SVRONE              ; filter: its own render (loop seam settled)
.nsv: call NSETUP
    jc .x
    xor ax,ax
    mov [FXPOS],ax
    mov [FXHELD],ax
    mov [FXPREV],ax
    mov [FXLAST],ax
    mov [FXRPI],ax
    mov [FXRPF],ax
    mov [KSI],ax
    mov [FXTP],ax
    push es                 ; clear the Karplus-Strong history
    push ds
    pop es
    push di
    push cx
    mov di,KSB
    mov cx,1024
    cld
    rep stosw
    pop cx
    pop di
    pop es
.ch: mov ax,si              ; words left in this bank
    neg ax
    shr ax,1
    jnz .a
    mov ax,0x8000
.a: cmp ax,256
    jbe .b
    mov ax,256
.b: cmp word [NCNT+2],0
    jnz .c
    cmp ax,[NCNT]
    jbe .c
    mov ax,[NCNT]
.c: mov cx,ax
    sub [NCNT],ax
    sbb word [NCNT+2],0
    add [FXN],ax
    adc word [FXN+2],0
    call [FXLP]
    call FXTICK
    or si,si
    jnz .d
    mov al,[NBANK]          ; next 64K bank
    mov ah,al
    and ah,0xc0
    inc al
    and al,0x3f
    or al,ah
    mov [NBANK],al
    out 0x22,al
.d: mov ax,[NCNT]
    or ax,[NCNT+2]
    jnz .ch
.x: push ds
    pop es
    ret
FXLG:               ; generic: cx words at es:si through FXSMP
.l: mov ax,[es:si]
    push cx
    push si
    call FXSMP
    pop si
    pop cx
    mov [es:si],ax
    add si,2
    loop .l
    ret
FXLT:               ; TapeHack, fully wet: table + interpolation, sign kept in bp
.l: mov ax,[es:si]
    cwd
    mov bp,dx
    xor ax,dx
    sub ax,dx
    mov bx,ax
    shr bx,5
    and bx,0xfffe
    and ax,63
    mov di,[bx+THT+2]
    sub di,[bx+THT]
    imul di
    shl ax,1                ; (dx:ax >> 6), low word
    rcl dx,1
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    xor ax,bp
    sub ax,bp
    mov [es:si],ax
    add si,2
    loop .l
    ret
FXLTM:              ; TapeHack with dry/wet mix
.l: mov ax,[es:si]
    cwd
    mov bp,dx
    xor ax,dx
    sub ax,dx
    mov bx,ax
    shr bx,5
    and bx,0xfffe
    and ax,63
    mov di,[bx+THT+2]
    sub di,[bx+THT]
    imul di
    shl ax,1                ; (dx:ax >> 6), low word
    rcl dx,1
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    xor ax,bp
    sub ax,bp
    mov bx,[es:si]          ; out = dry + ((wet - dry) * FXW >> 14): the same word as the two-product form
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
FXLC:               ; linear crush, fully wet
.l: mov ax,[es:si]
    add ax,[CHALF]
    jno .m
    mov ax,0x7fff
.m: and ax,[CMASK]
    mov [es:si],ax
    add si,2
    loop .l
    ret
FXLCM:              ; linear crush with mix
.l: mov ax,[es:si]
    add ax,[CHALF]
    jno .m
    mov ax,0x7fff
.m: and ax,[CMASK]
    mov bx,[es:si]          ; out = dry + ((wet - dry) * FXW >> 14): the same word as the two-product form
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
FXLR:               ; ring mod, fully wet: phase bp.di (16.16)
    mov bp,[FXRPI]
    mov di,[FXRPF]
.l: mov bx,bp
    shr bx,7
    and bx,0x1fe
    mov ax,[es:si]
    imul word [bx+RTAB]
    shl ax,1
    rcl dx,1
    mov [es:si],dx
    add di,[FXRIF]
    adc bp,[FXRII]
    add si,2
    loop .l
    mov [FXRPI],bp
    mov [FXRPF],di
    ret
FXLRM:              ; ring mod with mix
    mov bp,[FXRPI]
    mov di,[FXRPF]
.l: mov bx,bp
    shr bx,7
    and bx,0x1fe
    mov ax,[es:si]
    imul word [bx+RTAB]
    shl ax,1
    rcl dx,1
    mov ax,dx
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
    add di,[FXRIF]
    adc bp,[FXRII]
    add si,2
    loop .l
    mov [FXRPI],bp
    mov [FXRPF],di
    ret
.of: call MIXOV
    jmp .j
FXLBW:              ; bit mangle, fully wet
    mov ax,[MGM]
.l: xor [es:si],ax
    add si,2
    loop .l
    ret
MIXOV:              ; wet - dry did not fit 16 bits (flags from the SUB): dx:ax = (wet - dry) * FXW all the same
    js .p
    imul word [FXW]
    sub dx,[FXW]
    ret
.p: imul word [FXW]
    add dx,[FXW]
    ret
TUINIT:             ; Tube2 static curve over the signed input: THT[k] for x = -32768 + 128k (TUENT), k = 0..513
    mov al,[FXIN]           ; pad = CC115 (127 = none)
    xor ah,ah
    mov cx,32767
    mul cx
    mov cx,127
    div cx
    mov [TPAD],ax
    mov al,127              ; p = 9 * (1 - tube) + 1 (1..10)
    sub al,[FXOUT]
    mov ah,9
    mul ah
    mov cl,127
    div cl
    xor ah,ah
    inc ax
    mov [TPOW],ax
    mov cx,ax
    inc cx
    mov ax,32768
    xor dx,dx
    div cx
    mov [TGSN],ax           ; gain scaling 1/(p+1), into TGS with the curve
    ret
TUENT:              ; cx = k -> ax
    push si
    cmp cx,512
    jb .k
    mov dx,[TPAD]           ; x = +1.0
    jmp .pd
.k: mov ax,cx
    shl ax,7
    sub ax,0x8000
    imul word [TPAD]
    shl ax,1
    rcl dx,1
.pd: mov ax,dx              ; a /= p
    cwd
    idiv word [TPOW]
    push ax
    or ax,ax
    jns .a1
    neg ax
.a1: call SQRTQ             ; sharpen = 1 -/+ sqrt(|a|)
    shr ax,1
    mov cx,ax
    pop ax
    mov bx,16384
    or ax,ax
    js .ng
    sub bx,cx
    jmp .sh
.ng: add bx,cx
.sh: mov si,ax              ; a -= a*|a|*sharpen/4
    mov cx,ax
    or cx,cx
    jns .a2
    neg cx
.a2: imul cx
    shl ax,1
    rcl dx,1
    mov ax,dx
    imul bx                 ; (t * sharpen) >> 16 = ((t * sharpen) >> 14) / 4
    sub si,dx
    mov ax,si               ; a *= p
    imul word [TPOW]
    mov si,ax
    mov bx,ax               ; f = |a|^(p+1) / (p+1)
    or bx,bx
    jns .a3
    neg bx
.a3: mov ax,bx
    mov cx,[TPOW]
.pw: mul bx
    shl ax,1
    rcl dx,1
    mov ax,dx
    loop .pw
    xor dx,dx
    mov cx,[TPOW]
    inc cx
    div cx
    or si,si
    js .an
    sub si,ax
    jmp .a4
.an: add si,ax
.a4: mov ax,si              ; a += a/p (32-bit, then clamp)
    cwd
    mov bx,ax
    mov cx,dx
    idiv word [TPOW]
    cwd
    add ax,bx
    adc dx,cx
    or dx,dx
    jg .hi
    jl .lo
    cmp ax,0x8000
    jb .sv
.hi: mov ax,0x7fff
    jmp .sv
.lo: cmp dx,-1
    jl .lo2
    cmp ax,0x8000
    jae .sv
.lo2: mov ax,0x8000
.sv: pop si
    ret
SQRTQ:              ; ax = 0..65535 (Q15) -> ax = square root (Q15); table over 0.5..2 with interpolation
    or ax,ax
    jz .r
    xor cl,cl
    or ah,ah
    jnz .n
    xchg al,ah              ; below 256: four of the steps below at once
    mov cl,4
.n: cmp ax,16384
    jae .t
    shl ax,2
    inc cl
    jmp .n
.t: mov bx,ax
    sub bx,16384
    mov bl,bh               ; (bx >> 9) * 2
    and bx,0x00fe
    and ax,511
    push cx
    mov cx,[bx+SQN2+2]
    sub cx,[bx+SQN2]
    mul cx
    shr dx,1                ; (dx:ax >> 9), low word
    rcr ax,1
    mov al,ah
    mov ah,dl
    add ax,[bx+SQN2]
    pop cx
    shr ax,cl
.r: ret
TLOOK:              ; ax = input sample -> Tube2 static curve (table + interpolation)
    mov bx,ax
    xor bx,0x8000
    mov dx,bx
    and dx,127
    shr bx,7
    shl bx,1
    mov ax,[bx+THT+2]
    sub ax,[bx+THT]
    imul dx
    shl ax,1                ; (dx:ax >> 7), low word
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    ret
TUPREP:             ; live: FXTP = curve of the clean word just before this chunk
    mov ax,[LVPOS]
    or ax,[LVPOS+2]
    jz .z
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    add ax,[LVSO]
    adc dx,[LVSO+2]
    add ax,[LVSRC]
    adc dx,[LVSRC+2]
    sub ax,1
    sbb dx,0
    mov di,LVTMP
    mov cx,1
    call LVRDX
    mov ax,[LVTMP]
    jmp .lk
.z: mov ax,[LVBUF]
.lk: call TLOOK
    mov [FXTP],ax
    push ds
    pop es
    ret
FXLU:               ; Tube2: static curve, then the slew stage, clamp, mix
.l: push cx
    mov ax,[es:si]
    call TLOOK
    mov bx,[FXTP]           ; slew = previous - current
    mov [FXTP],ax
    mov di,ax
    cmp bx,ax
    jg .dp
    sub ax,bx
    call SQRTQ
    shr ax,2
    mov bx,16384
    sub bx,ax
    jmp .sg
.dp: sub bx,ax
    mov ax,bx
    call SQRTQ
    shr ax,2
    mov bx,16384
    add bx,ax
.sg: mov ax,di              ; y -= y*|y|*s*gs
    mov cx,ax
    or cx,cx
    jns .a
    neg cx
.a: imul cx
    shl ax,1
    rcl dx,1
    mov ax,dx
    imul bx
    shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    mov ax,dx
    imul word [TGS]
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
    cmp word [FXW],16384
    jz .st
    mov ax,dx
    mov bx,[es:si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
.st: mov [es:si],dx
    add si,2
    pop cx
    dec cx
    jz .x
    jmp .l
.x: ret
.of: call MIXOV
    jmp .j
FXSMP:              ; ax = sample -> processed sample
    mov [FXD],ax
    cmp byte [FXM],6        ; Karplus-Strong (render): 1024-word history ring
    jnz .nk
    imul word [KSIN]
    shl ax,1
    rcl dx,1
    mov ax,dx
    mov bx,[KSI]
    mov si,bx
    sub si,[KSP]
    dec si
    and si,1023
    shl si,1
    mov cx,[si+KSB]
    sar cx,1
    add si,2
    and si,2047
    mov dx,[si+KSB]
    sar dx,1
    add ax,0                ; (x in ax)
    push ax
    mov ax,cx
    add ax,dx
    imul word [KSFB]
    shl ax,1
    rcl dx,1
    pop ax
    add dx,ax
    jno .ko
    mov dx,0x7fff
    or ax,ax
    jns .ko
    mov dx,0x8000
.ko: shl bx,1
    mov [bx+KSB],dx
    shr bx,1
    inc bx
    and bx,1023
    mov [KSI],bx
    mov ax,dx
    jmp .mix
.nk:
    cmp byte [FXM],3        ; linear crush with DeFreq hold
    jnz .np
    add ax,[CHALF]
    jno .cm
    mov ax,0x7fff
.cm: and ax,[CMASK]
    cmp word [FXPOS],1
    jge .ch
    mov cx,[FXFREQ]
    mov [FXPOS],cx
    mov [FXHELD],ax
.ch: dec word [FXPOS]
    mov ax,[FXHELD]
    jmp .mix
.np: cmp byte [FXM],0
    jz .pk
    call THS
    cmp byte [FXM],1
    jz .mix
.pk: call PKS
.mix: imul word [FXW]
    push dx
    push ax
    mov ax,16384
    sub ax,[FXW]
    imul word [FXD]
    pop bx
    add ax,bx
    pop bx
    adc dx,bx
    shr ax,14
    shl dx,2
    or ax,dx
    ret
THS:                ; TapeHack: table with linear interpolation, odd symmetric
    mov cx,ax
    or ax,ax
    jns .p
    neg ax
.p: mov bx,ax
    shr bx,6
    and ax,63
    shl bx,1
    mov dx,[bx+THT+2]
    sub dx,[bx+THT]
    imul dx
    shr ax,6
    shl dx,10
    or ax,dx
    add ax,[bx+THT]
    or cx,cx
    jns .r
    neg ax
.r: ret
PKS:                ; Pockey2: mu-law DeRez, DeFreq hold, blur
    mov [FXA],ax
    call MU
    mov bx,ax               ; bx = q
    cwd
    mov cx,dx
    mov di,ax
    mov ax,[FXLAST]
    cwd
    sub di,ax
    sbb cx,dx
    jns .ab
    not cx
    neg di
    sbb cx,-1
.ab: mov ax,di              ; blur = 0.618 - |q - last| * overallscale (Q16), Q15 into si
    mul word [FXOS]
    shl ax,1
    rcl dx,1
    jc .z
    cmp dx,40503
    jae .z
    mov si,40503
    sub si,dx
    shr si,1
    jmp .h
.z: xor si,si
.h: cmp word [FXPOS],1
    jge .nh
    mov cx,[FXFREQ]
    mov [FXPOS],cx
    mov [FXHELD],bx
.nh: mov cx,[FXA]
    mov [FXLAST],cx
    dec word [FXPOS]
    or si,si
    jz .pv
    mov ax,si
    imul word [FXHELD]
    mov bx,ax
    mov cx,dx
    mov ax,32768
    sub ax,si
    imul word [FXPREV]
    add ax,bx
    adc dx,cx
    shl ax,1
    rcl dx,1
    mov ax,dx
    jmp .st
.pv: mov ax,[FXPREV]
.st: mov cx,[FXHELD]
    mov [FXPREV],cx
    ret
MU:                 ; mu-law encode, keep the top rez bits, decode (Pockey2), sign kept
    mov [FXSG],ax
    or ax,ax
    jnz .nz
    ret
.nz: jns .p
    neg ax
.p: mov dx,255
    mul dx
    add ax,32768
    adc dx,0
    xor bx,bx
.n: test dl,0x80
    jnz .nd
    shl ax,1
    rcl dx,1
    inc bx
    jmp .n
.nd: mov di,dx
    shl di,1
    test ax,0x8000
    jz .i0
    inc di
.i0: and di,0xff
    shl di,1
    shr ax,7
    and ax,0xff
    mov dx,[di+LOGT+2]
    sub dx,[di+LOGT]
    mul dx
    mov al,ah
    mov ah,dl
    add ax,[di+LOGT]
    mov dx,8
    sub dx,bx
    mov bx,dx
    shr dx,1
    and bx,1
    ror bx,1
    add ax,bx
    adc dx,0
    mov bx,dx               ; enc (Q16) = L * 16396 >> 16
    mov dx,16396
    mul dx
    mov di,dx
    mov ax,bx
    mov dx,16396
    mul dx
    add ax,di
    adc dx,0
    or dx,dx
    jnz .full
    and ax,[FXMASK]
    push ax
    mov bx,ax
    shr bx,5
    and bx,0xff
    shl bx,1
    shl ax,3
    and ax,0xf8
    mov dx,[bx+DEXT+2]
    sub dx,[bx+DEXT]
    mul dx
    mov al,ah
    mov ah,dl
    add ax,[bx+DEXT]
    add ax,32768
    pop cx
    mov cl,ch
    shr cl,5
    xor dx,dx
    or cl,cl
    jz .s
.sh: shl ax,1
    rcl dx,1
    dec cl
    jnz .sh
.s: sub ax,32768
    sbb dx,0
    mov bx,255
    div bx
    cmp ax,32767
    jbe .sg
.full: mov ax,32767
.sg: test word [FXSG],0x8000
    jz .r
    neg ax
.r: ret
FXOST: dw 53498,26749,13375,6687
FXFTT: dw 54772,27386,13693,6846
S_FR: db 'BITS 12',0
S_FD: db 'DEFREQ 000',0
S_FI: db 'INPUT x010 ',0     ; (+10 is written: keep one space)
S_FO: db 'OUTPUT 100%',0
S_FX: db 'MIX 100%',0
S_FW: db 'RENDERING...',0
S_L1: db 'LIVE FX ON',0
S_L0: db 'LIVE FX OFF',0
S_LP: db 'LIVE: NO POCKEY',0
S_KN: db 'KS NOTE 000',0
S_KF: db 'KS FDBK 000%',0
S_TP: db 'TUBE PAD 000%',0
S_TA: db 'TUBE AMT 000%',0
S_LC: db 'LIVE: COPYING..',0
S_LR: db 'LIVE RELEASED',0
S_LI: db 'LIVE OFF: CLEAN',0
S_RF: db 'RING 0000.0HZ',0
S_RS0: db 'RING SINE',0
S_RS1: db 'RING SQUARE',0
S_LM: db 'LIVE: NO MEMORY',0
S_LV: db 'LIVE: NO VOICE',0
S_FT: db '00000/S 000.0S',0
%include "fxtab.inc"
%include "ringtabk.inc"
%include "kstab.inc"
%include "sqtab.inc"
