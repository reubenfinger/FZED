; ---------- FZED wave overlay: disk sector 50 (signature 4032h at D400h and D7BEh), loaded into D400h-D7BFh by WVCC
; (fx/fx4m.asm) through OVCALL. The preset wave generator, moved here unchanged from fx4m.asm to free the lv area.
; FZ calls (ROM 117 allocate, 119 delete via WVSH, others via INIT / AFTER) run on the stack at DBFEh, which reaches
; down to about D7ECh: keep this code at the bottom and the top of the sector empty; add new waves after the old ones.
; After the first FZ calls the end signature is checked: if the stack reached it, the load is refused.
    dw 0x4032
WVLOAD:
    cmp byte [CAPON],0      ; PERF38M: not while capture mode runs
    jnz .no
    cmp byte [BKON],0       ; CC16 is NEW VOICE now; never use a stale bank-wave target
    jnz .no
    call LVOFF              ; PERF38J: live FX released first (as chop / normalise), not a refusal
    cmp byte [CHCNT],0
    jnz .no
    mov al,[RST]
    cmp al,1
    jb .rs
    cmp al,3
    jbe .no
.rs: call WVSH              ; voice mode: the current edit voice (PERF40A: a shared wave is let go first)
    mov [WTV],si
    mov byte [WNEW],0
    cmp word [si+0x10],0
    jnz .hv
    push word 0             ; PERF38K: empty voice: allocate 1808 words, INIT envelopes / filter
    push word 1816          ; PERF38L: 1808 written + 8 guard words
    push word 0
    push si
    APIC 117,8
    mov si,[WTV]
    or bx,bx
    jnz .no
    mov word [si+0x10],0x1d7
    mov ax,0x007f
    call INIT
    mov byte [WNEW],1
    mov si,[WTV]
.hv:
    cmp word [0xD7BE],0x4032   ; FZED: the FZ calls' stack must not have reached this overlay
    jnz .no
    mov bx,[si]             ; PERF38L: the stored wave start / end, not the (pot-moved) play start / end
    mov cx,[si+2]
    and cx,0x1f
    mov [WST],bx
    mov [WST+2],cx
    mov ax,[si+4]
    mov dx,[si+6]
    and dx,0x1f
    sub ax,bx
    sbb dx,cx
    jc .no
    jnz .ok
    cmp ax,1808
    jae .ok
.no: mov bx,S_WR
    jmp NMSG
.ok: xor ax,ax
    mov [WPH],ax
    mov [WPH+2],ax
    xor bp,bp
.ch: mov cx,1808            ; PERF38L: 1800-word loop + 8 words of the wave continued
    sub cx,bp
    jz .done
    cmp cx,128
    jbe .g
    mov cx,128
.g: push cx
    mov di,LVBUF
.w: push cx
    push di
    mov ax,[WPH+2]
    call WVF
    mov dx,26214            ; 0.8 of full scale
    imul dx
    shl ax,1
    rcl dx,1
    pop di
    mov [di],dx
    add di,2
    add word [WPH],0x820a        ; 11 cycles in 1800 words: 11 * 2^32 / 1800
    adc word [WPH+2],0x0190
    pop cx
    loop .w
    pop cx
    push cx
    mov ax,[WST]
    mov dx,[WST+2]
    add ax,bp
    adc dx,0
    call LVWR
    push ds
    pop es
    pop cx
    add bp,cx
    jmp .ch
.done: mov si,[WTV]
    mov word [si+0x12],0    ; loop 0 as sustain and end loop
    mov ax,[WST]            ; PERF38L: play start = loop start = wave start, loop end = +1800 (loop length
    mov cx,[WST+2]          ; = end - start: the generator jumps back on reaching the end), play end = +1808;
    mov dx,[si+0xa]         ; no loop fine / jump flags, no crossfade, loop time as the FZ's own loops (1022)
    and dx,0xffe0
    or dx,cx
    mov [si+8],ax
    mov [si+0xa],dx
    mov [si+0x14],ax
    mov [si+0x16],cx
    add ax,1800
    adc cx,0
    mov [si+0x34],ax
    mov [si+0x36],cx
    add ax,8
    adc cx,0
    mov dx,[si+0xe]
    and dx,0xffe0
    or dx,cx
    mov [si+0xc],ax
    mov [si+0xe],dx
    mov word [si+0x54],0
    mov word [si+0x64],1022
    mov word [si+0xae],0x155d       ; highest key 93, lowest 21
    mov word [si+0xb0],57           ; original key A (220 Hz), rate 36k
    cmp byte [BKON],0               ; bank mode: no snapshot; CC15 ADD VOICE puts it on a channel
    jnz .ms
    cmp byte [WNEW],0
    jz .od
    call AFTER                      ; new voice: set up and assigned as a new take is
    jmp short .ms
.od: mov byte [RETN],1               ; new baseline, voice kept
    call PSETUP
    mov byte [RETN],0
.ms:
    mov al,[WSEL]
    inc al
    mov di,S_WV+5
    call DEC2
    mov bx,S_WV
    jmp NMSG

WVF:                ; ax = phase -> ax = sample of wave WSEL (keeps bp)
    mov bl,[WSEL]
    xor bh,bh
    shl bx,1
    jmp [cs:bx+WVT]         ; PERF39F: WSEL is 0-based since PERF39C (0 = saw); WVT-2 jumped off the table
WVT: dw .saw,.sq,.p25,.p12,.tri,.sin,.dsin
.saw: xor ax,0x8000
    ret
.p12: cmp ax,0x2000
    jmp .pl
.p25: cmp ax,0x4000
    jmp .pl
.sq: cmp ax,0x8000
.pl: mov ax,32767
    jb .r
    neg ax
.r: ret
.tri: add ax,0x4000           ; FZED: start a quarter cycle in, at zero going up: no step from silence at note-on
    test ax,0x8000
    jz .t1
    not ax
.t1: shl ax,1
    xor ax,0x8000
    ret
.sin: jmp SIN
.dsin: mov si,ax
    call SIN
    sar ax,1
    mov di,ax
    mov ax,si
    shl ax,1
    call SIN
    sar ax,1
    add ax,di
    ret
SIN:                ; ax = phase -> ax = sine (Q15), interpolated (keeps si di bp)
    mov bl,ah
    xor bh,bh
    shl bx,1
    mov cl,al
    call SINR               ; PERF38K: quarter-wave table
    add bx,2
    and bx,0x1fe
    push ax
    call SINR
    mov dx,ax
    pop ax
    sub dx,ax
    push ax
    mov al,cl
    xor ah,ah
    imul dx
    mov al,ah
    mov ah,dl
    pop dx
    add ax,dx
    ret

S_WV: db 'WAVE 00 LOADED  ',0

%if ($-$$) > 0x3A0
%error wave overlay reaches the top of its sector (keep D7A0h-D7BDh clear for the FZ-call stack margin)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4032
    times 0x400-($-$$) db 0x5a
