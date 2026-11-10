cpu 186
bits 16
org 0x6000
%macro APIC 2
    push word %1
    call L6004
    add sp,2+%2
%endmacro
STATE equ 0x8018
LASTCC equ 0x8019
BUF equ 0x8020
ORIG equ 0x80D0
LASTV equ 0x80DA
NE equ 0x80DC
SS2 equ 0x80E0
MODE equ 0x8000
ERRC equ 0x8001
FLAG equ 0x8003
AEL equ 0x80F0
AEH equ 0x80F2
REF equ 0x80F4
ADL equ 0x80F6
ADH equ 0x80F8
CNTV equ 0x80FA
GSAVE equ 0x80E8
RST equ 0x8010
LEN equ 0x8012
PREADY equ 0x8014
AFL equ 0x8015
APB equ 0x80FC
ASV equ 0x80FE
LBUF equ 0x8100
LSV equ 0x8140
LIDX equ 0x8142
PBSV equ 0x8150
PNEG2 equ 0x8152
E00SV equ 0x8154
PBFIX equ 0x8156
LK equ 0x8158
ESNAP equ 0x8170
LSTEP equ 0x815A
LRATE equ 0x81A0
LDEPTH equ 0x81A1
LSHAPE equ 0x81A2
LDEST equ 0x81A3
LMODE equ 0x81A4
LYOUNG equ 0x81A5
LTM2 equ 0x81A6
LPH2 equ 0x81A8
LOUT equ 0x81AA
LRND equ 0x81AC
LCNT equ 0x81AE
LCLKT equ 0x81B0
LCLKL equ 0x81B2
LB74 equ 0x81B4
LPREV equ 0x81B6
LSHV equ 0x81B8
LDONE equ 0x81B9
LWARB equ 0x81BA
RVP equ 0x81C0
G6 equ 0x81C2
NARM equ 0x81E0
NPK equ 0x81E2
NG equ 0x81E4
NCNT equ 0x81E6
NBANK equ 0x81EA
CHN equ 0x81EC
CHARM equ 0x81ED
DARM equ 0x81EE
CHCNT equ 0x81EF
CHBANK equ 0x81F0
CHPLAY equ 0x81F2
DFCSV equ 0x81F4
CHL equ 0x81F6
CHSRC equ 0x81FA
CHI equ 0x81FE
CHV equ 0x8200
CHSB equ 0x8240
CHDB equ 0x8241
ZCM equ 0x8242
TSENS equ 0x8243
NBND equ 0x8244
TFAST equ 0x8246
TSLOW equ 0x8248
THOLD equ 0x824A
TGAP equ 0x824C
TCNT equ 0x824E
SBND equ 0x8280
CHWHY equ 0x8250
CHOWN equ 0x8252
LRAW equ 0x8254
CBITS equ 0x8256
CARM equ 0x8257
CMASK equ 0x8258
CHALF equ 0x825A
    jmp near ENTRY
    retf
L6004:
    pop word [0x55f6]
    int3
    push word [0x55f6]
    ret
ENTRY:
    mov [cs:SAVSP],sp
    mov [cs:SAVBP],bp
    mov [cs:SAVDS],ds
    mov [cs:SAVES],es
    mov sp,0xeffe
    call MAIN0
    mov sp,[cs:SAVSP]
    mov bp,[cs:SAVBP]
    mov ds,[cs:SAVDS]
    mov es,[cs:SAVES]
    retf
SAVSP: dw 0
SAVBP: dw 0
SAVDS: dw 0
SAVES: dw 0
MAIN0:
    mov di,0x6400
    mov bx,18
.ld: push bx
    push di
    push word 0
    push di
    push bx
    push word 0xbf
    call L6004
    add sp,8
    pop di
    pop bx
    or ax,ax
    jnz .bad
    add di,0x400
    cmp di,0x8000           ; sectors 25-37 load above the variables (8400h)
    jnz .ld2
    add di,0x400
.ld2: cmp di,0xc000             ; sectors 38-39 at B800h (code from B900h), 40-43 at DC00h
    jnz .ld4
    mov di,0xdc00
.ld4: inc bx
    cmp bx,44
    jb .ld
    cmp word [SIG],0x3750
    jnz .bad
    mov byte [L6004],0xe9   ; loaded: FZ calls now go through L6004X (fx/fx4.asm)
    mov word [L6004+1],L6004X-(L6004+3)
    jmp CAPINIT             ; PERF38Q: capture flag cleared, then MAIN
.bad:
    mov bx,S_LE
    xor cx,cx
    mov dx,6
    call PRT
    mov cx,200
.w: call L6398a
    loop .w
    push word 7
    push word 0
    push word 0x57
    call L6004
    add sp,6
    ret
L6398a:
    push cx
    mov cx,0x3000
.l: nop
    loop .l
    pop cx
    ret
PRT:
    push cs
    push bx
    push cx
    push dx
    push word 0
    push word 0xa2
    call L6004
    add sp,12
    ret
S_LE: db 'LOAD ERR',0
MAIN:
    mov word [CURV],0
    call MINIT
    call MXINIT
    mov byte [MODE],1
    mov byte [0x8002],0xff
    mov bx,S_TITLE
    mov cx,1
    xor dx,dx
    call PRT
    mov byte [RST],0
    mov byte [AFL],0
    mov byte [PREADY],0
    mov word [LEN],50
    mov byte [LRAW],4
    mov byte [CBITS],8
    mov byte [CARM],0
    call FXINIT
    call PBGET
    push es
    push ds
    pop es
    cld
    mov di,LRATE
    xor ax,ax
    mov cx,0x20
    rep stosw
    pop es
    mov word [LOUT],0x8000
    mov word [LRND],0x1234
    mov byte [CHN],8
    mov byte [ZCM],1
    mov byte [TSENS],64
    mov byte [CHARM],0
    mov byte [DARM],0
    mov byte [CHCNT],0
    mov word [CHBANK],0
    mov word [CHOWN],0
    mov byte [CHPLAY],0
    mov word [CHOKV],0xff   ; PERF40A: choke off, slice 1
    mov byte [CPARM],1
    mov word [VPICK],0x00ff ; PERF40H: no voice picked, no remote exit
    mov byte [L7F],0
    mov byte [KEEPA],0      ; PERF40I: ENTER keeps the sound only (as before) until Gills says otherwise
    xor ax,ax               ; PERF40J: chops into their own bank; no target-bank chop
    mov [CHTO],ax
    mov [CHBASE+1],ax
    mov [0x801A],ax         ; PERF40L: STRETCH next TRACE, order FORWARD,
    mov word [0x801C],64    ; skew even; PERF40M: start not moved (STMV)
    mov word [STN],0x407F   ; PERF40F STRETCH: 8 segments, stretch 64, grain 100%
    mov word [STG],0x007F   ; crossfade 0
    mov word [STZ],0x007F   ; snap on, sustain none, off
    mov ax,[0xdfc]
    mov [DFCSV],ax
    mov ax,[0x40a]
    mov [LTM2],ax
    mov byte [0x4d9],0
    mov byte [0x4d6],0x40
    call L61DB
    cmp word [si+0x10],0
    jz .emp
    mov byte [RETN],1       ; existing voice: keep its filter and envelopes
    call PSETUP
    mov byte [RETN],0
    call CHFINDO
    jmp .nt
.emp:
    mov bx,S_E
    xor cx,cx
    mov dx,7
    call PRT
    mov byte [L7F],1
.nt: call STAT2             ; PERF40H: line 2 = the voice (or bank) being edited                        ; (PERF38E: no start-up audition note, no fixed output writes)
    mov ax,[0x9d8]
    mov [cs:0x8016],ax
    mov byte [cs:STATE],0
.lp:
    call L6372
    cmp ax,1
    jz done
    cmp ax,2
    jz keep
    mov al,[RST]
    cmp al,1
    jb .np
    cmp al,3
    ja .np
    call UPOLL
    cmp byte [RST],2
    jnz .n3
    cmp byte [0x4d7],3
    jnz .np
    mov byte [RST],3
    call SHOWR
.n3:
    cmp byte [RST],3
    jnz .np
    call ENDCHK
.np:
    call CAPTICK            ; PERF38M: capture mode, then LFOALL
    call MATRIX
    call RVPATCH
    call LVRUNX             ; PERF38H: paced LCD, curve steps, then live FX
    call PARSE
    jc .idle
    call MROUTE             ; bank CCs; bank mode: edit the voice on this CC's channel
    jnc .mr
    jmp .lp
.mr:
    push ax
    call DISPATCH
.sk:
    pop ax
    call ECHOF              ; PERF38I: decimal echo, only for controls without their own message
    jmp .lp
.idle:
    mov al,[RST]
    cmp al,1
    jb .slow
    cmp al,3
    ja .slow
    mov cx,0x800
.fp: call UPOLL
    loop .fp
    jmp .lp
.slow:
    call ENDW
    cmp byte [LVON],0       ; live TapeHack: no idle delay, keep rendering
    jnz .lp
    call L6398              ; pattern only stepped every 25 ms when nothing else was happening)
    jmp .lp
