; ---------- PERF40L tools overlay 4: disk sector 49 (signature 4031h at D400h and D7BEh): STRETCH (moved from tools
; overlay 2) with NEXT (trace / skip), ORDER and SKEW. Controls 6, 7 and 10 still live in tools overlay 2 (sector 47).
    dw 0x4031
STNX equ 0x801A             ; PERF40L control 16: >= 64 the stretch loops SKIP (jump loop to loop), else TRACE; PERF40M: bit 5
                            ; = LEAD-IN CUT (the note starts at the first loop, not at the voice's start)
STOR equ 0x801B             ; control 17: segment order 0 forward, 1 reverse, 2 there and back, 3 shuffle (raw 0-127)
STSK equ 0x801C             ; control 18: skew of the loop times, 64 = even, below = earlier ones longer, above = later
STRETCH:            ; PERF parameter 89 with control [STSEL] (parameter 88): 0 segments, 1 stretch (loop time), 2 grain,
    mov bl,[STSEL]          ; 3 crossfade, 4 snap, 5 sustain at, 9 on / off, 16 next, 17 order, 18 skew. The play range is
    cmp bl,16               ; cut into 2-8 segments, one of the FZ's loops each (a loop time each).
    jae .hi
    cmp bl,6
    jb .lo
    cmp bl,9
    jnz .o2
.lo: cmp bl,9
    jz .onoff
    cmp bl,5
    ja .r0
    xor bh,bh
    cmp bl,5
    jnz .st
    and byte [STSU],0x80    ; (sustain keeps the on flag in bit 7)
    or [STSU],al
    jmp .chk
.st: mov [bx+STN],al
.chk: test byte [STSU],0x80
    jnz BUILD
.r0: ret
.hi: cmp bl,18
    ja .r0
    xor bh,bh
    mov [bx+STNX-16],al
    jmp .chk
.o2: push word STRET2        ; 6 CHOP INTO, 7 CAPTURE ON, 10 per slice (8 nothing): tools overlay 2
    push word 0x402F
    jmp OVCALL
.onoff: cmp al,64
    jae .on
    test byte [STSU],0x80
    jz .r0
    jmp .o2                 ; PERF40M: OFF (rare) runs in tools overlay 2: loops and start back
.on: or byte [STSU],0x80
BUILD:
    call L61DB
    cmp word [si+0x10],0
    jz .r
    mov al,[STN]            ; N = 2-8
    mov ah,7
    mul ah
    shl ax,1
    add ah,2
    mov [STK],ah            ; (scratch: N)
    call STOWN5             ; PERF40M: start moved by LEAD-IN CUT (and not touched since): work from the saved start
    jnz .rs
    mov cx,[STRS]
    mov bl,[STRSH]
    xor bh,bh
    jmp short .rs1
.rs: mov cx,[si+8]
    mov bx,[si+0xa]
    and bx,0x1f
    mov [STRS],cx
    mov [STRSH],bl
.rs1: mov ax,[si+0xc]       ; length = end - start (21-bit word addresses)
    mov dx,[si+0xe]
    and dx,0x1f
    mov [STA],cx            ; (scratch: start of the play range, dword)
    mov [STA+2],bx
    sub ax,cx
    sbb dx,bx
    jc .sh
    mov cl,[STK]            ; segment = length / N (two steps: the length is up to 21 bits)
    xor ch,ch
    push ax
    mov ax,dx
    xor dx,dx
    div cx
    mov bx,ax
    pop ax
    div cx                  ; bx:ax = segment
    or bx,bx
    jnz .ok
    cmp ax,64
    jae .ok
.sh: mov bx,S_STS
    jmp NMSG
.r: ret
.ok: mov [STL],ax           ; (scratch: segment length)
    mov [STL+2],bx
    mov cl,[STG]            ; grain = segment * (G + 1) / 128, at least 32 words
    inc cx
    xor ch,ch
    mul cx
    push dx
    push ax
    mov ax,bx
    mul cx
    pop bx                  ; low word
    pop dx
    add dx,ax               ; dx:bx = segment * (G + 1)
    mov ax,bx
    mov cx,7
.g7: shr dx,1
    rcr ax,1
    loop .g7
    or dx,dx
    jnz .gok
    cmp ax,32
    jae .gok
    mov ax,32
.gok: mov [STW],ax          ; (scratch: grain, dword)
    mov [STW+2],dx
    mov al,[STT]            ; loop time = 1 + T*T*1000/16384 (1-985), about 19.8 ms a step (hardware timing)
    mul al
    mov cx,1000
    mul cx
    mov cx,14
.t14: shr dx,1
    rcr ax,1
    loop .t14
    inc ax
    mov [STTV],ax
    mov al,[STSK]           ; skew step D = T * (S - 64) / 64 / (N - 1) per loop, signed
    sub al,64
    cbw
    imul word [STTV]
    mov cx,6
.d6: sar dx,1
    rcr ax,1
    loop .d6
    mov cl,[STK]
    dec cx
    xor ch,ch
    cwd
    idiv cx
    mov [STSD],ax
    xor bx,bx               ; ORDER: STO[i] = segment for loop i
.oi: mov [bx+STO],bl
    inc bx
    cmp bx,8
    jb .oi
    mov cl,[STK]            ; (cx = N)
    mov al,[STOR]
    shr al,5
    jz .ofw
    cmp al,2
    jb .orv
    ja .osh
    xor bx,bx               ; there and back: 0 2 4 .. then .. 5 3 1
.otb: mov al,bl
    shl al,1
    cmp al,cl
    jb .ot1
    mov al,cl
    sub al,bl
    dec ax
    shl al,1
    inc ax
.ot1: mov [bx+STO],al
    inc bx
    cmp bl,cl
    jb .otb
    jmp short .ofw
.orv: xor bx,bx             ; reverse: N-1 .. 0
.or1: mov al,cl
    sub al,bl
    dec ax
    mov [bx+STO],al
    inc bx
    cmp bl,cl
    jb .or1
    jmp short .ofw
.osh: mov al,[STOR]          ; shuffle: each ORDER pot position in the shuffle range is its own fixed order
    mov ah,al
    mov di,ax
    mov bx,1
.os1: mov ax,di             ; j = random % (i + 1); swap loop i and loop j
    mov dx,25173
    mul dx
    add ax,13849
    mov di,ax
    mov al,ah
    xor ah,ah
    mov dl,bl
    inc dx
    div dl
    push bx
    mov al,ah
    xor ah,ah
    xchg ax,bx
    mov dl,[bx+STO]
    xchg ax,bx
    xchg dl,[bx+STO]
    xchg ax,bx
    mov [bx+STO],dl
    pop bx
    inc bx
    cmp bl,cl
    jb .os1
.ofw: xor bx,bx             ; bx = 4 * loop
.lp: mov al,bl
    shr al,2
    cmp al,[STK]
    jae .park
    push bx                 ; segment start = range start + STO[i] * segment, snapped
    shr bx,2
    mov cl,[bx+STO]
    pop bx
    xor ch,ch
    mov ax,[STA]
    mov dx,[STA+2]
    jcxz .s0
.sm: add ax,[STL]
    adc dx,[STL+2]
    loop .sm
.s0: call .snap
    mov [bx+si+0x14],ax
    mov [bx+si+0x16],dx
    add ax,[STW]            ; + grain, snapped
    adc dx,[STW+2]
    call .snap
    cmp byte [STNX],64      ; NEXT: SKIP = bit 7 of the loop end (the FZ's LOOP NEXT setting), TRACE = clear
    jb .tr
    or dh,0x80
.tr: mov [bx+si+0x34],ax
    mov [bx+si+0x36],dx
    mov al,[STX]            ; crossfade (as CC72: value x 8)
    xor ah,ah
    shl ax,3
    push ax
    mov ax,bx               ; loop time = T + (2i - (N-1)) * D: T * (1 -/+ skew) at the ends, kept within 1-1023
    shr ax,1
    mov cl,[STK]
    xor ch,ch
    sub ax,cx
    inc ax
    imul word [STSD]
    add ax,[STTV]
    cmp ax,1
    jge .l1
    mov ax,1
.l1: cmp ax,1023
    jle .l2
    mov ax,1023
.l2: mov cx,ax
    pop ax
    jmp .wr
.park: mov ax,[si+0xc]      ; unused loops parked at the end
    mov dx,[si+0xe]
    and dx,0x1f
    mov [bx+si+0x14],ax
    mov [bx+si+0x16],dx
    mov [bx+si+0x34],ax
    mov [bx+si+0x36],dx
    xor ax,ax
    xor cx,cx
.wr: push bx
    shr bx,1
    mov [bx+si+0x54],ax
    mov [bx+si+0x64],cx
    pop bx
    add bx,4
    cmp bx,32
    jb .lp
    mov al,[STK]            ; end loop = the last one; sustain = none or the loop chosen
    dec ax
    mov [si+0x13],al
    mov al,[STSU]
    and al,0x7f
    mov ah,[STK]
    inc ah
    mul ah
    shl ax,1
    mov al,ah               ; 0 = none, 1-N = that loop
    dec al
    jns .su
    mov al,8
.su: mov [si+0x12],al
    test byte [STNX],0x20   ; PERF40M LEAD-IN CUT: the voice starts at the first loop when that isn't the range start
    jz .lp0
    cmp byte [STO],0
    jz .lp0
    mov ax,[si+0x14]
    mov [si+8],ax
    mov al,[si+0x16]
    and al,0x1f
    and byte [si+0xa],0xe0
    or [si+0xa],al
    mov byte [STMV],1
    jmp short .lpd
.lp0: cmp byte [STMV],0     ; (PLAY, or forward: the start goes back if STRETCH moved it)
    jz .lpd
    call STRSB5
.lpd:
    mov al,[STK]            ; 'ST8 T04.1 G01.41': segments, loop time (s), one grain pass at the original key (s)
    add al,'0'
    mov [S_STR+2],al
    mov ax,[STTV]           ; tenths = T * 198 / 1000
    mov cx,198
    mul cx
    add ax,500              ; (rounded)
    adc dx,0
    mov cx,1000
    div cx
    xor dx,dx               ; 3 digits ending one early, then the last moved right past the point
    mov di,S_STR+7
    mov cx,3
    call DECN
    mov al,[S_STR+7]
    mov [S_STR+8],al
    mov byte [S_STR+7],'.'
    mov ax,[STW]            ; hundredths = grain words << rate / 360 (36k = rate 0)
    mov dx,[STW+2]
    mov cl,[si+0xb1]
    and cl,3
    jz .gr
.gs: shl ax,1
    rcl dx,1
    dec cl
    jnz .gs
.gr: mov cx,360
    div cx
    cmp ax,9999
    jbe .g9
    mov ax,9999
.g9: xor dx,dx
    mov di,S_STR+14
    mov cx,4
    call DECN
    mov ax,[S_STR+13]
    mov [S_STR+14],ax
    mov byte [S_STR+13],'.'
    mov bx,S_STR
    jmp NMSG
.snap: cmp byte [STZ],64    ; snap on: nearest zero crossing (within 256 words)
    jb .ns
    call ZCNEAR
.ns: ret

STOWN5:             ; PERF40M: ZF=1 if STRETCH moved this voice's start (it still equals loop 1's start), else STMV cleared
    cmp byte [STMV],0
    jz .no
    mov ax,[si+8]
    cmp ax,[si+0x14]
    jnz .no
    mov al,[si+0xa]
    xor al,[si+0x16]
    and al,0x1f
    jz .r
.no: mov byte [STMV],0
    or sp,sp
.r: ret
STRSB5:             ; PERF40M: the saved start back into the voice
    mov ax,[STRS]
    mov [si+8],ax
    mov al,[STRSH]
    and byte [si+0xa],0xe0
    or [si+0xa],al
    mov byte [STMV],0
    ret

STK  equ 0xD7A0             ; scratch in this overlay's own area (below the end signature)
STA  equ 0xD7A2
STL  equ 0xD7A6
STW  equ 0xD7AA
STTV equ 0xD7AE
STSD  equ 0xD7B0             ; skew step
STB  equ 0xD7B2
STO  equ 0xD7B4             ; 8 bytes: segment of each loop (to D7BBh)
S_STR: db 'ST8 T00.0 G00.00',0
S_STS: db 'TOO SHORT',0

%if ($-$$) > 0x3A0
%error tools overlay 4 reaches its scratch area (D7A0h)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4031
    times 0x400-($-$$) db 0x5a
