; ---------- PERF38: state-variable filter (FX mode 8 = CC112 120-127), live and render ----------
; Chamberlin SVF after the Ksoloti object filter/multimode svf m; fixed point as tested in work/perf_build/svf_test.
; CC94 type (0-42 low-pass, 43-85 band-pass, 86-127 high-pass), CC115 cutoff, CC116 resonance, CC117 mix.
SVF equ 0xC360              ; f (= 2 x f/2), Q15
SVD equ 0xC362              ; damping, Q15
SVIN equ 0xC364             ; input gain, Q15 (band-pass: damping; low/high-pass: sqrt(2 damping)/2)
SVT equ 0xC366              ; 0 low-pass, 1 band-pass, 2 high-pass
SVLL equ 0xC368             ; low  fraction (integer part SVLH)
SVBL equ 0xC36A             ; band fraction (integer part SVBH)
SVLH equ 0xC36C
SVBH equ 0xC36E
SVS equ 0xC370              ; live: 2 streams (sweep, chase) x 16: +0 next pos (dword) +4 segment +5 valid +6 LL BL LH BH
SVSTR equ 0xC390            ; live: 0 = sweep cursor, 1 = chase cursor
SVDRY equ 0xC392
SVTMP equ 0xC3DA            ; 4 bytes
SVSCR equ 0xD400            ; scratch (Karplus-Strong ring, unused in this mode): 1000 words
SVA equ 0xDBF0              ; range: from (dword)
SVE equ 0xDBF4              ;        to (dword)
SVWF equ 0xDBF8             ; 1 = write the result back
SVN equ 0xDBFA
SVLS equ 0xDBFC             ; (spare)

%macro SVSAT32 2
    jno %%ok
    or %2,%2
    js %%pos
    mov %2,0x8000
    mov word %1,0
    jmp %%ok
%%pos: mov %2,0x7fff
    mov word %1,0xffff
%%ok:
%endmacro
%macro SVSAT16 1
    jno %%ok
    or %1,%1
    js %%pos
    mov %1,0x8000
    jmp %%ok
%%pos: mov %1,0x7fff
%%ok:
%endmacro

SVK8:               ; cx words at es:si through the filter (state SVLL/SVBL/SVLH/SVBH), mix with CC117
    mov al,[SVT]            ; the loop is patched for this call: output (low / band / high) and mix on / off
    mov ah,0xc7             ; mov ax,di
    cmp al,1
    jb .tp
    mov ah,0xc5             ; mov ax,bp
    jz .tp
    mov ah,0xc3             ; mov ax,bx
.tp: mov [cs:.ty+1],ah
    mov ax,0x9090           ; mix: fall into it
    cmp word [FXW],16384
    jnz .tm
    mov ax,((.st-.mx-2)<<8)|0xeb   ; no mix: jmp short .st
.tm: mov [cs:.mx],ax
    mov di,[SVLH]
    mov bp,[SVBH]
    jmp short .l
.l: mov ax,[es:si]
    mov [SVDRY],ax
    imul word [SVIN]
    shl ax,1
    rcl dx,1
    mov bx,dx               ; scaled input (6 dB headroom included)
    mov ax,bp
    imul word [SVD]
    shl ax,1
    rcl dx,1                ; dx = damping * band
    sub bx,dx               ; notch = in - 2 * damping * band (saturating)
    SVSAT16 bx
    sub bx,dx
    SVSAT16 bx
    mov ax,bp
    imul word [SVF]         ; SVF = 2f/2 (Q15): one doubling here
    shl ax,1
    rcl dx,1
    add [SVLL],ax           ; low += 2f * band
    adc di,dx
    SVSAT32 [SVLL],di
    sub bx,di               ; high = notch - low
    SVSAT16 bx
    mov ax,bx
    imul word [SVF]
    shl ax,1
    rcl dx,1
    add [SVBL],ax           ; band += 2f * high
    adc bp,dx
    SVSAT32 [SVBL],bp
.ty: db 0x8b,0xc7           ; mov ax,di (patched: 8B C7 di, C5 bp, C3 bx)
    add ax,ax               ; undo the headroom
    SVSAT16 ax
.mx: dw 0x9090              ; (patched: nop nop / jmp short .st)
    mov bx,[SVDRY]          ; out = dry + ((wet - dry) * FXW >> 14)
    sub ax,bx
    jo .o
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov ax,dx
.st: mov [es:si],ax
    add si,2
    dec cx
    jz .x
    jmp .l
