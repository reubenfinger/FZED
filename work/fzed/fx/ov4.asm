; ---------- PERF40H tools overlay 3: disk sector 48 (signature 4030h at D400h and D7BEh): VOICE SELECT (pick / select),
; exit from Gills, NORMALISE (moved from the resident code). Code that makes FZ calls comes first (the FZ-call stack grows
; down from DBFEh into this area's top).
    dw 0x4030
VTOOL:              ; STRETCH-style controls 11 VOICE PICK (preview on line 2), 12 VOICE SELECT (>= 64), 13 EXIT (< 64 as
    mov bl,[STSEL]          ; ESC, >= 64 as ENTER)
    cmp bl,11
    jz .pick
    cmp bl,12
    jz .sel
    cmp bl,13
    jz .ex
    cmp bl,14
    jz .ka
    cmp bl,15
    jz FREEZE
    ret
.ka: xor ah,ah              ; 14 ENTER KEEPS: < 43 the sound only (as before), 43-85 all of the edit voice, >= 86 all
    cmp al,43               ; (bank voices too)
    jb .k0
    inc ah
    cmp al,86
    jb .k0
    inc ah
.k0: mov [KEEPA],ah
    ret
.ex: mov ah,1
    cmp al,64
    jb .e
    inc ah
.e: mov [EXITR],ah
    ret
.pick: mov si,0x2288        ; the voices with sound: the pot spreads over them
    mov cx,64
    xor dx,dx
.c: cmp word [si+0x10],0
    jz .c1
    inc dx
.c1: add si,0xc0
    loop .c
    or dl,dl
    jz .r
    mul dl
    shl ax,1                ; ah = which of them
    mov si,0x2288
    xor bx,bx
.f: cmp word [si+0x10],0
    jz .n
    or ah,ah
    jz .got
    dec ah
.n: add si,0xc0
    inc bx
    cmp bx,64
    jb .f
.r: ret
.got: mov [VPICK],bl
    mov al,'>'              ; '>05 TST A' until selected
    jmp VLINE
.sel: cmp al,64
    jb .r
    cmp byte [BKON],0       ; voice mode only, not while recording or capturing
    jnz .r
    cmp byte [CAPON],0
    jnz .r
    mov al,[RST]
    or al,al
    jz .ok
    cmp al,3
    jbe .r
.ok: mov bl,[VPICK]
    cmp bl,64
    jae .r
    mov al,0xc0
    mul bl
    add ax,0x2288
    mov si,ax
    cmp word [si+0x10],0
    jz .r
    xor bh,bh
    push bx
    push si
    call LVOFF              ; as NEW VOICE: live FX released, slices stop, back to the voice
    mov byte [CHPLAY],0
    call VDIRECT
    pop si
    pop bx
    mov [0xe04],si
    mov word [0xe06],0
    mov [0xe02],bx
    mov [RV],si
    mov [CURV],si
    mov byte [RETN],1       ; keep its sound
    call PSETUP
    mov byte [RETN],0
    mov byte [VPICK],0xff
    jmp STAT2

NORMCC:             ; CC101 >= 120: normalise the voice between its start and end points (peak -0.5 dB)
    cmp al,64
    jae .hi
    mov byte [NARM],0
    ret
.hi: cmp al,120
    jb .r
    cmp byte [NARM],0
    jnz .r
    mov byte [NARM],1
    cmp byte [PREADY],0
    jz .r
    mov al,[RST]
    cmp al,1
    jb .ok
    cmp al,3
    jbe .r                  ; not while recording
.ok: call LVOFF              ; PERF38I: live FX released first (its clean copy would undo the normalise)
    call L61DB
    mov bx,S_NB
    call NMSG
    call NSETUP
    jc .r
    xor bp,bp               ; pass 1: peak of |sample|
.p1: mov ax,[es:si]
    or ax,ax
    jns .a1
    neg ax
    jns .a1
    mov ax,0x7fff
.a1: cmp ax,bp
    jbe .a2
    mov bp,ax
.a2: call NNEXT
    jnz .p1
    mov [NPK],bp
    or bp,bp
    jnz .g
    mov bx,S_NS
    jmp NMSG
.g: mov dx,0x0078           ; G (8.8) = 30934 * 256 / peak, max 255.99
    mov ax,0xd600
    cmp dx,bp
    jb .dv
    mov ax,0xffff
    jmp .gg
.dv: div bp
.gg: mov [NG],ax
    cmp ax,0x100
    ja .p2s
    mov bx,S_NF
    jmp NMSG
.p2s: call L61DB          ; si = voice again (pass 1 used si for the wave pointer)
    call NSETUP
.p2: mov ax,[es:si]         ; pass 2: sample * G / 256
    or ax,ax
    jns .b1
    neg ax
    mul word [NG]
    mov al,ah
    mov ah,dl
    neg ax
    jmp .b2
.b1: mul word [NG]
    mov al,ah
    mov ah,dl
.b2: mov [es:si],ax
    call NNEXT
    jnz .p2
    mov ax,[NG]             ; show gain as xNNN.NN
    mov di,S_NG+1
    push ax
    mov al,ah
    xor ah,ah
    mov bl,100
    div bl
    add al,0x30
    mov [di],al
    mov al,ah
    aam
    add ax,0x3030
    xchg al,ah
    mov [di+1],ax
    pop ax
    xor ah,ah
    mov dx,100
    mul dx
    mov al,ah
    aam
    add ax,0x3030
    xchg al,ah
    mov [di+4],ax
    mov bx,S_NG
    push ds
    pop es
    jmp NMSG
.r: ret

CHFIND:             ; PERF restarted: find the CHOP bank, re-link its slices and their source voice
    mov bx,0xe08
    mov cx,8
.f: cmp word [bx+0x282],'CH'
    jnz .n
    cmp word [bx+0x284],'OP'
    jz .got
.n: add bx,0x290
    loop .f
    ret
.got: mov [CHBANK],bx
    mov cx,[bx]
    jcxz .r
    cmp cx,32
    ja .r
    xor di,di
.c: mov ax,[bx+di+0x202]
    or ax,ax
    jz .r
    push di
    mov di,ax
    cmp word [di+0x10],0
    pop di
    jz .r
    mov [di+CHV],ax
    add di,2
    loop .c
    mov al,[bx]
    mov [CHCNT],al
    mov ah,4                ; PERF40D: the slice count asked for: 4, 8, 16 or 32, at least the slices found
.cn: cmp ah,al
    jae .cs
    shl ah,1
    jmp .cn
.cs: mov [CHN],ah
    cmp byte [bx+0x287],'V'
    jnz .r
    mov al,[bx+0x288]
    sub al,'0'
    cmp al,9
    ja .r
    mov ah,10
    mul ah
    mov dl,[bx+0x289]
    sub dl,'0'
    cmp dl,9
    ja .r
    add al,dl
    dec al
    cmp al,63
    ja .r
    mov ah,0xc0
    mul ah
    add ax,0x2288
    mov [CHOWN],ax
    call L61DB
    jmp CHPROP
.r: ret

FREEZE:             ; PERF40J control 15 (>= 64): let go of the chop. Its slices and places stay as plain bank voices; the
    cmp al,64               ; next chop makes a new one. Its own CHOP bank is renamed 'SLC' (so a restart doesn't take it back).
    jb .r
    mov bx,[CHBANK]
    or bx,bx
    jz .m
    cmp byte [CHMOD],0
    jnz .z
    mov word [bx+0x282],'SL'
    mov word [bx+0x284],'C '
.z: cmp byte [CHPLAY],0
    jz .z2
    mov byte [CHPLAY],0
    call BKBACK
.z2: xor ax,ax
    mov [CHBANK],ax
    mov [CHOWN],ax
    mov [CHCNT],al
    mov [CHBASE],ax
    mov [CHMOD],al
.m: mov bx,S_FRZ
    jmp NMSG
.r: ret
CHBSEL:             ; PERF40J, from CHOP: bx = the chop's bank with [bx] = its places before the slices; CF=1 none
    mov bx,[CHBANK]
    or bx,bx
    jz .new
    mov ax,[CHBASE]         ; chop again: the same bank, from the same place
    mov [bx],ax
    clc
    ret
.new: mov al,[CHTO]
    mov [CHMOD],al
    or al,al
    jnz .to
    mov bx,0xe08            ; own CHOP bank: the first empty one, named 'CHOP'
    mov cx,8
.fb: cmp word [bx],0
    jz .own
    add bx,0x290
    loop .fb
    mov bx,S_CB
    call NMSG
    stc
    ret
.own: mov word [CHBASE],0
    mov [CHBANK],bx
    mov word [bx],0
    lea di,[bx+0x282]
    mov word [di],'CH'
    mov word [di+2],'OP'
    mov ax,'  '
    mov cx,4
.nm: mov [di+4],ax
    add di,2
    loop .nm
    clc
    ret
.to: call PBFIND            ; the target: chosen bank, FZED BANK, or a new FZED BANK
    jnc .t1
    mov bx,S_NBX
    call NMSG
    stc
    ret
.t1: mov ax,[bx]
    mov [CHBASE],ax
    mov [CHBANK],bx
    clc
    ret
S_FRZ: db 'CHOP FROZEN     ',0
S_NB: db 'NORMALISING... ',0
S_NS: db 'NORM: SILENT   ',0
S_NF: db 'NORM: FULL     ',0
S_NG: db 'x000.00 NORM   ',0
%if ($-$$) > 0x3BE
%error tools overlay 3 reaches its end signature (D7BEh)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4030
    times 0x400-($-$$) db 0x5a
