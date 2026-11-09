; ---------- PERF40A tools overlay: disk sector 46, loaded into D400h-D7BFh when needed (OVCALL checks OV2SIG first).
; It shares D400h with live FX buffers, the capture overlay and the curve build, so it is reloaded whenever one of those
; has used the area. FZ calls made from here run with the stack at DBFEh down to about D7ECh: keep this code below D7C0h.
OV2SIG: dw 0x402E           ; PERF40F: 4000h + sector (also at D7BEh)
MKBND:              ; SBND[0..NBND] = slice boundaries over start..end; CF=1 if too short
    mov ax,[si+8]
    mov dx,[si+0xa]
    and dx,0x1f
    mov [SBND],ax
    mov [SBND+2],dx
    mov [CHSRC],ax
    mov [CHSRC+2],dx
    mov ax,[si+0xc]
    mov dx,[si+0xe]
    and dx,0x1f
    sub ax,[CHSRC]
    sbb dx,[CHSRC+2]
    jc .bad
    mov [CHL],ax            ; total length
    mov [CHL+2],dx
    mov bl,[CHN]
    xor bh,bh
    push ax                 ; per-slice length (32/16 in two steps)
    mov ax,dx
    xor dx,dx
    div bx
    mov cx,ax
    pop ax
    div bx                  ; cx:ax = total/N
    or cx,cx
    jnz .ok
    cmp ax,64
    jb .bad
.ok: mov [TGAP],ax          ; (low word, for the transient gap)
    mov [TGAP+2],cx
    cmp byte [ZCM],2
    jnz .eq
    jmp TRANS
.eq: mov byte [NBND],1
.e1: mov al,[NBND]          ; boundary i = start + i * (total/N)
    cmp al,[CHN]
    jae .end
    xor ah,ah
    mov bx,ax
    mul word [TGAP]
    push dx
    push ax
    mov ax,bx
    mul word [TGAP+2]
    pop cx
    pop dx
    add dx,ax
    mov ax,cx
    add ax,[CHSRC]
    adc dx,[CHSRC+2]
    cmp byte [ZCM],0
    jz .e2
    cmp word [TGAP+2],0     ; only snap slices of 1024+ words
    jnz .e3
    cmp word [TGAP],1024
    jb .e2
.e3: call ZCNEAR
.e2: mov bl,[NBND]
    xor bh,bh
    shl bx,2
    mov [bx+SBND],ax
    mov [bx+SBND+2],dx
    inc byte [NBND]
    jmp .e1
.end: mov bl,[NBND]
    xor bh,bh
    shl bx,2
    mov ax,[si+0xc]
    mov dx,[si+0xe]
    and dx,0x1f
    mov [bx+SBND],ax
    mov [bx+SBND+2],dx
    clc
    ret
.bad: stc
    ret
TRANS:              ; transient detector: up to N-1 onsets after the start
    mov byte [NBND],1
    mov ax,[TGAP]           ; minimum gap = (total/N)/2, 64..65535 words
    mov cx,[TGAP+2]
    shr cx,1
    rcr ax,1
    or cx,cx
    jz .g1
    mov ax,0xffff
.g1: cmp ax,64
    jae .g2
    mov ax,64
.g2: mov [TGAP],ax
    shr ax,1
    mov [THOLD],ax
    mov word [TFAST],0
    mov word [TSLOW],0
    push si
    call NSETUP
    jnc .lp
    pop si
    jmp MKBND.end
.lp: mov ax,[es:si]
    or ax,ax
    jns .a
    neg ax
    jns .a
    mov ax,0x7fff
.a: mov bx,ax               ; fast += (a - fast)/32, slow += (a - slow)/512
    sub ax,[TFAST]
    sar ax,5
    add [TFAST],ax
    mov ax,bx
    sub ax,[TSLOW]
    sar ax,9
    add [TSLOW],ax
    cmp word [THOLD],0
    jz .t
    dec word [THOLD]
    cmp byte [NBND],1       ; start of the take: let the baseline follow the level
    jnz .nx
    mov ax,[TFAST]
    mov [TSLOW],ax
    jmp .nx