.x: mov [SVLH],di
    mov [SVBH],bp
    ret
.o: call MIXOV
    jmp .j

SVPAR:              ; coefficients from CC94 (type), CC115 (cutoff), CC116 (resonance)
    mov bl,[FXIN]
    and bx,0x7f
    shl bx,1
    mov ax,[cs:bx+SVFT]
    add ax,ax               ; stored doubled (max 26656)
    mov [SVF],ax
    mov al,[FXOUT]          ; A = 0.837 - 0.708 r/127 (Q15): damping A^2 runs Q 0.7 ... Q 30
    and ax,0x7f
    mov cx,23200
    mul cx
    mov cx,127
    div cx
    mov cx,27427
    sub cx,ax
    mov ax,cx
    mul cx
    shl ax,1
    rcl dx,1
    mov [SVD],dx
    mov ax,cx               ; sqrt(2 damping)/2 = A * 0.7071
    mov dx,23170
    mul dx
    shl ax,1
    rcl dx,1
    mov bx,dx
    mov al,[FXRF]
    mov ah,2
    cmp al,86
    jae .t
    mov ah,1
    mov bx,[SVD]
    cmp al,43
    jae .t
    mov ah,0
    mov ax,cx
    mov dx,23170
    mul dx
    shl ax,1
    rcl dx,1
    mov bx,dx
    mov ah,0
.t: mov [SVT],ah
    mov [SVIN],bx
    jmp SVMCHK2             ; PERF38I (fx5i.asm)

SVCLR:              ; filter state = 0
    xor ax,ax
    mov [SVLL],ax
    mov [SVBL],ax
    mov [SVLH],ax
    mov [SVBH],ax
    ret

SVRANGE:            ; words SVA..SVE of the wave through the filter, 128 at a time (written back when SVWF)
.c: mov ax,[SVE]
    mov dx,[SVE+2]
    sub ax,[SVA]
    sbb dx,[SVA+2]
    jc .x
    mov cx,ax
    or ax,dx
    jz .x
    or dx,dx
    jnz .big
    cmp cx,128
    jbe .n
.big: mov cx,128
.n: mov [SVN],cx
    mov ax,[SVA]
    mov dx,[SVA+2]
    mov di,LVBUF
    call LVRDX
    push es
    push ds
    pop es
    mov si,LVBUF
    mov cx,[SVN]
    call SVK8
    pop es
    cmp byte [SVWF],0
    jz .nw
    mov ax,[SVA]
    mov dx,[SVA+2]
    mov cx,[SVN]
    call LVWR
    mov ax,[SVN]
    add [FXN],ax
    adc word [FXN+2],0
    call FXTICK
.nw: mov ax,[SVN]
    add [SVA],ax
    adc word [SVA+2],0
    jmp .c
.x: push ds
    pop es
    ret

SVLOOP:             ; voice si: CF=0 and SVA..SVE = its sustain loop when it plays one inside start..end
    mov bl,[si+0x12]
    cmp bl,8
    jae .no
    xor bh,bh
    shl bx,2
    mov ax,[bx+si+0x14]
    mov dx,[bx+si+0x16]
    and dx,0x1f
    mov [SVA],ax
    mov [SVA+2],dx
    mov ax,[bx+si+0x34]
    mov dx,[bx+si+0x36]
    and dx,0x1f
    mov [SVE],ax
    mov [SVE+2],dx
    sub ax,[SVA]            ; end > start
    sbb dx,[SVA+2]
    jc .no
    or ax,dx
    jz .no
    mov ax,[SVA]            ; start >= voice start
    mov dx,[SVA+2]
    mov cx,[si+0xa]
    and cx,0x1f
    sub ax,[si+8]
    sbb dx,cx
    jc .no
    mov ax,[si+0xc]         ; voice end >= end
    mov dx,[si+0xe]
    and dx,0x1f
    sub ax,[SVE]
    sbb dx,[SVE+2]
    jc .no
    clc
    ret
.no: stc
    ret