keep:
    call CAPMX              ; PERF38M: capture mode off, then MXOFF
    call LVOFF
    mov al,0
    call MRESTORE
    call RABORT
    cmp byte [PREADY],0
    jz tail2
    call L61DB
    cmp byte [KEEPA],0      ; PERF40I: ENTER KEEPS ALL (set from Gills): loops, start / end and play mode stay as edited
    jnz tail2
    test byte [STSU],0x80   ; PERF40H: STRETCH on: its loops are kept (not put back from PERF's copy)
    jnz tail
    push si
    lea di,[si+0x14]
    mov si,BUF
    mov cx,0x40
    call MOVB
    pop si
    jmp tail
done:
    call CAPMX              ; PERF38M: capture mode off, then MXOFF
    call EFREST
    call LVOFF
    mov al,1
    call MRESTORE
    call RABORT
    call UNASSIGN
    cmp byte [PREADY],0
    jz tail2
    call L61DB
    mov al,1
    call COPY
    mov ax,[LSV]
    mov [si+0x12],ax
tail:
    mov ax,[ORIG]
    mov [si+0x10],ax
    mov cx,4
    xor bx,bx
.r: mov ax,[bx+GSAVE]
    mov [si+bx+8],ax
    add bx,2
    loop .r
tail2:
    call LFOOFF
    cmp byte [PBFIX],0
    jz .nf
    mov ax,[PNEG2]
    mov [0xdfe],ax
    mov ax,[E00SV]
    mov [0xe00],ax
    mov byte [PBFIX],0
    mov ax,[DFCSV]
    mov [0xdfc],ax
.nf:
    push ds
    pop es
    mov byte [0x42c],0
    call L62D5
    push word 7
    push word 0
    push word 0x57
    call L6004
    add sp,6
    ret
COPY:
    push si
    lea di,[si+0x14]
    mov si,BUF
    or al,al
    jnz .go
    xchg si,di
.go:
    mov cx,0x9e
    call MOVB
    pop si
    ret
INIT:
    mov [si+0x76],ax
    mov bx,INITT
    mov cx,16
.i: mov dl,[cs:bx]
    xor dh,dh
    add dx,si
    mov di,dx
    mov al,[cs:bx+1]
    mov [di],al
    add bx,2
    loop .i
    ret
WRITE:
    mov dl,[cs:LASTCC]
    xor dh,dh
    mov bx,dx
    cmp byte [PRAW],0       ; parameter path (CC10/11): plain store, no filters
    jnz .wr
    cmp dl,70
    jae .ded
    mov bx,IGN
    mov cx,13
.i: cmp dl,[cs:bx]
    jz .ret
    inc bx
    loop .i
    cmp dl,66
    jb .wr
    cmp dl,68
    jbe .kc
.wr:
    sub dl,10
    mov bx,dx
    mov [bx+si+0x76],al
.ret:
    ret
.kc:              ; CC66 highest
    cmp byte [BKON],0
    jz .kcv
    jmp BKKEY
.kcv:              ; (+AEh), CC67 lowest (+AFh), CC68 original (+B0h); keep lowest<=orig<=highest, within 3 octaves
    and al,0x7f
    cmp dl,66
    jnz .k1
    mov [si+0xae],al
    jmp .cl
.k1: cmp dl,67
    jnz .k2
    mov [si+0xaf],al
    jmp .cl
.k2: mov [si+0xb0],al
.cl: mov al,[si+0xb0]
    and al,0x7f
    mov [si+0xb0],al
    mov ah,[si+0xae]
    cmp ah,al
    jae .h1
    mov ah,al
.h1: mov bl,al
    add bl,36
    cmp bl,127
    jbe .h2
    mov bl,127
.h2: cmp ah,bl
    jbe .h3
    mov ah,bl
.h3: mov [si+0xae],ah
    mov ah,[si+0xaf]
    cmp ah,al
    jbe .l1
    mov ah,al
.l1: mov bl,al
    sub bl,36
    jnc .l2
    xor bl,bl
.l2: cmp ah,bl
    jae .l3
    mov ah,bl
.l3: mov [si+0xaf],ah
    ret
.ded:
    cmp bl,86
    jb .d0
    jmp LMSG            ; FZED: CC86 also names the loop mode
.d0:
    cmp bl,78
    jae .env
    cmp bl,76
    jae .se
    cmp bl,73
    jae .rawd
    cmp bl,72
    jz .xf
    cmp bl,71
    jz .sr
    shr al,5
    mov bx,[ORIG]
    or al,al
    jz .mw
    mov bx,0x101d
    cmp al,1
    jz .mw
    mov bx,0x2014
.mw:
    mov [si+0x10],bx
    jmp PMSG            ; FZED: name the play mode
.sr:
    shr al,5
    mov [si+0xb1],al
    ret
.rawd:
    sub bl,73
    mov bl,[cs:bx+RT]
    mov [bx+si],al
    ret
.se:
    cmp bl,76
    jnz .en
    call RNG
    mul bx
    add ax,[GSAVE]
    adc dx,[GSAVE+2]
    mov [si+8],ax
    mov [si+10],dx
    ret
.en:
    call INV            ; 127 = full length, lower = shorter
    call RNG
    mul bx
    mov bx,ax
    mov ax,[AEL]
    mov cx,[AEH]
    sub ax,bx
    sbb cx,dx
    mov [si+12],ax
    mov [si+14],cx
    mov [NE],ax
    mov [NE+2],cx
    jmp SLIDEALL
.xf:
    xor ah,ah
    shl ax,3
    push es
    push ds
    pop es
    cld
    lea di,[si+0x54]
    mov cx,8
    rep stosw
    pop es
    ret
.env:
    sub bl,78
    call ENVFIX             ; ADSR controls: sustain on step 2, end on step 3 (as at start)
    lea di,[si+0x7a]
    test bl,4
    jz .g0
    add di,0x12
.g0:
    and bl,3
    mov dl,[cs:bx+ENVT]
    xor dh,dh
    add di,dx
    cmp bl,2
    jnz .e1
    shl al,1
    jmp .st
.e1:
    xor al,0x7f
    jnz .e2
    inc al
.e2:
    or bl,bl
    jz .st
    or al,0x80
.st:
    mov [di],al
    ret
SLIDEALL:           ; voice loops = LBUF loops slid so that no loop end passes NE
    xor bx,bx
    mov cx,8
.sl: push cx
    mov ax,[bx+LBUF+0x20]
    mov dx,[bx+LBUF+0x22]
    and dx,0x1f
    sub ax,[NE]
    sbb dx,[NE+2]
    jc .s0
    mov cx,ax
    or cx,dx
    jz .sp
    add ax,16
    adc dx,0
    jmp .sp
.s0: xor ax,ax
    xor dx,dx
.sp: mov [SS2],ax
    mov [SS2+2],dx
    mov di,0x20
    call SLD
    xor di,di
    call SLD
    pop cx
    add bx,4
    loop .sl
    cmp word [si+0x12],0x0808   ; PERF40N: ONE-SHOT: loop 0 stays parked (an end / loop point / window move used to
    jnz .r                  ; put a real loop 0 back, and the FZ's note start loops it: one-shot didn't 'take')
    jmp ..@PARK0
.r: ret
LOOPCC:             ; bl = 86 loop mode, 87 loop start, 88 loop end, 126 loop window
    cmp bl,126
    jnz .n126
    jmp LOOPWIN
.n126: cmp bl,86
    jnz .pt
    cmp al,43
    jb .one
    cmp al,85
    jb .org
    mov al,[LIDX]
    mov [si+0x12],al
    mov [si+0x13],al
    jmp .tim
.org:
    push si                 ; FZED: ORIGINAL also puts the loop points back (PERF's copy from when the voice was set up)
    mov si,BUF
    mov di,LBUF
    mov cx,0x40
    call MOVB
    pop si
..@ORGKEEP:         ; STRETCH OFF enters here: sustain / end loop and loop times back, the edited loop points kept
    mov ax,[LSV]
    mov [si+0x12],ax
.tim:
    push si
    lea di,[si+0x64]
    mov si,BUF+0x50
    mov cx,16
    call MOVB
    pop si
    jmp SLIDEALL        ; restore loop points (one-shot parked loop 0)
.one:
    mov word [si+0x12],0x0808
    push es
    push ds
    pop es
    cld
    lea di,[si+0x64]
    xor ax,ax
    mov cx,8
    rep stosw
    pop es
..@PARK0:
    mov ax,[GSAVE+4]    ; park loop 0 at the sample's original end, no loop flags,
    mov dx,[GSAVE+6]    ; so the FZ's note-start loop setup can never loop a one-shot
    and dx,0x1f
    mov [si+0x14],ax
    mov [si+0x16],dx
    mov [si+0x34],ax
    mov [si+0x36],dx
    ret
.pt:
    cmp bl,88
    jnz .pt2
    call INV            ; loop end: 127 = sample end, lower = earlier
.pt2:
    push bx
    call RNG
    cmp bx,16
    jae .st
    mov bx,16
.st: mov [LSTEP],bx     ; minimum loop length = one control step (avoids tiny whining loops)
    mul bx
    pop cx
    xor bh,bh
    mov bl,[LIDX]
    shl bx,2
    cmp cl,87
    jnz .le
    add ax,[GSAVE]
    adc dx,[GSAVE+2]
    xor di,di               ; PERF38Z: (flags unused at .wr)
    jmp .wr
.le:
    mov cx,dx
    mov dx,ax
    mov ax,[AEL]
    sub ax,dx
    mov dx,[AEH]
    sbb dx,cx
    mov di,0x20
.wr:                ; LBUF[di+bx] = dx:ax (keep flag bits), then keep start < end-16
    push bx
    add bx,di
    mov cx,[bx+LBUF+2]
    and cx,0xffe0
    and dx,0x1f
    or dx,cx
    mov [bx+LBUF],ax
    mov [bx+LBUF+2],dx
    pop bx
    mov ax,[bx+LBUF+0x20]
    mov dx,[bx+LBUF+0x22]
    and dx,0x1f
    sub ax,[LSTEP]
    sbb dx,0
    jnc .e16
    xor ax,ax
    xor dx,dx
.e16:
    mov cx,[bx+LBUF+2]
    and cx,0x1f
    cmp cx,dx
    jb .ok
    ja .fix
    mov cx,[bx+LBUF]
    cmp cx,ax
    jb .ok
.fix:
    and dx,0x1f
    mov cx,[bx+LBUF+2]
    and cx,0xffe0
    or dx,cx
    mov [bx+LBUF],ax
    mov [bx+LBUF+2],dx
.ok:
    jmp SLIDEALL
SLD:                ; voice[0x14+di+bx] = BUF[di+bx] - SS2 (21-bit, keep hi bits 15..5)
    push bx
    add bx,di
    mov ax,[bx+LBUF]
    mov dx,[bx+LBUF+2]
    mov cx,dx
    and dx,0x1f
    and cx,0xffe0
    sub ax,[SS2]
    sbb dx,[SS2+2]
    jnc .ok
    xor ax,ax
    xor dx,dx
.ok: and dx,0x1f
    or dx,cx
    mov [bx+si+0x14],ax
    mov [bx+si+0x16],dx
    pop bx
    ret
PSETUP:
    call L61DB
    xor al,al
    call COPY
    mov ax,[si+0x10]
    mov [ORIG],ax
    mov cx,4
    xor bx,bx
.g: mov ax,[si+bx+8]
    mov [bx+GSAVE],ax
    add bx,2
    loop .g
    cmp byte [RETN],0
    jnz .ret
    mov ax,0x007f           ; INIT: cutoff 127, resonance 0
    call INIT
.ret: mov ax,[GSAVE+4]
    mov [AEL],ax
    mov ax,[GSAVE+6]
    mov [AEH],ax
    mov ax,[GSAVE+4]
    mov [NE],ax
    mov ax,[GSAVE+6]
    mov [NE+2],ax
    mov di,LBUF
    call CP40
    mov ax,[si+0x12]
    mov [LSV],ax
    cmp al,8
    jb .li
    mov al,ah
    cmp al,8
    jb .li
    xor al,al
.li: mov [LIDX],al
    mov byte [PREADY],1
    ret
AFTER:
    call PSETUP
    call ASSIGN
    cmp byte [PBFIX],0
    jz .r
    call VDIRECT
.r: ret
PBGET:              ; PBSV = play-bank pointer; then play the edit voice directly (voice's own original/highest/lowest)
    mov ax,[0xdfe]
    mov [PNEG2],ax
    mov ax,[0xe00]
    mov [E00SV],ax
    mov ax,[0xdfe]
    or ax,ax
    jz .calc
    js .calc
    mov [PBSV],ax
    jmp VDIRECT
.calc:
    xor ax,ax
    mov [PBSV],ax
    mov ax,[0xdfc]
    cmp ax,8
    jae VDIRECT
    mov cx,0x290
    mul cx
    add ax,0xe08
    mov [PBSV],ax
VDIRECT:
    mov word [0xdfe],0xffff
    mov word [0xe00],0xffff
    mov byte [PBFIX],1
    ret
ASSIGN:
    call L61DB
    mov bx,[PBSV]
    or bx,bx
    jle .r                  ; (PERF39E: none, or not a bank)
    cmp bx,[BKBANK]         ; PERF39E: never put a new take into the bank FZED is building
    jz .r
    cmp word [bx],0
    jz .r
    cmp byte [AFL],0
    jnz .s
    mov ax,[bx+0x202]
    mov [ASV],ax
    mov [APB],bx
    mov byte [AFL],1
.s: mov [bx+0x202],si
.r: ret
UNASSIGN:
    cmp byte [AFL],0
    jz .r
    mov bx,[APB]
    mov ax,[ASV]
    mov [bx+0x202],ax
    mov byte [AFL],0
.r: ret
RABORT:
    mov al,[RST]
    cmp al,1
    jb .r
    cmp al,3
    ja .r
    call ABORT
.r: ret
UPOLL:
    in al,0xd2
    test al,0x38
    jz .ne
    mov al,0x15
    out 0xd2,al
.ne:
    in al,0xd2
    test al,2
    jz .r
    in al,0xd0
    mov si,[0x9d8]
    mov [si+0x8d6],al
    inc byte [0x9d8]
.r: ret
; recording finished when generators 0 and 1 have stopped (as rec_do)
ENDCHK:
    push word 1
    APIC 49,2
    test bl,1
    jnz .r
    push word 0
    APIC 49,2
    test bl,1
    jnz .r
    call STOP
    mov si,[0xe04]
    mov word [si+0x10],0x1d7
    mov byte [RST],4
    call AFTER
    call SHOWR
.r: ret
STOP:
    push word 0x100
    push word [0xe06]
    push word [0xe04]
    APIC 47,6
    ret
ABORT:
    call STOP
    call WDEL
    mov byte [RST],0
    ret
WDEL:
    push si
    mov si,[0xe04]
    call SHARED
    jnz .del
    pusha                   ; PERF40A: shared wave: only this voice forgets it (addresses and mode cleared)
    push es
    push ds
    pop es
    cld
    mov di,si
    xor ax,ax
    mov cx,9
    rep stosw
    pop es
    popa
.del: pop si
    jz .r
    push word [0xe06]
    push word [0xe04]
    APIC 119,4
.r: ret
RWRITE:
    mov dl,[cs:LASTCC]
    cmp dl,102
    jnz .c3
    shr al,5                ; 0-3: 36k / 18k / 9k / 4.5k (experimental)
    mov [0x4d9],al
    jmp .lc
.c3: cmp dl,103
    jnz .c4
    mov [LRAW],al
.lc:            ; LEN = (CC103+1) x 0.1 s, doubled for each halving of the rate
    mov al,[LRAW]
    xor ah,ah
    inc ax
    shl ax,1
    mov bx,ax
    shl ax,2
    add ax,bx
    mov cl,[0x4d9]
    shl ax,cl
    mov [LEN],ax
    ret
.c4: cmp dl,104
    jnz .c5
    shr al,6
    mov [0x4d8],al
    xor ah,ah
    push ax
    APIC 48,2
    ret
.c5: cmp dl,105
    jnz .c6
    shl al,1
    mov [0x4d6],al
    ret
.c6: cmp dl,106
    jnz .c7
    cmp al,64
    jb .ret
    cmp byte [BKON],0       ; recording only in voice mode
    jz .vmr
    mov bx,S_RS
    jmp NMSG
.vmr:
    push ax                 ; arming: live TapeHack off first (memory)
    push dx
    call LVOFF
    pop dx
    pop ax
    mov ah,[RST]
    cmp ah,1
    jb .a0
    cmp ah,3
    jbe .ret
.a0: mov si,[0xe04]
    cmp word [si+0x10],0
    jz .a1
    cmp byte [RST],4
    jz .a0d
    cmp al,120
    jb .used
.a0d:
    call WDEL
.a1: mov ax,[LEN]
    mov [0x4da],ax
    mov bx,360
    mul bx
    mov cl,[0x4d9]

.sh: or cl,cl
    jz .a2
    shr dx,1
    rcr ax,1
    dec cl
    jmp .sh
.a2: push dx
    push ax
    push word [0xe06]
    push word [0xe04]
    APIC 117,8
    or bx,bx
    jnz .mem
    push word 0x100
    push word [0xe06]
    push word [0xe04]
    APIC 45,6
    cmp byte [0x4d9],3      ; 4.5k: the FZ sets the anti-alias filter for 18k; lower it an octave below 9k
    jnz .f45
    mov al,0x5c
    out 0xbe,al
.f45: call NFAP              ; PERF39A: the CC110 NORM FILTER / cutoff choice over the rate's defaults
    mov byte [RST],1
.ret: ret
.used: mov byte [RST],5
    ret
.mem: mov byte [RST],6
    ret
.c7: cmp dl,107
    jnz .c8
    cmp al,64
    jb .ret
    cmp byte [RST],1
    jnz .ret
    APIC 46,0
    mov byte [RST],3
    mov byte [0x4d7],3
    ret
.c8: cmp dl,108
    jnz .c9
    cmp al,64
    jb .ret
    cmp byte [RST],1
    jz .c8a
    mov bx,S_NARM           ; PERF40K: not armed: say so (it used to start capture mode, which deletes the voice; capture
    cmp byte [RST],5        ; now comes from Gills' CAPTURE view, control 7)
    jnz .c8m
    mov bx,S_USD            ; (the voice has a sample and ARM was below 120)
.c8m: jmp NMSG
.c8a:
    mov byte [RST],2
    mov byte [0x4d7],2
    ret
.c9: cmp dl,110
    jnz .c9b
    or al,0x80              ; PERF39A: kept (NFV) and put back after every record setup; bands pick the cutoff
    mov [NFV],al
    jmp NFAP
.c9b: cmp al,64
    jb .ret
    mov al,[RST]
    cmp al,1
    jb .ret
    cmp al,3
    ja .ret
    jz .keep
    jmp ABORT
.keep:
    call STOP
    mov si,[0xe04]
    mov word [si+0x10],0x1d7
    mov byte [RST],4
    jmp AFTER
SHOWR:              ; PERF40H, plain values. Line 5 'REC 36K  012.8S' (rate, length), line 6 'ARMED -20DB T127' (state,
    mov bl,[0x4d9]          ; input gain, auto-trigger level)
    and bx,3
    shl bx,2
    mov ax,[cs:bx+RATT]
    mov [S_P+4],ax
    mov ax,[cs:bx+RATT+2]
    mov [S_P+6],ax
    mov ax,[LEN]            ; centiseconds -> 'ddd.d'
    xor dx,dx
    mov cx,10
    div cx
    xor dx,dx
    div cx
    add dl,'0'
    mov [S_P+13],dl
    xor dx,dx
    mov di,S_P+11
    mov cx,3
    call DECN
    mov bx,S_P
    xor cx,cx
    mov dx,5
    call PRT
    mov al,[RST]
    mov ah,6
    mul ah
    add ax,S_ST
    mov si,ax
    mov di,S_L6
    mov cx,5
    call MOVB
    mov si,S_G0
    cmp byte [0x4d8],0
    jz .g
    mov si,S_G0+5
.g: mov di,S_L6+6
    mov cx,5
    call MOVB
    mov al,[0x4d6]
    mov di,S_L6+13
    call DEC3
    mov bx,S_L6
    xor cx,cx
    mov dx,6
    jmp PRT
RATT: db '36K 18K 9K  4.5K'
S_G0: db '  0DB-20DB'
S_L6: db 'IDLE    0DB T064',0
WRITEL:             ; WRITE, then push the change to notes already playing this voice
    jmp PSW                 ; PERF40G: filter / envelope / LFO 1 can go to the chosen chop slice
WRITEL0:
    push ax
    call L61DB
    push si
    lea si,[si+0x7a]
    mov di,ESNAP
    mov cx,0x22
    call MOVB
    pop si
    pop ax
    call WRITE
    call L61DB
    call ENVDIR
    call SNAPV
    call CHPROP
    mov di,0x5420
    mov dl,1
.g: cmp byte [di],0xff
    jz .n
    cmp [di+0xa],si
    jz .mine
    call ISSLICE            ; a chop slice of this voice: envelope changes only
    jnz .n
    push si
    push dx
    push di
    mov si,[di+0xa]
    call LENV
    pop di
    push di
    call LSUS
    pop di
    pop dx
    push dx
    push di
    mov al,[cs:LASTCC]
    cmp al,72
    jz .sl
    cmp al,126
    jz .sl
    cmp al,87
    jb .sx
    cmp al,88
    ja .sx
.sl: call LLOOP
.sx: pop di
    pop dx
    pop si
    jmp .n
.mine:
    push dx
    push di
    call LENV
    pop di
    push di
    mov al,[cs:LASTCC]
    cmp al,78
    jb .s1
    cmp al,85
    jbe .s2
.s1: cmp al,12
    jb .s3
    cmp al,47
    ja .s3
.s2: call LSUS
.s3: pop di
    pop dx
    mov al,[cs:LASTCC]
    cmp al,72
    jz .lp
    cmp al,77
    jz .lp
    cmp al,126
    jz .lp
    cmp al,87
    jb .n
    cmp al,88
    ja .n
.lp: push dx
    push di
    call LLOOP
    pop di
    pop dx
.n: add di,0x3a
    shl dl,1
    jnz .g
    ret
LENV:               ; add (new - old) voice envelope bytes to this note's copies
    xor bx,bx
.e: mov al,[si+bx+0x7a]
    xor ah,ah
    mov cl,[bx+ESNAP]
    call LRMASK             ; PERF38I: rates without the direction bit
    sub ax,cx
    jz .nx
    mov cx,ax           ; signed delta -255..255
    mov al,bl           ; voice offset 7A+bx -> gene offset
    cmp al,8
    jb .dr              ; 7A..81 DCA rates -> +16
    cmp al,16
    jb .dl              ; 82..89 DCA levels -> +1E (+16)
    cmp al,18
    jb .nx              ; 8A/8B dcf sus/end: skip
    cmp al,26
    jb .fr              ; 8C..93 DCF rates -> +2A (-18+2A = +18)
    jmp .fl             ; 94..9B DCF levels -> +32 (+18)
.dr: mov ax,0x16
    jmp .rate
.dl: mov ax,0x16
    jmp .lev
.fr: mov ax,0x18
    jmp .rate
.fl: mov ax,0x18
.lev: push di
    add di,ax
    add di,bx
    xor ah,ah
    mov al,[di]
    add ax,cx
    jns .l1
    xor ax,ax
.l1: cmp ax,0xff
    jbe .l2
    mov al,0xff
.l2: mov [di],al
    pop di
    jmp .nx
.rate: push di
    add di,ax
    add di,bx
    mov al,[di]
    mov dh,al
    and dh,0x80
    and ax,0x7f
    add ax,cx
    cmp ax,1
    jge .r1
    mov ax,1
.r1: cmp ax,0x7f
    jle .r2
    mov ax,0x7f
.r2: or al,dh
    mov [di],al
    pop di
.nx: inc bx
    cmp bx,0x22
    jb .e
    ret
LSUS:               ; note holding at sustain: re-enter the sustain stage so a new level is reached
    mov bl,[di+0x14]
    cmp bl,[si+0x79]
    jz .f
    cmp [di+0x15],bl
    jbe .f
    cmp bl,8
    jae .f
    xor bh,bh
    mov al,[bx+di+0x1e]
    mov cl,[bx+di+0x16]
    and cl,0x7f
    cmp al,[di+0x13]
    jae .u
    or cl,0x80
.u: mov [bx+di+0x16],cl
    mov [di+0x15],bl
.f: mov bl,[di+0x28]
    cmp bl,[si+0x8b]
    jz .r
    cmp [di+0x29],bl
    jbe .r
    cmp bl,8
    jae .r
    xor bh,bh
    mov al,[bx+di+0x32]
    mov cl,[bx+di+0x2a]
    and cl,0x7f
    cmp al,[di+0x27]
    jae .v
    or cl,0x80
.v: mov [bx+di+0x2a],cl
    mov [di+0x29],bl
.r: ret
ENDW:               ; one-shot forward voice: stop generators that pass the (live) end point
    cmp byte [PREADY],0
    jz .r
    call L61DB
    test word [si+0x10],0xf000   ; forward voice (reverse 1xxxh, cue 2xxxh)
    jnz .r
    cmp word [si+0x12],0x0808
    jnz .r
    mov di,0x5420
    mov dl,1
.g: cmp byte [di],0xff
    jz .n
    cmp [di+0xa],si
    jnz .n
    cmp word [di+6],16  ; let the ROM finish starting the note first
    jb .n
    push dx
    push di
    call GAREAD
    jc .p
    mov ax,[si+0xe]
    and ax,0x1f
    cmp dx,ax
    jb .p
    ja .st
    cmp cx,[si+0xc]
    jb .p
.st: pop di
    pop dx
    push dx
    push di
    mov bx,0x200
    mov dh,0x42
    call GA2            ; stop this generator (as the ROM's kill does)
.p: pop di
    pop dx
.n: add di,0x3a
    shl dl,1
    jnz .g
.r: ret
GAREAD:             ; current address of generator (dl = mask) -> dx:cx, CF=1 timeout (ROM 1FE7)
    in al,0xe2
    push ax
    or al,4
    out 0xe2,al
    mov dh,0x80
    call GA1
    jc .x
    mov cx,3000
.w: in al,0x1a
    test al,1
    jnz .rd
    loop .w
    stc
    jmp .x
.rd: in ax,4
    mov dx,ax
    and dx,0x1f
    in ax,2
    mov cx,ax
    clc
.x: pop ax
    out 0xe2,al
    ret

LLOOP:              ; forward voice: resend end point and current loop to the generator (mask dl)
    test word [si+0x10],0xf000   ; forward voice (reverse 1xxxh, cue 2xxxh)
    jnz .r
    mov al,[di+0xe]
    mov [LK],al
    push dx
    mov bx,[si+0xc]
    mov cx,[si+0xe]
    and cx,0x1f
    mov dh,0x40
    call GA2            ; end point
    pop dx
    cmp word [si+0x12],0x0808   ; one-shot (no loops): never program a loop
    jz .r
    mov al,[di+0xf]
    and al,0x3f
    cmp [LK],al                 ; current loop beyond the note's target loop: none active
    ja .r
    xor bh,bh
    mov bl,[LK]
    cmp bl,8
    jae .r
    shl bx,2
    lea di,[bx+si]      ; di = voice + 4k (loop k entries)
    push dx
    mov ax,[di+0x14]
    mov bx,[di+0x16]
    mov cl,bh
    xor ch,ch
    and bx,0x1f
    mov dh,0x41
    call GA1            ; loop restart = loop start
    pop dx
    push dx
    mov ax,[di+0x34]
    mov bx,[di+0x36]
    and bx,0x1f
    mov cx,[di+0x16]
    and cx,0x1f
    sub ax,[di+0x14]
    sbb bx,cx
    shr bx,1
    rcr ax,1
    xor cx,cx
    mov dh,0x43
    call GA1            ; loop length / 2
    pop dx
    push dx
    mov bx,[di+0x34]
    mov cx,[di+0x36]
    and cx,0x1f
    mov dh,0x41
    call GA2            ; loop trigger = loop end
    pop dx
    cmp byte [cs:LASTCC],72
    jnz .r
    xor bh,bh
    mov bl,[LK]
    shl bx,1
    mov ax,[bx+si+0x54]
    mov bx,[si+0x10]
    or ax,ax
    jnz .x
    and bx,0xbf
.x: mov dh,0x42
    call GA2            ; mode: crossfade on/off (bit 6) as at note start
.r: ret
GA1:                ; gate array group 1 (ROM 1A30): ax->0 bx->2 cx->4 dx->6. CF=1 timeout
    push si
    push di
    mov si,ax
    mov di,3000
.t: in al,0xe2
    push ax
    or al,5
    out 0xe2,al
    in al,0x1a
    test al,1
    jnz .go
    pop ax
    out 0xe2,al
    dec di
    jnz .t
    pop di
    pop si
    stc
    ret
.go: mov ax,si
    out 0,ax
    mov ax,bx
    out 2,ax
    mov ax,cx
    out 4,ax
    mov ax,dx
    out 6,ax
    pop ax
    out 0xe2,al
    pop di
    pop si
    clc
    ret
GA2:                ; gate array group 2 (ROM 1A5B): bx->8 cx->A dx->E. CF=1 timeout
    push di
    mov di,3000
.t: in al,0xe2
    push ax
    or al,5
    out 0xe2,al
    in al,0x1a
    test al,2
    jnz .go
    pop ax
    out 0xe2,al
    dec di
    jnz .t
    pop di
    stc
    ret
.go: mov ax,bx
    out 8,ax
    mov ax,cx
    out 0xa,ax
    mov ax,dx
    out 0xe,ax
    pop ax
    out 0xe2,al
    pop di
    clc
    ret
INV:                ; al = 127 - al, never 127 (keep at least one step of length)
    mov ah,127
    sub ah,al
    mov al,ah
    cmp al,127
    jb .r
    mov al,126
.r: ret
RTB:                ; MIDI realtime byte: F8 clock, FA start
    cmp al,0xf8
    jnz .fa
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[LCLKL]
    mov [LCLKT],ax
    mov [LCLKL],dx
    inc word [LCNT]
    cmp word [LCNT],384
    jb .r
    mov word [LCNT],0
.r: ret
.fa: cmp al,0xfa
    jnz .r
    mov word [LCNT],0
    mov ax,[0x40a]
    mov [LCLKL],ax
    ret
LFOCC:              ; CC89 rate/division, 90 depth, 91 shape, 92 destination, 93 mode
    call L61DB
    mov bl,[cs:LASTCC]
    cmp bl,89
    jnz .c90
    mov [LRATE],al
    ret
.c90: cmp bl,90
    jnz .c91
    mov [LDEPTH],al
    ret
.c91: cmp bl,91
    jnz .c92
    mov ah,8
    call SCL
    mov [LSHAPE],ah
    ret
.c92: cmp bl,92
    jnz .c93
    push ax
    call LFOOFF
    pop ax
    shr al,4
    mov [LDEST],al
    cmp al,2
    jnz .r
    mov ax,[si+0x74]
    mov [LB74],ax
.r: ret
.c93: mov ah,3
    call SCL
    mov [LMODE],ah
    ret
SCL: mul ah             ; ah = al * ah / 128
    shl ax,1
    ret
NOWE:               ; bx = this voice's MIDI channel block in the FZ's controller table (group B = foot)
    mov bl,[CURCH]
    and bl,0x0f
    mov al,0x18
    mul bl
    add ax,0x52a0
    mov bx,ax
    ret
LFOOFF:             ; remove LFO 2's effect from its current destination
    push ax
    push bx
    call NOWE
    xor al,al
    mov [bx+0xa],al
    mov [bx+0xb],al
    mov [bx+0xc],al
    mov [bx+0xe],al
    mov [bx+0xf],al
    cmp byte [LDEST],7
    jnz .nb
    mov [bx],al             ; bend back to centre
.nb: cmp byte [LDEST],2
    jnz .n
    call L61DB
    mov ax,[LB74]
    mov [si+0x74],ax
.n: mov word [LOUT],0x8000
    pop bx
    pop ax
    ret
LFO2:
    cmp byte [LDEST],0
    jnz .go
    push bx
    mov bl,[LREC]
    xor bh,bh
    cmp byte [bx+MXLU],0    ; running only as a matrix source
    pop bx
    jnz .go
    ret
.go: call L61DB
    call LFENVUP
    cmp byte [LMODE],2
    jnz .free
    mov al,[LRATE]          ; MIDI clock: 4 bars .. 1/16
    mov ah,7
    call SCL
    mov cl,6
    sub cl,ah
    mov bx,6
    shl bx,cl               ; clocks per cycle
    push bx
    mov dx,1
    xor ax,ax
    div bx
    mov di,ax               ; phase step per clock
    mov ax,[0x40a]
    sub ax,[LCLKL]
    mov cx,[LCLKT]
    jcxz .nof
    cmp ax,cx
    jb .f1
    mov ax,cx
    dec ax
.f1: mul di
    div cx
    jmp .f2
.nof: xor ax,ax
.f2: push ax
    mov ax,[LCNT]
    xor dx,dx
    pop cx
    pop bx
    push cx
    div bx
    mov ax,dx
    mul di
    pop cx
    add ax,cx
    mov [LPH2],ax
    jmp .shape
.free: mov ax,[0x40a]
    mov dx,ax
    sub ax,[LTM2]
    mov [LTM2],dx
    shr ax,5
    mov cl,[LRATE]
    xor ch,ch
    mul cx
    shl ax,2
    cmp byte [LSHAPE],7     ; warble: this cycle's random speed (Q8)
    jnz .fa
    mov cl,[LWARB]
    or cl,cl
    jnz .fb
    mov cl,160
.fb: xor ch,ch
    mul cx
    mov al,ah
    mov ah,dl
.fa: add [LPH2],ax
    cmp byte [LMODE],1
    jnz .shape
    mov di,0x5420           ; retrigger: a new note of this voice restarts the cycle
    mov cx,8
    xor dl,dl
.y: cmp byte [di],0xff
    jz .yn
    cmp [di+0xa],si
    jnz .yn
    cmp word [di+6],8
    jae .yn
    mov dl,1
.yn: add di,0x3a
    loop .y
    or dl,dl
    jz .yo
    cmp byte [LYOUNG],0
    jnz .yo
    mov word [LPH2],0
    mov word [LPREV],0
    mov byte [LDONE],0
.yo: mov [LYOUNG],dl
.shape:
    mov ax,[LPH2]
    mov dl,0
    cmp ax,[LPREV]
    jae .nw
    mov dl,1                ; cycle wrapped
.nw: mov [LPREV],ax
    mov al,ah               ; al = phase 0..255
    mov bl,[LSHAPE]
    cmp bl,7                ; warble = sine, new random speed (0.24..0.98) each cycle
    jnz .s0
    or dl,dl
    jz .wn
    push ax
    mov ax,[LRND]
    mov cx,25173
    mul cx
    add ax,13849
    mov [LRND],ax
    mov al,ah
    mov ah,190
    mul ah
    mov al,ah
    add al,61
    mov [LWARB],al
    pop ax
.wn: mov bl,1
.s0: or bl,bl
    jnz .s1
    cmp al,128              ; triangle
    jb .t1
    not al
.t1: shl al,1
    sub al,127
    jmp .out
.s1: cmp bl,1
    jnz .s2
    mov bl,al               ; sine (quarter table, 33 points)
    and bx,0x3f
    shr bx,1
    test al,0x40
    jz .q1
    neg bx
    add bx,32
.q1: mov ah,al
    mov al,[cs:bx+SINT]
    test ah,0x80
    jz .out
    neg al
    jmp .out
.s2: cmp bl,2
    jnz .s3
    sub al,128              ; saw up
    jmp .out
.s3: cmp bl,3
    jnz .s4
    not al                  ; saw down
    sub al,128
    jmp .out
.s4: cmp bl,4
    jnz .s5
    cmp al,128              ; square
    mov al,127
    jb .out
    mov al,-127
    jmp .out
.s5: cmp bl,5
    jnz .s6
    or dl,dl                ; sample & hold
    jz .h
    mov ax,[LRND]
    mov cx,25173
    mul cx
    add ax,13849
    mov [LRND],ax
    mov [LSHV],ah
.h: mov al,[LSHV]
    jmp .out
.s6: or dl,dl               ; one-shot rising ramp (holds at top until retriggered)
    jz .o1
    mov byte [LDONE],1
.o1: cmp byte [LDONE],0
    jz .o2
    mov al,127
    jmp .out
.o2: sub al,128
.out: cmp al,-128
    jnz .o3
    mov al,-127
.o3: cbw
    call LFGAIN             ; delay / fade-in after each new note
    call LFRSAVE            ; the matrix takes LFO 2 before its depth
    mov bl,[LDEPTH]
    imul bl
    sar ax,7                ; mod -127..127
    cmp ax,[LOUT]
    jnz .ap
    ret
.ap: mov [LOUT],ax
    mov cx,ax
    call NOWE
    mov dl,[LDEST]
    cmp dl,1
    jnz .d2
    mov dl,1
    call LFXADD
    mov [bx+0xf],cl         ; filter cutoff offset (+ matrix)
    ret
.d2: cmp dl,2
    jnz .d7c
    shl cx,2                ; pitch: +/- 2 semitones at full depth
    add cx,[LB74]
    mov [si+0x74],cx
    ret
.d7c: cmp dl,7
    jnz .d3
    mov dl,4
    call LFXADD
    push bx
    mov bl,[CURCH]
    and bx,0x0f
    mov al,[bx+CBEND]
    pop bx
    cbw
    push ax
    mov al,cl
    cbw
    pop cx
    add ax,cx
    call CLAMP
    cmp byte [PGM],0        ; glide on: the matrix pass writes the bend byte
    jnz .pgb
    mov [bx],al             ; pitch-bend byte (+ player's bend + matrix): scrubs in CUE play mode
.pgb:
    ret
.d3: add cx,127
    shr cx,1                ; 0..127
    cmp dl,3
    jb .d6
    cmp dl,5
    ja .d6
    push dx
    add dl,2
    call LFXADD
    pop dx
    or cl,cl
    jns .du
    xor cl,cl
.du: mov al,dl
    xor ah,ah
    mov di,ax
    mov [bx+di+0xa-3],cl    ; extra depth for the FZ's LFO -> pitch / amplitude / filter
    ret
.d6: cmp dl,6
    jnz .d7
    neg cl                  ; tremolo: level offset 0..-127 (+ matrix)
    mov dl,3
    call LFXADD
    mov [bx+0xe],cl
.d7: ret
SINT: db 0,6,12,19,25,31,37,43,49,54,60,65,71,76,81,85,90,94,98,102,106,109,112,115,117,120,122,123,125,126,126,127,127
RVPATCH:            ; reverse play mode + loop mode not one-shot: give each reverse note its loop (v2)
    cmp byte [PREADY],0
    jz .r
    call L61DB
    cmp word [si+0x10],0x101d
    jnz .r
    cmp word [si+0x12],0x0808
    jz .r
    mov di,0x5420
    xor bx,bx
    mov dl,1
.k: cmp byte [di],0xff
    jz .ina
    cmp [di+0xa],si
    jz .me
    call ISSLICE
    jnz .nx
.me: mov ax,[di+6]
    cmp ax,[bx+G6]
    mov [bx+G6],ax
    jb .new
    test [RVP],dl
    jnz .nx
.new: or [RVP],dl
    push si
    mov si,[di+0xa]
    call RVONE
    pop si
    jmp .nx
.ina: mov al,dl
    not al
    and [RVP],al
.nx: add di,0x3a
    add bx,2
    shl dl,1
    jnz .k
.r: ret
RVONE:              ; di = gene, dl = mask: send loop length (cmd 43) and mode with loop bits (cmd 42)
    push bx
    push dx
    xor bh,bh
    mov bl,[di+0xe]
    cmp bl,8
    jae .x
    shl bx,2
    push dx
    mov ax,[bx+si+0x34]
    mov cx,[bx+si+0x36]
    and cx,0x1f
    mov dx,[bx+si+0x16]
    and dx,0x1f
    sub ax,[bx+si+0x14]
    sbb cx,dx
    pop dx
    jc .x
    shr cx,1
    rcr ax,1
    push bx
    mov bx,cx
    mov cx,[si+0x10]
    mov dh,0x43
    call GA1
    pop bx
    push bx                 ; v2: restart = loop end, trigger = loop start
    mov ax,[bx+si+0x34]
    mov cx,[bx+si+0x16]
    mov bx,[bx+si+0x36]
    and bx,0x1f
    mov cl,ch
    xor ch,ch
    mov dh,0x41
    call GA1
    pop bx
    push bx
    mov cx,[bx+si+0x16]
    and cx,0x1f
    mov bx,[bx+si+0x14]
    mov dh,0x41
    call GA2
    pop bx
.nsw:
    shr bx,1
    mov cx,[bx+si+0x54]
    mov bx,[si+0x10]
    or bx,0xc2
    or cx,cx
    jnz .m
    and bx,0xbf
.m: mov dh,0x42
    call GA2
.x: pop dx
    pop bx
    ret

NMSG:
    cmp byte [MXQ],0        ; matrix-made changes stay quiet
    jz .m
    ret
.m: call L7CHK              ; PERF40H: 'EMPTY-REC READY' goes once the voice has sound
    mov word [LCDP],0       ; (a paced FX value message waiting is older than this one)
    push ds
    pop es
    jmp NPAD                ; FZED: line 3 is blanked first, so messages need no trailing spaces
NSETUP:             ; es:si -> wave memory at voice start (bank via port 22h), NCNT:bp... count in [NCNT] (dx:cx)
    mov ax,[si+0xc]         ; count = end - start (words)
    mov dx,[si+0xe]
    and dx,0x1f
    mov bx,[si+0x8]
    mov cx,[si+0xa]
    and cx,0x1f
    sub ax,bx
    sbb dx,cx
    jc .bad
    mov di,ax
    or ax,dx
    jz .bad
    mov [NCNT],di
    mov [NCNT+2],dx
    shl bx,1                ; byte address = word address * 2
    rcl cx,1
    and cl,0x3f
    in al,0x22
    and al,0xc0
    or al,cl
    out 0x22,al
    mov [NBANK],al
    mov ax,0x1000
    mov es,ax
    mov si,bx
    clc
    ret
.bad: stc
    ret
NNEXT:              ; advance one word; ZF=1 when done
    add si,2
    jnz .c
    mov al,[NBANK]
    mov ah,al
    and ah,0xc0
    inc al
    and al,0x3f
    or al,ah
    mov [NBANK],al
    out 0x22,al
.c: sub word [NCNT],1
    sbb word [NCNT+2],0
    mov ax,[NCNT]
    or ax,[NCNT+2]
    ret
ISSLICE:            ; ZF=1 if gene di plays one of the chop slices
    push cx
    push bx
    mov ax,[di+0xa]
    xor bx,bx
    mov cl,[CHCNT]
    xor ch,ch
    jcxz .no
.l: cmp ax,[bx+CHV]
    jz .y
    add bx,2
    loop .l
.no: or sp,sp              ; ZF=0
.y: pop bx
    pop cx
    ret
CHPROP:             ; copy sound settings (mode, 54h..ADh, rate, loops) from the source voice to every chop slice
    cmp byte [CHCNT],0
    jz .r
    cmp si,[CHOWN]
    jnz .r
    xor bx,bx
    mov cl,[CHCNT]
    xor ch,ch
.l: push cx
    mov di,[bx+CHV]
    mov ax,[si+0x10]
    mov [di+0x10],ax
    mov al,[si+0xb1]        ; sample rate (live: the pitch job reads it every tick)
    mov [di+0xb1],al
    push si
    add si,0x54
    add di,0x54
    call CHPMV              ; PERF40G: all of 54h-ADh, or (per-slice mode) all but filter / envelopes / LFO 1
    pop si
    pop cx
    add bx,2
    loop .l
    jmp CHLOOP
.r: ret
CHLOOP:             ; slices follow the source's loop mode; loop points map to the same place in each slice
    xor bx,bx
    mov cl,[CHCNT]
    xor ch,ch
.l: push cx
    push bx
    mov di,[bx+CHV]
    mov ax,[si+0x12]
    mov [di+0x12],ax
    cmp ax,0x0808
    jz .one
    xor bx,bx
.k: push bx
    add bx,0x14
    call CHPT
    add bx,0x20
    call CHPT
    pop bx
    call CHMIN
    add bx,4
    cmp bx,32
    jb .k
    jmp .nx
.one: mov ax,[di+0xc]       ; one-shot: loops parked at the slice end, no flags
    mov dx,[di+0xe]
    and dx,0x1f
    xor bx,bx
.p: mov [bx+di+0x14],ax
    mov [bx+di+0x16],dx
    mov [bx+di+0x34],ax
    mov [bx+di+0x36],dx
    add bx,4
    cmp bx,32
    jb .p
.nx: pop bx
    pop cx
    add bx,2
    loop .l
    ret
CHPT:               ; slice point [di+bx] = slice start + slice length * (source point - GSAVE) / (AE - GSAVE)
    push bx
    mov ax,[si+bx]
    mov dx,[si+bx+2]
    mov cx,dx
    and cx,0xffe0           ; loop flag bits
    push cx
    and dx,0x1f
    sub ax,[GSAVE]
    sbb dx,[GSAVE+2]
    jnc .p
    xor ax,ax
    xor dx,dx
.p: mov bx,[AEL]
    mov cx,[AEH]
    and cx,0x1f
    sub bx,[GSAVE]
    sbb cx,[GSAVE+2]
    jc .full
.nm: or cx,cx
    jz .nd
    shr cx,1
    rcr bx,1
    shr dx,1
    rcr ax,1
    jmp .nm
.nd: or bx,bx
    jz .full
    or dx,dx
    jnz .full
    cmp ax,bx
    jae .full
    mov dx,ax
    xor ax,ax
    div bx
    jmp .hf
.full: mov ax,0xffff
.hf: mov bx,ax              ; bx = fraction 0..FFFFh
    mov ax,[di+0xc]
    mov dx,[di+0xe]
    and dx,0x1f
    mov cx,[di+0xa]
    and cx,0x1f
    sub ax,[di+8]
    sbb dx,cx
    push dx
    mul bx
    mov cx,dx
    pop ax
    mul bx
    add ax,cx
    adc dx,0
    add ax,[di+8]
    adc dx,[di+0xa]
    and dx,0x1f
    pop cx
    or dx,cx
    pop bx
    mov [di+bx],ax
    mov [di+bx+2],dx
    ret
CHMIN:              ; keep slice loop k (bx = 4k) at least 32 words long, inside the slice
    mov ax,[di+bx+0x34]
    mov dx,[di+bx+0x36]
    and dx,0x1f
    mov cx,[di+bx+0x16]
    and cx,0x1f
    sub ax,[di+bx+0x14]
    sbb dx,cx
    jc .fix
    or dx,dx
    jnz .ok
    cmp ax,32
    jae .ok
.fix: mov ax,[di+bx+0x34]
    mov dx,[di+bx+0x36]
    and dx,0x1f
    sub ax,32
    sbb dx,0
    jc .cl
    mov cx,[di+0xa]
    and cx,0x1f
    cmp dx,cx
    ja .st
    jb .cl
    cmp ax,[di+8]
    jae .st
.cl: mov ax,[di+8]
    mov dx,[di+0xa]
    and dx,0x1f
.st: mov cx,[di+bx+0x16]
    and cx,0xffe0
    or dx,cx
    mov [di+bx+0x14],ax
    mov [di+bx+0x16],dx
.ok: ret
CHFINDO: push word CHFIND  ; PERF40H: (start-up only) in tools overlay 3
    push word 0x4030
    jmp OVCALL
CHOPCC:             ; CC96 sensitivity, CC97 chop mode/zero-cross, CC98 chop, CC99 slices, CC100 delete unused
    mov bl,[cs:LASTCC]
    cmp bl,96
    jnz .c97
    mov [TSENS],al
    ret
.c97: cmp bl,97
    jnz .c99
    mov ah,3
    call SCL
    mov [ZCM],ah
    mov al,ah
    mov ah,16
    mul ah
    add ax,S_ZM
    mov bx,ax
    jmp NMSG
.c99: cmp bl,99
    jnz .c100
    shr al,5
    mov cl,al
    mov al,4
    shl al,cl
    mov [CHN],al
    mov di,S_CN+5
    call DEC2
    mov bx,S_CN
    jmp NMSG
.c100: cmp bl,100
    jnz .c98
    push word DELUN         ; PERF40G: DELETE UNUSED is in tools overlay 2
    push word 0x402F
    jmp OVCALL
.c98: cmp al,64
    jae .p1
    mov byte [CHARM],0      ; play the voice itself
    cmp byte [CHPLAY],0
    jz .rr
    mov byte [CHPLAY],0
    jmp BKBACK
.p1: cmp al,120
    jae .mk
    cmp byte [CHCNT],0      ; play the slices
    jz .rr
    jmp CHON
.mk: cmp byte [CHARM],0
    jnz .rr
    mov byte [CHARM],1
    call CHOK
    jc .rr
    jmp CHOP
.rr: ret
CHOK:               ; CF=1 if busy (recording) or no voice
    cmp byte [PREADY],0
    jz .no
    mov al,[RST]
    cmp al,1
    jb .ok
    cmp al,3
    jbe .no
.ok: call L61DB
    clc
    ret
.no: stc
    ret
ADDREF:             ; voice addresses changed (delete unused): refresh PERF's copies so ESC stays safe
    mov byte [CHSBV],0
    mov cx,4
    xor bx,bx
.g: mov ax,[si+bx+8]
    mov [bx+GSAVE],ax
    add bx,2
    loop .g
    mov ax,[GSAVE+4]
    mov [AEL],ax
    mov [NE],ax
    mov ax,[GSAVE+6]
    mov [AEH],ax
    mov [NE+2],ax
    mov di,LBUF
    call CP40
    mov di,BUF
CP40:               ; FZED: the voice's 8 loop starts / ends (voice+14h, 40h bytes) -> di
    push si
    lea si,[si+0x14]
    mov cx,0x40
    call MOVB
    pop si
    ret
CHON:               ; play the chop bank
    mov ax,[CHBANK]
    or ax,ax
    jz .r
    cli
    mov [0xdfe],ax
    mov word [0xe00],0
    sub ax,0xe08
    xor dx,dx
    mov cx,0x290
    div cx
    mov [0xdfc],ax
    sti
    mov byte [CHPLAY],1
.r: ret
CHOP:
    mov al,[LVON]           ; live FX: chop the clean sample, then resume
    mov [LVWAS],al
    call LVOFF
    mov bx,S_CW
    call NMSG
    call L61DB
    xor bx,bx               ; 1. remove the previous chop voices
.dl: cmp bl,[CHCNT]
    jae .dd
    push bx
    shl bx,1
    mov di,[bx+CHV]
    cmp word [di+0x10],0
    jz .d2
    push word 0
    push di
    APIC 169,4
.d2: pop bx
    inc bx
    jmp .dl
.dd: mov byte [CHCNT],0
    call L61DB
    call MKBNDO             ; 2. slice boundaries (equal or transients, zero-crossing snap)
    jnc .bnd
    jmp .short
.bnd:
    call CHBSELO            ; 3. bank (PERF40J): this chop's again, else its own new CHOP bank or (CHOP INTO TARGET) the
    jnc .bok                ; bank being built, after its places, on Gills' channel
    ret
.bok:
    mov byte [CHI],0
.sl: mov al,[CHI]           ; 4. each slice
    cmp al,[NBND]
    jae .sld
    mov bx,[CHBANK]         ; PERF40J: a bank holds 64 places
    cmp word [bx],64
    jb .s0
.sld: jmp .done
.s0: call L61DB
    mov di,0x2288           ; free voice slot
    mov cx,64
.fv: cmp di,si
    jz .fn
    cmp word [di+0x10],0
    jz .got
.fn: add di,0xc0
    loop .fv
    mov bx,S_CV
    jmp .err
.got: mov bl,[CHI]           ; length = SBND[i+1] - SBND[i]
    xor bh,bh
    shl bx,2
    mov ax,[bx+SBND+4]
    mov dx,[bx+SBND+6]
    sub ax,[bx+SBND]
    sbb dx,[bx+SBND+2]
    mov [CHL],ax
    mov [CHL+2],dx
    push di
    push dx
    push ax
    push word 0
    push di
    APIC 117,8              ; FZ allocates wave memory for the slice
    pop di
    or bx,bx
    jz .al
    mov bx,S_CM
    jmp .err
.al: call L61DB
    push si                 ; copy all settings except addresses
    push di
    mov ax,[si+0x10]
    mov [di+0x10],ax
    add si,0x54
    add di,0x54
    mov cx,0xc0-0x54
    call MOVB
    pop di
    pop si
    mov word [di+0x12],0x0808   ; one-shot, loops parked at the slice end, no loop time
    mov ax,[di+0xc]
    mov dx,[di+0xe]
    and dx,0x1f
    xor bx,bx
.lp: mov [bx+di+0x14],ax
    mov [bx+di+0x16],dx
    mov [bx+di+0x34],ax
    mov [bx+di+0x36],dx
    add bx,4
    cmp bx,32
    jb .lp
    xor bx,bx
.lt: mov word [bx+di+0x64],0
    add bx,2
    cmp bx,16
    jb .lt
    mov al,[CHI]            ; key = C2 + slice
    add al,36
    mov [di+0xae],al
    mov [di+0xaf],al
    mov [di+0xb0],al
    push di                 ; wave data: SBND[i] -> slice start, CHL words
    mov bl,[CHI]
    xor bh,bh
    shl bx,2
    mov ax,[bx+SBND]
    mov dx,[bx+SBND+2]
    mov cx,[di+8]
    mov bx,[di+0xa]
    call WCOPY
    pop di
    mov bx,[CHBANK]         ; bank area
    mov al,[CHI]
    xor ah,ah
    mov si,ax
    add bx,si
    add bx,[CHBASE]         ; PERF40J: after the places already in the bank
    mov al,[CHI]
    add al,36
    mov [bx+2],al
    mov [bx+0x42],al
    mov [bx+0x102],al
    mov byte [bx+0x82],0x7f
    mov byte [bx+0xc2],0
    mov byte [bx+0x1c2],0
    mov al,[CHOKV]          ; PERF40A: FFh all outputs, 01h output 1 = choke
    mov [bx+0x182],al
    call CHCHAN             ; PERF40J: the FZ's channel (own CHOP bank) or Gills' (CHOP INTO TARGET)
    mov [bx+0x142],al
    mov bx,[CHBANK]
    shl si,1
    mov [si+CHV],di
    add bx,[CHBASE]
    add bx,[CHBASE]
    mov [bx+si+0x202],di
    mov bx,[CHBANK]
    inc word [bx]
    inc byte [CHI]
    mov al,[CHI]
    mov [CHCNT],al
    jmp .sl
.err: mov [CHWHY],bx
    call NMSG
    cmp byte [CHCNT],0
    jz .r
    jmp .dz
.done: mov word [CHWHY],0
.dz: call L61DB
    mov [CHOWN],si
    mov ax,si               ; bank name 'CHOP Vnn' = source voice number
    sub ax,0x2288
    mov cl,0xc0
    div cl
    inc al
    call CHNMD              ; PERF40J: (a chop into a target bank leaves the bank's name alone)
    mov byte [di+0x287],'V'
    add di,0x288
    call DEC2
    call CHPROP
    call CHON
    mov al,[CHCNT]
    mov di,S_CO+5
    call DEC2
    mov al,[CHN]
    mov di,S_CO+8
    call DEC2
    mov si,S_CK             ; reason when fewer slices than asked for
    mov al,[CHCNT]
    cmp al,[CHN]
    jae .w0
    mov si,S_CKH            ; (transient mode found fewer hits)
.w0: mov bx,[CHWHY]
    cmp bx,S_CM
    jnz .w1
    mov si,S_CKM
.w1: cmp bx,S_CV
    jnz .w2
    mov si,S_CKV
.w2: mov ax,[si]
    mov [S_CO+11],ax
    mov ax,[si+2]
    mov [S_CO+13],ax
    mov byte [CHSBV],1      ; slices know where they came from (live FX on slices)
    mov ax,[GSAVE]
    mov [CHG0],ax
    mov ax,[GSAVE+2]
    mov [CHG0+2],ax
    mov bx,S_CO
    call NMSG
    cmp byte [LVWAS],0
    jz .r
    mov byte [LVWAS],0
    mov al,127
    jmp LVCC
.short: mov bx,S_CS
    jmp NMSG
.r: ret
DEC2:               ; al (0-99) -> two decimal digits at [di]
    aam
    add ax,0x3030
    xchg al,ah
    mov [di],ax
    ret
WCOPY:              ; copy [NCNT]=CHL words from wave dx:ax to wave bx:cx (word addresses)
    push es
    shl ax,1                ; source byte address -> bank / offset
    rcl dx,1
    mov si,ax
    mov [CHSB],dl
    shl cx,1                ; destination
    rcl bx,1
    mov di,cx
    mov [CHDB],bl
    mov ax,0x1000
    mov es,ax
    in al,0x22
    and al,0xc0
    mov ah,al
    mov bp,[CHL]
.w: mov al,[CHSB]
    and al,0x3f
    or al,ah
    out 0x22,al
    mov dx,[es:si]
    mov al,[CHDB]
    and al,0x3f
    or al,ah
    out 0x22,al
    mov [es:di],dx
    add si,2
    jnz .s
    inc byte [CHSB]
.s: add di,2
    jnz .d
    inc byte [CHDB]
.d: sub bp,1
    sbb word [CHL+2],0
    mov dx,bp
    or dx,[CHL+2]
    jnz .w
    pop es
    ret
RDW:                ; ax = sample at wave word address dx:ax
    push bx
    push cx
    push es
    mov bx,ax
    mov cx,dx
    shl bx,1
    rcl cx,1
    and cl,0x3f
    in al,0x22
    and al,0xc0
    or al,cl
    out 0x22,al
    mov ax,0x1000
    mov es,ax
    mov ax,[es:bx]
    pop es
    pop cx
    pop bx
    ret
ZCAT:               ; ZF=1 if the signal crosses zero between dx:ax-1 and dx:ax
    push ax
    push dx
    push bx
    push ax
    push dx
    call RDW
    mov bx,ax               ; s1
    pop dx
    pop ax
    sub ax,1
    sbb dx,0
    call RDW                ; s0
    or bx,bx
    jz .y
    xor ax,bx
    js .y
    or sp,sp                ; ZF=0
    jmp .x
.y: cmp ax,ax               ; ZF=1
.x: pop bx
    pop dx
    pop ax
    ret
ZCNEAR:             ; dx:ax -> nearest zero crossing within 256 words (unchanged if none)
    push bx
    push cx
    xor cx,cx
.l: push ax
    push dx
    add ax,cx
    adc dx,0
    call ZCOK               ; PERF38I: candidates inside the sample only
    jz .f
    pop dx
    pop ax
    push ax
    push dx
    sub ax,cx
    sbb dx,0
    call ZCOK
    jz .f
    pop dx
    pop ax
    inc cx
    cmp cx,256
    jbe .l
    pop cx
    pop bx
    ret
.f: add sp,4
    pop cx
    pop bx
    ret
ZCBACK:             ; dx:ax -> nearest zero crossing at or before, within 1024 words
    push cx
    mov cx,1024
.l: call ZCAT
    jz .r
    sub ax,1
    sbb dx,0
    loop .l
.r: pop cx
    ret
SNAPV:              ; zero-crossing snap for start/end/loop edits (CC97 >= 43)
    cmp byte [ZCM],0
    jz .r
    mov bl,[cs:LASTCC]
    mov di,8
    cmp bl,76
    jz .one
    mov di,0xc
    cmp bl,77
    jz .one
    cmp bl,87
    jb .r
    cmp bl,88
    ja .r
    mov cl,bl
    xor bh,bh
    mov bl,[LIDX]
    shl bx,2
    lea di,[bx+0x14]        ; CC87 snaps the loop start, CC88 the loop end
    cmp cl,87
    jz .lp
    lea di,[bx+0x34]
.lp: push word [bx+si+0x14]
    push word [bx+si+0x16]
    push word [bx+si+0x34]
    push word [bx+si+0x36]
    call .one
    mov ax,[bx+si+0x34]     ; keep the loop at least one control step long, else undo
    mov dx,[bx+si+0x36]
    and dx,0x1f
    mov cx,[bx+si+0x16]
    and cx,0x1f
    sub ax,[bx+si+0x14]
    sbb dx,cx
    jc .ud
    jnz .ok
    cmp ax,[LSTEP]
    jae .ok
.ud: pop word [bx+si+0x36]
    pop word [bx+si+0x34]
    pop word [bx+si+0x16]
    pop word [bx+si+0x14]
    ret
.ok: add sp,8
    ret
.one: push bx
    mov bx,si
    add bx,di
    mov ax,[bx]
    mov dx,[bx+2]
    and dx,0x1f
    push bx
    call ZCNEAR
    pop bx
    mov [bx],ax
    mov cx,[bx+2]
    and cx,0xffe0
    or dx,cx
    mov [bx+2],dx
    pop bx
.r: ret
RNG:
    xor ah,ah
    push ax
    mov ax,[AEL]
    mov dx,[AEH]
    sub ax,[GSAVE]
    sbb dx,[GSAVE+2]
    mov cl,7
    shr ax,cl
    mov bx,dx
    mov cl,9
    shl bx,cl
    or ax,bx
    pop bx
    xchg ax,bx
    ret
ENVT: db 0,1,9,2
RT: db 0xa0,0x76,0x77
IGN: db 10,11,14,15,16,23,32,33,34,41,52,64,69
INITT: db 0x78,1,0x79,2,0x7a,0x7f,0x7b,0x7f,0x7c,0xc0,0x82,0xff,0x83,0xff,0x84,0   ; DCA: sus step 2, end step 3, full sustain
       db 0x8a,1,0x8b,2,0x8c,0x7f,0x8d,0x7f,0x8e,0xc0,0x94,0xff,0x95,0xff,0x96,0   ; DCF: the same
S_TITLE: db 'FZED',0
S_P: db 'REC 36K  002.0S',0
S_USD: db 'USED:ARM 120+',0
S_ST: db 'IDLE ',0,'ARMED',0,'WAIT ',0,'REC  ',0,'DONE ',0,'USED ',0,'NOMEM',0

S_C: db 'C=000 000',0
S_E: db 'EMPTY-REC READY',0
S_CN: db 'CHOP 00 SLICES',0
S_CW: db 'CHOPPING...',0
S_CO: db 'CHOP 00/00 OK  ',0   ; (+10..+13 are written: keep the length)
S_MCU: db 'CUE',0                ; FZED: play mode name (the others are in fx5bk.asm / fx4m.asm)
S_CK: db ' OK '
S_CKM: db ' MEM'
S_CKH: db ' HIT'
S_CKV: db ' VOI'
S_CB: db 'CHOP: NO BANK  ',0
S_CV: db 'CHOP: NO VOICE ',0
S_CM: db 'CHOP: NO MEMORY',0
S_CS: db 'CHOP: TOO SHORT',0
S_ZM: db 'CHOP EVEN      ',0,'CHOP EVEN+ZERO ',0,'CHOP TRANSIENT ',0
L61DB:
    mov si,[CURV]           ; the voice the CCs are editing (bank mode: the CC's channel)
    or si,si
    jnz L61F0
    mov si,[0xe04]
    test si,si
    jnz L61F0
    mov ax,[0xe02]
    mov bx,0xc0
    mul bx
    add ax,0x2288
    mov si,ax
L61F0:
    ret
L62D5:
    push word 0x0
    push word 0x40
    push word 0x80
    push word 0x33
    call L6004
    add sp,byte 0x8
    ret
L6331:
    mov ax,[0x9d8]
    cmp ax,[cs:0x8016]
    jz L634D
    mov bx,[cs:0x8016]
    inc byte [cs:0x8016]
    mov ax,[cs:0x8016]
                        ; (PERF38E: the FZ's own read pointer 09D6h is left to the FZ; writing it lost MIDI bytes)
    mov al,[bx+0x8d6]
    xor ah,ah
    clc
    ret
L634D:
    stc
    ret
L6372:
    mov al,[EXITR]          ; PERF40H: an exit sent from Gills (1 = ESC, 2 = ENTER) counts as that key
    or al,al
    jz .k
    mov byte [EXITR],0
    xor ah,ah
    ret
.k: push bx
    push cx
    push dx
    push si
    push di
    push word 0x6
    call L6004
    add sp,byte 0x2
    cmp ax,byte 0x15
    jz L638F
    cmp bx,byte 0x15
    jz L638F
    cmp ax,byte 0x14
    jz L638E
    cmp bx,byte 0x14
    jz L638E
    xor ax,ax
    jmp short L6392
L638E:
    mov ax,0x2
    jmp short L6392
L638F:
    mov ax,0x1
L6392:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
L6398:
    push ax
    push cx
    mov cx,0x0600           ; PERF38H: idle wait about 3 ms (was 0x3000, about 25 ms: the matrix, LFO 2 and the
L639D:
    nop
    loop L639D
    pop cx
    pop ax
    ret
%include "fx/fx5ak.asm"
%include "fx/capr4a.asm"
%include "fx/tools40.asm"
%if ($-$$) > 0x2000
%error low code would overlap variables at 8000h
%endif
    times 0x2400-($-$$) db 0x5a
%include "fx/fxkz.asm"
%include "fx/multi.asm"
DISPATCH:           ; al = value of CC LASTCC (PERF's CC handlers; also used by the mod matrix)
    push ax
    call L61DB
    pop ax
    call MXCAP
    push ax
    cmp byte [CAPON],0      ; PERF38M: capture mode takes the RECORD page and ignores conflicting controls
    jz .cf
    call CAPFLT
    jc .x
.cf:
    cmp byte [cs:LASTCC],10
    jnz .n10
    mov bl,[CCCH]           ; CC10: choose a parameter for CC11 on this channel
    and bx,0x0f
    mov [bx+PSEL],al
    jmp .x
.n10: cmp byte [cs:LASTCC],11
    jnz .n11
    call PARAM
    jmp .x
.n11: cmp byte [cs:LASTCC],126  ; loop window (matrix destination 9 / parameter 4)
    jnz .n126
    jmp .wr
.n126:
    cmp byte [cs:LASTCC],112
    jb .n112
    cmp byte [cs:LASTCC],119
    ja .n112
    call FXCC
    jmp .x
.n112:
    cmp byte [cs:LASTCC],102
    jae .rc
    cmp byte [cs:LASTCC],101
    jnz .n101
    call NORMO              ; PERF40H: normalise is in tools overlay 3 (sector 48)
    jmp .x
.n101:
    cmp byte [cs:LASTCC],96
    jb .n98
    call CHOPCC
    jmp .x
.n98:
    cmp byte [cs:LASTCC],94
    jb .n94
    call FXCC               ; CC94/95: ring mod frequency / shape
    jmp .x
.n94:
    cmp byte [cs:LASTCC],89
    jb .wr
    call LFOCC
    jmp .x
.wr:
    cmp byte [PREADY],0
    jz .x
    call WRITEL
    jmp .x
.rc:
    call RWRITE
    call SHOWR
    jmp .x
.x: pop ax
    ret
%include "fx/matrixz.asm"
%include "fx/fx5bk.asm"
%include "fx/capru.asm"
CAPINIT: mov byte [CAPON],0
    jmp MAIN
%if ($-$$) < 0x57FE
    times 0x57FE-($-$$) db 0x5a
%endif
SIG: dw 0x3750
%if ($-$$) > 0x5800
%error high code too big for sectors 25-37 (B800h on is used for tables)
%endif
section lv follows=.text vstart=0xB800
%include "fx/fx4m.asm"
%include "fx/fx5k.asm"
%include "fx/capr2z.asm"
%if ($-$$) > 0x600
%error code sectors B800h full (BE00h is THT)
%endif
    times 0x800-($-$$) db 0x5a
section xt follows=lv vstart=0xDC00
%include "fx/svfi.asm"
%include "fx/matrix2i.asm"
%include "fx/portai.asm"
%include "fx/fx2h.asm"
%include "fx/fx3i.asm"
%include "fx/fx5xi.asm"
%include "fx/capr3u.asm"
%if ($-$$) > 0x1000
%error code sectors 38-41 full
%endif
%if ($-$$) < 0x1000
    times 0x1000-($-$$) db 0x5a
%endif
section ov follows=xt vstart=0xD400
%include "fx/capo.asm"
section ov2 follows=ov vstart=0xD400
%include "fx/ov2.asm"
section ov3 follows=ov2 vstart=0xD400
%include "fx/ov3.asm"
section ov4 follows=ov3 vstart=0xD400
%include "fx/ov4.asm"
section ov5 follows=ov4 vstart=0xD400
%include "fx/ov5.asm"
