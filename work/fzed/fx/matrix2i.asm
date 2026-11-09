; ---------- PERF38: matrix helpers moved to sectors 38-40 (ENVDIR, FZ keyboard queue reader) ----------
ENVDIR:             ; after any voice write: each envelope step heads the right way to its level
    push ax             ; (down if its level is below the previous step's, otherwise up)
    push bx
    push cx
    push dx
    push di
    lea di,[si+0x7a]        ; DCA rates (levels at +8)
    call .g
    lea di,[si+0x8c]        ; DCF rates (levels at +8)
    call .g
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.g: xor dl,dl               ; envelope starts from 0
    xor bx,bx
    mov cx,8
.l: mov al,[bx+di+8]
    mov ah,[bx+di]
    and ah,0x7f
    cmp al,dl
    jae .u
    or ah,0x80
.u: mov [bx+di],ah
    mov dl,al
    inc bx
    loop .l
    ret

IQSCAN:             ; read (without taking) the ROM's own event queues: FZ keyboard velocity/note, wheel, aftertouch, bend
    push si
    xor si,si
    mov di,0xade            ; queue 0: ring ADEh, write index BE0h
    mov bx,0xbe0
    call .q
    inc si
    mov di,0xce6            ; queue 2: ring CE6h, write index DE8h
    mov bx,0xde8
    call .q
    pop si
    ret
.q: mov dl,[bx]
    mov al,[si+IQP]
    cmp al,dl
    jz .r
    inc byte [si+IQP]
    push bx
    xor ah,ah
    mov bx,ax
    mov al,[bx+di]
    call IQB
    pop bx
    jmp .q
.r: ret
IQB:                ; al = byte from queue si
    cmp al,0xf8
    jae .x
    cmp al,0x80
    jb .d
    cmp al,0xf0
    jb .s
    xor al,al
.s: mov [si+IQS],al
    mov byte [si+IQC],0
.x: ret
.d: mov dl,[si+IQS]
    or dl,dl
    jz .x
    mov bl,dl
    and bx,0x0f
    cmp byte [BKON],0       ; voice mode: feeds the voice (omni), as MIDI does
    jnz .c
    mov bl,[CURCH]
    and bx,0x0f
.c: and dl,0xf0
    cmp dl,0xd0
    jz .at
    cmp dl,0xc0
    jz .x
    cmp byte [si+IQC],0
    jnz .t
    mov [si+IQD],al
    inc byte [si+IQC]
    ret
.t: mov byte [si+IQC],0
    mov ah,[si+IQD]
    cmp dl,0xa0
    jz .at
    cmp dl,0x90
    jnz .nb
    or al,al
    jz .qof
    mov [bx+CVEL],al
    call PNON2              ; PERF38I: same pattern restart as a DIN note
    mov [bx+CNOTE],ah
    call RAND
    mov [bx+CRND],al
    ret
.nb: cmp dl,0xe0
    jnz .nc
    sub al,64
    shl al,1
    mov [bx+CBEND],al
    ret
.nc: cmp dl,0xb0
    jz .ncb
    cmp dl,0x80
    jnz .x
.qof: jmp PNOFF
.ncb:
    cmp ah,1
    jnz .n1
    mov [bx+CMW],al
    ret
.n1: cmp ah,4
    ja .x
    cmp ah,2
    jb .x
    mov cl,4
    shl ah,cl
    add bl,ah
    mov [bx+MISC+0xB0],al   ; CC2-4 -> CM2-CM4 (D0h, E0h, F0h)
    ret
.at: mov [bx+CAT],al
    ret
