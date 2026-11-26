; ---------- EXT module 2: BACKUP (RH6: was 3), disk sector 53, tool. FZED 19 = 16-23 picks it; Render (CC118) runs it.
; Copies the edit voice into the first empty voice WITH ITS OWN COPY OF THE SAMPLE (Copy Voice shares the sample, so a
; render changes both). The edit voice stays the edit voice: render on it, and if the result is no good, pick the
; backup with Voice Select. The FZ shows BACKUP IN V05 (the backup's voice number), or why there is none.
; The copied range is the one live FX and Render work on: the sample start to end as FZED took the voice (GSAVE to AE),
; and its last word. The backup's voice data (start, end, the eight loops, envelopes and the rest) is the edit voice's
; as it is now, with every address that lies in that range moved to the copy; any outside it are left as they are.
; Uses the FZ's allocate call (117) as live FX do; the copy goes through LVBUF 128 words at a time.
    dw 0x4035
    db 1, 2                 ; ABI 1, tool
    dw LOWEND,HIGHEND,LVEND,XTEND
    db 'EXT BACKUP',0
    times 0x20-($-$$) db 0
    clc                     ; +20h init: nothing to check
    ret
    nop
    jmp near BKRUN          ; +23h
BKSRC: dw 0                 ; the edit voice
BKDST: dw 0                 ; the backup's voice slot
BKG0: dd 0                  ; the range's first word (GSAVE, 21-bit)
BKLEN: dd 0                 ; words copied (AE - GSAVE + 1)
BKNEW: dd 0                 ; the copy's first word
BKCP: dd 0                  ; words copied so far
S_BKE: db 'BACKUP: NO VOICE',0
S_BKF: db 'BACKUP: NO SLOT',0
S_BKM: db 'BACKUP: NO MEMORY',0
S_BKD: db 'BACKUP IN V00',0
BKRUN:              ; si = the edit voice
    cld
    mov bx,S_BKE
    cmp word [si+0x10],0
    jnz .h
.m: jmp NMSG
.h: mov [BKSRC],si
    mov ax,[GSAVE]
    mov dx,[GSAVE+2]
    and dx,0x1f
    mov [BKG0],ax
    mov [BKG0+2],dx
    mov cx,[AEL]
    mov bx,[AEH]
    and bx,0x1f
    sub cx,ax
    sbb bx,dx
    jnc .ok
    mov bx,S_BKE            ; (end before start: nothing sensible to copy)
    jmp NMSG
.ok: add cx,1
    adc bx,0
    mov [BKLEN],cx
    mov [BKLEN+2],bx
    mov di,0x2288           ; the first empty voice slot
    mov cx,64
.fv: cmp word [di+0x10],0
    jz .got
    add di,0xc0
    loop .fv
    mov bx,S_BKF
    jmp NMSG
.got: mov [BKDST],di
    mov ax,[BKLEN]
    mov dx,[BKLEN+2]
    add ax,8                ; + 8 guard words, as the wave overlay allocates
    adc dx,0
    push di
    push dx
    push ax
    push word 0
    push di
    APIC 117,8
    pop di
    or bx,bx
    jz .al
    mov bx,S_BKM
    jmp NMSG
.al: mov ax,[di+8]
    mov dx,[di+0xa]
    and dx,0x1f
    mov [BKNEW],ax
    mov [BKNEW+2],dx
    xor ax,ax
    mov [BKCP],ax
    mov [BKCP+2],ax
.cl: mov ax,[BKLEN]         ; the sample, 128 words at a time
    mov dx,[BKLEN+2]
    sub ax,[BKCP]
    sbb dx,[BKCP+2]
    mov cx,128
    or dx,dx
    jnz .c
    cmp ax,cx
    jae .c
    mov cx,ax
.c: jcxz .rec
    push cx
    mov ax,[BKG0]
    mov dx,[BKG0+2]
    add ax,[BKCP]
    adc dx,[BKCP+2]
    call LVRD
    pop cx
    push cx
    mov ax,[BKNEW]
    mov dx,[BKNEW+2]
    add ax,[BKCP]
    adc dx,[BKCP+2]
    call LVWR
    push ds
    pop es
    pop cx
    add [BKCP],cx
    adc word [BKCP+2],0
    jmp .cl
.rec: mov si,[BKSRC]        ; the voice data after the allocation's own first 8 bytes
    mov di,[BKDST]
    add si,8
    add di,8
    mov cx,0xb8
    push ds
    pop es
    cld
    rep movsb
    mov di,[BKDST]          ; start, end and the eight loops' starts and ends: moved to the copy
    lea bx,[di+8]
    call BKADJ
    lea bx,[di+0xc]
    call BKADJ
    lea bx,[di+0x14]
    mov cx,16
.lp: call BKADJ
    add bx,4
    loop .lp
    mov ax,di               ; BACKUP IN Vnn
    sub ax,0x2288
    mov bl,0xc0
    div bl
    inc al
    mov di,S_BKD+11
    call DEC2
    mov bx,S_BKD
    jmp NMSG
BKADJ:              ; the address dword at [bx] (21 bits, flags above): if in BKG0 .. BKG0 + BKLEN - 1, moved by BKNEW - BKG0
    push cx
    mov ax,[bx]
    mov dx,[bx+2]
    mov cx,dx
    and dx,0x1f
    sub ax,[BKG0]
    sbb dx,[BKG0+2]
    jc .r                   ; before the range
    cmp dx,[BKLEN+2]
    jb .in
    ja .r
    cmp ax,[BKLEN]
    jae .r                  ; after it
.in: add ax,[BKNEW]
    adc dx,[BKNEW+2]
    and dx,0x1f
    and cx,0xffe0           ; the flags kept
    or dx,cx
    mov [bx],ax
    mov [bx+2],dx
.r: pop cx
    ret

%if ($-$$) > 0x3A0
%error EXT module 3 reaches the top of its sector
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4035
    times 0x400-($-$$) db 0x5a