SVRONE:             ; render voice si: start..loop from silence, loop settled twice, loop..end from the settled state
    call SVCLR
    push si
    call SVLOOP
    pop si
    jc .plain
    push word [SVA]         ; loop start / end
    push word [SVA+2]
    push word [SVE]
    push word [SVE+2]
    mov ax,[SVA]            ; 1: start..loop start, written
    mov dx,[SVA+2]
    mov [SVE],ax
    mov [SVE+2],dx
    mov ax,[si+8]
    mov dx,[si+0xa]
    and dx,0x1f
    mov [SVA],ax
    mov [SVA+2],dx
    mov byte [SVWF],1
    push si
    call SVRANGE
    pop si
    pop word [SVE+2]
    pop word [SVE]
    pop word [SVA+2]
    pop word [SVA]
    mov byte [SVWF],0       ; 2: run round the loop twice (not written) so its end meets its start
    mov cx,2
.st: push cx
    push word [SVA]
    push word [SVA+2]
    push si
    call SVRANGE
    pop si
    pop word [SVA+2]
    pop word [SVA]
    pop cx
    loop .st
    mov ax,[si+0xc]         ; 3: loop start..end, written
    mov dx,[si+0xe]
    and dx,0x1f
    mov [SVE],ax
    mov [SVE+2],dx
    mov byte [SVWF],1
    call SVRANGE
    ret
.plain: mov ax,[si+8]
    mov dx,[si+0xa]
    and dx,0x1f
    mov [SVA],ax
    mov [SVA+2],dx
    mov ax,[si+0xc]
    mov dx,[si+0xe]
    and dx,0x1f
    mov [SVE],ax
    mov [SVE+2],dx
    mov byte [SVWF],1
    call SVRANGE
    ret

SVPRE:              ; live, before a chunk: carry the stream's state when the chunk follows its last one, else run up
    mov bl,[SVSTR]
    and bx,1
    shl bx,4
    add bx,SVS
    cmp byte [bx+5],0
    jz .ru
    mov al,[LVSEGI]
    cmp al,[bx+4]
    jnz .ru
    mov ax,[LVPOS]
    cmp ax,[bx]
    jnz .ru
    mov ax,[LVPOS+2]
    cmp ax,[bx+2]
    jnz .ru
    mov ax,[bx+6]           ; continuous: this stream's state
    mov [SVLL],ax
    mov ax,[bx+8]
    mov [SVBL],ax
    mov ax,[bx+10]
    mov [SVLH],ax
    mov ax,[bx+12]
    mov [SVBH],ax
    ret
.ru: call SVCLR             ; jump: run the filter over up to 512 clean words before the chunk
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    mov cx,512
    or dx,dx
    jnz .rf
    cmp ax,cx
    jae .rf
    mov cx,ax
.rf: jcxz .r
    sub ax,cx
    sbb dx,0
    add ax,[LVSO]
    adc dx,[LVSO+2]
    add ax,[LVSRC]
    adc dx,[LVSRC+2]
    push cx
    mov di,SVSCR
    call LVRDX
    pop cx
    push es
    push ds
    pop es
    mov si,SVSCR
    push word [FXW]
    mov word [FXW],16384
    call SVK8
    pop word [FXW]
    pop es
.r: ret

SVPOST:             ; live, after a chunk: remember where this stream is and its state
    mov bl,[SVSTR]
    and bx,1
    shl bx,4
    add bx,SVS
    mov al,[LVSEGI]
    mov [bx+4],al
    mov byte [bx+5],1
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    add ax,[LVN]
    adc dx,0
    mov [bx],ax
    mov [bx+2],dx
    mov ax,[SVLL]
    mov [bx+6],ax
    mov ax,[SVBL]
    mov [bx+8],ax
    mov ax,[SVLH]
    mov [bx+10],ax
    mov ax,[SVBH]
    mov [bx+12],ax
    ret

SVRESET:            ; forget both streams
    mov byte [SVS+5],0
    mov byte [SVS+16+5],0
    ret

SVLV:               ; live chunk (es:si = LVBUF, cx words): state carried or run up, filtered, state kept
    push cx
    push si
    call SVPRE
    pop si
    pop cx
    push ds
    pop es
    call SVK8
    jmp SVPOST

SVINIT:
    call SVRESET
    jmp SVCLR

SVMAPCC:            ; bl = CC of a slow matrix destination; filter mode: 14 FX mix -> resonance, 15 FX param -> cutoff
    push ax                 ; CC112 in the filter band
    call FXMOF
    cmp al,8
    pop ax
    jnz .r
    cmp bl,117
    jnz .a
    mov bl,116
.a: cmp bl,94
    jnz .r
    mov bl,115