.t: mov ax,[TSLOW]          ; threshold = slow * (1 + k/8) + 300, k = 20 - sens/8 (ratio 3.5 .. 1.5)
    mov al,[TSENS]
    shr al,3
    mov cl,20
    sub cl,al
    xor ch,ch
    mov ax,[TSLOW]
    mul cx
    shr dx,1
    rcr ax,1
    shr dx,1
    rcr ax,1
    shr dx,1
    rcr ax,1
    or dx,dx
    jnz .nx
    add ax,[TSLOW]
    jc .nx
    add ax,300
    jc .nx
    cmp [TFAST],ax
    jbe .nx
    mov dl,[NBANK]          ; onset: word address = (bank:offset)/2, snapped back to a zero crossing
    and dx,0x3f
    mov ax,si
    shr dx,1
    rcr ax,1
    push si
    push ax
    push dx
    call ZCBACK
    mov bl,[NBND]           ; keep it after the previous boundary
    xor bh,bh
    dec bx
    shl bx,2
    cmp dx,[bx+SBND+2]
    ja .zk
    jb .zr
    cmp ax,[bx+SBND]
    ja .zk
.zr: pop dx
    pop ax
    jmp .zs
.zk: add sp,4
.zs: pop si
    push ax
    mov al,[NBANK]
    out 0x22,al             ; restore the scan's window
    pop ax
    mov bl,[NBND]
    xor bh,bh
    shl bx,2
    mov [bx+SBND],ax
    mov [bx+SBND+2],dx
    inc byte [NBND]
    mov ax,[TGAP]
    mov [THOLD],ax
    mov al,[NBND]
    cmp al,[CHN]
    jae .dn
.nx: call NNEXT
    jnz .lp
.dn: pop si
    push ds
    pop es
    jmp MKBND.end
SLTOOL:             ; 122 SLICE, 123 move it, 124 its lowest key, 125 its highest key, 127 its output (bl), value al
    mov cl,[CHCNT]
    or cl,cl
    jz .r
    cmp bl,127
    jnz .k1
    call .sb                ; 127 SLICE OUTPUT: this slice only (OFF / 1-8, as parameter 121)
    push bx
    call OUTB
    pop bx
    mov [bx+0x182],ah
    mov al,[SLSEL]
    inc ax
    mov di,S_SO+2
    call DEC2
    mov bx,S_SO
    jmp OUTM
.k1:
    cmp bl,122
    jnz .k
    mov cl,[CHN]            ; 122 SLICE: 0-127 over the slice count asked for (CC99), as Gills shows it
    mul cl
    shl ax,1
    cmp ah,[CHCNT]
    jae .nm
    mov [SLSEL],ah
    jmp .show
.nm: mov al,ah              ; (a transient chop found fewer: that slice wasn't made)
    inc ax
    mov di,S_NM+2
    call DEC2
    mov bx,S_NM
    jmp NMSG
.k: mov dh,bl
    call .sb
    and al,0x7f
    mov dl,66               ; 125: highest = original + value (semitones)
    cmp dh,124
    jb .mv
    mov ah,[bx+0x102]       ; PERF40E: 124 / 125 are semitones from the original key (Gills sends 0-24)
    ja .hi
    neg al                  ; 124: lowest = original - value
    inc dx
.hi: add al,ah
    jmp .set
.mv: mov ah,al              ; 123: move the slice, keeping its width (original key = the value)
    sub ah,[bx+0x102]
    add [bx+2],ah
    add [bx+0x42],ah
    mov dl,68
.set: call BKKEY.set        ; store and keep lowest <= original <= highest, within 3 octaves
    shl di,1                ; the slice voice takes the same keys (the FZ ignores keys outside a voice's range)
    mov si,[di+CHV]
    mov al,[bx+2]
    mov [si+0xae],al
    mov al,[bx+0x42]
    mov [si+0xaf],al
    mov al,[bx+0x102]
    mov [si+0xb0],al
.show: call .sb             ; 'SL01 C_2-C_2-C_2' (PERF40H: note names): slice, lowest, original, highest (DEC3 uses bx)
    mov si,bx
    mov al,[SLSEL]
    inc ax
    mov di,S_SL+2
    call DEC2
    mov al,[si+0x42]
    mov di,S_SL+5
    call NOTE3
    mov al,[si+0x102]
    mov di,S_SL+9
    call NOTE3
    mov al,[si+2]
    mov di,S_SL+13
    call NOTE3
    mov bx,S_SL
    jmp NMSG
.r: ret
.sb: mov bl,[SLSEL]         ; bx = CHOP bank + slice, di = slice (kept inside the chop)
    xor bh,bh
    cmp bl,[CHCNT]
    jb .sb1
    mov bl,[CHCNT]
    dec bx
    mov [SLSEL],bl
.sb1: mov di,bx
    call ADDCB              ; (PERF40J: this chop's places)
    nop
    ret

VFULL:              ; PERF40B parameter 7 VOICE INIT, full: the voice's filter and envelopes, LFO 1, key follow,
    mov byte [MXQ],1        ; rate scaling and velocity, and PERF's extras for it (LFO 2, matrix, pattern, glide). The
    mov bx,VFC              ; sample, its points, loops, keys, pitch and the FX settings are kept.
.c: mov al,[cs:bx]          ; PERF's own controls, as if sent (quietly): each through DISPATCH
    mov [cs:LASTCC],al
    mov al,[cs:bx+1]
    push bx
    call DISPATCH
    pop bx
    add bx,2
    cmp bx,VFC.e
    jb .c
    mov byte [MXQ],0
    call L61DB
    mov bx,VFR              ; voice bytes: runs of (offset, count, value)
.r: mov dl,[cs:bx]
    xor dh,dh
    mov di,dx
    add di,si
    mov cl,[cs:bx+1]
    xor ch,ch
    mov al,[cs:bx+2]
.f: mov [di],al
    inc di
    loop .f
    add bx,3
    cmp bx,VFR.e
    jb .r
    mov ax,0x007f           ; cutoff 127, resonance 0, envelope steps 1-3 (instant on, full sustain, release)
    call INIT
    mov bx,S_VF
    jmp NMSG
VFC: db 90,0, 92,0                          ; LFO 2 depth 0, destination off
     db 10,1, 11,0, 10,2, 11,0              ; LFO 2 delay, fade-in 0
     db 10,8, 11,0, 10,5, 11,0, 10,6, 11,0  ; pattern off, glide time 0, glide off
     db 10,120, 11,127                      ; matrix: all 10 slots cleared
     db 10,7                                ; (CC11 on this channel is voice init again)
.e:
VFR: db 0x7d,5,0xc0, 0x85,5,0              ; amp envelope steps 4-8: falling, level 0
     db 0x8f,5,0xc0, 0x97,5,0              ; filter envelope steps 4-8
     db 0x9c,2,0, 0x9f,1,0                 ; LFO 1 delay, attack
     db 0xa1,13,0                          ; LFO 1 pitch / amp / filter / resonance depth; velocity > resonance, key
.e:                                         ; follow, rate scaling and velocity amounts (A5h-ADh) neutral
S_VF:  db 'VOICE INIT: ALL ',0
S_SL:  db 'SL00 C_2-C_2-C_2',0
S_SO:  db 'SL00 ->OFF      ',0
S_NM:  db 'SL00 NOT MADE   ',0
%if ($-$$) > 0x3BE
%error tools overlay reaches its end signature (D7BEh)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x402E                   ; PERF40F: end signature (the FZ-call stack grows down into this area: OVCALL checks it)
    times 0x400-($-$$) db 0x5a