.r: ret

SVUNMAP:            ; dl = CC the user sent; filter mode: resonance / cutoff are the bases of destinations 14 / 15
    push ax                 ; CC112 in the filter band
    call FXMOF
    cmp al,8
    pop ax
    jnz .r
    cmp dl,117
    jz .no
    cmp dl,94
    jz .no
    cmp dl,116
    jnz .a
    mov dl,117
    ret
.a: cmp dl,115
    jnz .r
    mov dl,94
.r: ret
.no: mov dl,0xff
    ret



; ---------- PERF38B: live filter writes each part of the sample once per setting ----------
; A map with 1 bit per 128 words of every segment says "already written with the current settings". The chase (the
; chunks just ahead of the playhead, started from a run-up) skips those, so it never writes over finished words; the
; sweep runs on with one unbroken filter state from the segment start, so what it writes is exact and, with the
; settings still, the same as what is already there. Any change of type / cutoff / resonance / mix (or live off /
; bypass / another mode) clears the map and restarts the sweep from the start.
SVMAP equ 0xD800            ; 976 bytes (SVSCR run-up uses D400-D7FF)
SVMAPN equ 976
SVSNAP equ 0xDBE0           ; SVF SVD SVIN SVT FXW the map belongs to
SVSKD equ 0xDBEC            ; 1 = the chase skipped its chunk (LVRUN then sweeps instead)
SVPH equ 0xDBED             ; sweep of a looped voice: 0 to the loop end (the loop itself not written), 1 round the
                            ; loop again (written), 2 on to the end
SVNW equ 0xDBEE             ; 1 = this sweep chunk is only run through (first time round the loop)
SPLS equ 0xDBD0             ; loop start (dword, words from the segment start)
SPLE equ 0xDBD4             ; loop end (exclusive)
SPLON equ 0xDBD8            ; 1 = the voice plays a sustain loop
SPLL equ 0xDBDA             ; loop length (capped at 0xffff)

SVMAPCHK:           ; after SVPAR
    cmp byte [FXM],8
    jnz .clr
    cmp byte [LVON],2
    jnz .clr
    mov si,SVSNAP
    mov ax,[SVF]
    cmp ax,[si]
    jnz .clr
    mov ax,[SVD]
    cmp ax,[si+2]
    jnz .clr
    mov ax,[SVIN]
    cmp ax,[si+4]
    jnz .clr
    mov al,[SVT]
    cmp al,[si+6]
    jnz .clr
    mov ax,[FXW]
    cmp ax,[si+8]
    jnz .clr
    ret
.clr: mov si,SVSNAP
    mov ax,[SVF]
    mov [si],ax
    mov ax,[SVD]
    mov [si+2],ax
    mov ax,[SVIN]
    mov [si+4],ax
    mov al,[SVT]
    mov [si+6],al
    mov ax,[FXW]
    mov [si+8],ax
    call SVRESET            ; both filter streams start again; the sweep from the segment start
    xor ax,ax
    mov [LVPOS],ax
    mov [LVPOS+2],ax
    mov [SVPH],al
    push es
    push ds
    pop es
    mov di,SVMAP
    mov cx,SVMAPN/2
    xor ax,ax
    cld
    rep stosw
    pop es
    ret

SVBIX:              ; dx:ax = position in the segment LVSEGI -> bx = map byte, al = bit (0 past the map)
    mov bx,ax
    shr bx,7
    shl dx,9
    or bx,dx
    mov ax,[LVSO]
    mov dx,[LVSO+2]
    shr ax,7
    shl dx,9
    or ax,dx
    add bx,ax
    mov al,[LVSEGI]         ; slices: one spare bit each so neighbours never share one
    cmp al,0xff
    jz .v
    xor ah,ah
    add bx,ax
.v: mov cl,bl
    and cl,7
    mov al,1
    shl al,cl
    shr bx,3
    cmp bx,SVMAPN
    jb .r
    xor al,al
    xor bx,bx
.r: add bx,SVMAP
    ret

SVSKIP:             ; LVCHK, chase chunk at LVPOS: CF=1 when it is already written with these settings (keeps ax bx dx)
    cmp byte [SVSTR],1
    jnz .no
    cmp byte [FXM],8
    jnz .no
    cmp byte [LVON],2
    jnz .no
    push ax
    push bx
    push dx
    call SVBIX
    test [bx],al
    pop dx
    pop bx
    pop ax
    jz .no
    mov byte [SVSKD],1
    stc
    ret
.no: clc
    ret

SVNOWR:             ; LVCHK: CF=1 = do not write this chunk (the sweep's first time round a loop)
    cmp byte [SVNW],0
    jz .w
    mov byte [SVNW],0
    stc
    ret
.w: clc
    ret

SVMARK:             ; LVCHK, after writing the chunk at LVPOS
    cmp byte [FXM],8
    jnz .r
    cmp byte [LVON],2
    jnz .r
    mov ax,[LVPOS]
    mov dx,[LVPOS+2]
    call SVBIX
    or [bx],al
.r: ret

SVSWN:              ; LVCHK: the filter's sweep of a looped voice stops at the loop start / end (bx = words; ax dx kept)
    mov byte [SVNW],0
    cmp byte [SVSTR],0
    jnz .r
    cmp byte [FXM],8
    jnz .r
    cmp byte [LVON],2
    jnz .r
    push ax
    push dx
    push bx
    call SPLOOP
    pop bx
    pop dx
    pop ax
    cmp byte [SPLON],0
    jz .r
    mov cx,ax               ; back at a segment start after the third part: first part again
    or cx,dx
    jnz .nz
    cmp byte [SVPH],2
    jnz .nz
    mov byte [SVPH],0
.nz: cmp byte [SVPH],2
    jae .r
    push ax
    push dx
    mov si,SPLE
    cmp byte [SVPH],0       ; first part: before the loop start written, the loop only run through
    jnz .e
    cmp dx,[SPLS+2]
    ja .in
    jb .bf
    cmp ax,[SPLS]
    jae .in
.bf: mov si,SPLS
    jmp .e
.in: mov byte [SVNW],1
.e: mov cx,ax               ; dx:ax = limit - pos
    mov ax,[si]
    sub ax,cx
    mov cx,dx
    mov dx,[si+2]
    sbb dx,cx
    jc .p
    or dx,dx
    jnz .p
    cmp ax,bx
    jae .p
    mov bx,ax
.p: pop dx
    pop ax
.r: ret

SVSWADV:            ; LVCHK, after the sweep moved on: at the loop end go round once more with the state it has
    cmp byte [SVSTR],0      ; there, so the loop's start meets its end the way the note plays it
    jnz .r
    cmp byte [FXM],8
    jnz .r
    cmp byte [LVON],2
    jnz .r
    cmp byte [SPLON],0
    jz .r
    mov ax,[LVPOS]
    cmp ax,[SPLE]
    jnz .r
    mov ax,[LVPOS+2]
    cmp ax,[SPLE+2]
    jnz .r
    cmp byte [SVPH],0
    jnz .p2
    mov byte [SVPH],1
    mov ax,[SPLS]
    mov [LVPOS],ax
    mov [SVS],ax            ; the stream carries on there
    mov ax,[SPLS+2]
    mov [LVPOS+2],ax
    mov [SVS+2],ax
    ret
.p2: cmp byte [SVPH],1
    jnz .r
    mov byte [SVPH],2
.r: ret

SPLOOP:             ; SPLON/SPLS/SPLE/SPLL from the voice's sustain loop (whole voice only, not slices)
    mov byte [SPLON],0
    cmp byte [LVSEGI],0xff
    jnz .r
    call L61DB
    call SVLOOP
    jc .r
    mov ax,[SVA]
    mov dx,[SVA+2]
    sub ax,[LVSD]
    sbb dx,[LVSD+2]
    jc .r
    mov [SPLS],ax
    mov [SPLS+2],dx
    mov ax,[SVE]
    mov dx,[SVE+2]
    add ax,1
    adc dx,0
    sub ax,[LVSD]
    sbb dx,[LVSD+2]
    jc .r
    cmp dx,[LVSL+2]         ; capped at the segment end
    jb .c
    ja .cp
    cmp ax,[LVSL]
    jbe .c
.cp: mov ax,[LVSL]
    mov dx,[LVSL+2]
.c: mov [SPLE],ax
    mov [SPLE+2],dx
    sub ax,[SPLS]
    sbb dx,[SPLS+2]
    jc .r
    or dx,dx
    jz .l
    mov ax,0xffff
.l: cmp ax,16
    jb .r
    mov [SPLL],ax
    mov byte [SPLON],1
.r: ret

%include "fx/svft.inc"
