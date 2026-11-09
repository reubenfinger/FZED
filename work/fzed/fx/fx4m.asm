; ---------- PERF38G (PERF38L loop / reload fixes): preset waves written by PERF, and FZ calls on a big stack (code at B900h-BBFFh) ----------
; Preset waves: CC111 picks one of 8 bands (v / 8: 0 off, 1-7 waves), CC9 below 64 arms, 120-127 loads it once.
; PERF writes 1800 words (11 cycles, 220 Hz at 36k) at the edit voice's start, sets loop 0 over them as both the
; sustain and the end loop, original key 57 (A), keys 21-93, rate 36k, then takes the voice as its new baseline
; (as at start: snapshots, no INIT). No FZ synthesis calls. The rest of the sample stays after the loop end.
; Refused with live FX on, in bank mode, with chop slices, while recording, or if the voice is under 1800 words.
WSEL equ 0xD2E0             ; (free RAM D2D0h-D3FFh)
WARM equ 0xD2E1
WPH equ 0xD2E4              ; dword
WST equ 0xD2E8              ; dword
SWSP equ 0xD2EC
SWBX equ 0xD2EE
WTV equ 0xD2D6              ; PERF38K: voice the wave goes into
WNEW equ 0xD2D8             ; PERF38K: 1 = it was empty and has just been allocated
S_WV: db 'WAVE 00 LOADED  ',0
S_WR: db 'WAVE: REFUSED   ',0

L6004X:             ; FZ call: with live FX off, run it on the 2 KB KSB area (FZ calls can need over 1 KB)
    pop word [0x55f6]
    cmp byte [LVON],0
    jnz .p
    cmp byte [CAPON],0      ; PERF38M: capture mode overlay occupies the KSB area
    jnz .p
    cmp sp,0xec00           ; only from PERF's own stack
    jb .p
    mov [SWSP],sp
    mov [SWBX],bx
    mov bx,sp
    mov sp,0xdbfe
    push word [bx+14]       ; the call number and up to 7 arguments
    push word [bx+12]
    push word [bx+10]
    push word [bx+8]
    push word [bx+6]
    push word [bx+4]
    push word [bx+2]
    push word [bx]
    mov bx,[SWBX]
    int3
    mov sp,[SWSP]
    push word [0x55f6]
    ret
.p: int3
    push word [0x55f6]
    ret

WVSEL:              ; CC111
    shr al,3
    jz .off
    dec al
    mov [WSEL],al
    ret
.off: mov byte [WSEL],0xff
    ret
WVCC:               ; CC9
    cmp al,64
    jae .h
    mov byte [WARM],1
    ret
.h: cmp al,120
    jb .r
    cmp byte [WARM],0
    jz .r
    mov byte [WARM],0
    cmp byte [WSEL],7
    jae .r
    jmp WVLOAD
.r: ret

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
.tri: test ax,0x8000
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

NEWVOICE:           ; CC16: choose the first empty voice after an armed rising edge
                    ; FZ Voice Edit selector at ROM 0x787B-0x7892 sets evn/ev/segment at E02/E04/E06.
    cmp byte [BKON],0
    jnz .done
    cmp al,64
    jae .high
    mov byte [ADDV],0
.done: stc
    ret
.high: cmp al,120
    jb .done
    cmp byte [ADDV],0
    jnz .done
    mov byte [ADDV],1
    cmp byte [CAPON],0
    jnz .busy
    mov al,[RST]
    or al,al
    jz .scan0
    cmp al,3                ; PERF39D: 4 = DONE (a finished recording) is not busy
    jbe .busy
.scan0: mov si,0x2288
    xor bx,bx
.scan: cmp word [si+0x10],0
    jz .found
    add si,0xc0
    inc bx
    cmp bx,64
    jb .scan
    mov bx,S_NEVF
    jmp NMSG
.found:
    push si
    call LVOFF              ; PERF39D: live FX released, slices stop, back to the voice
    mov byte [CHPLAY],0
    call VDIRECT
    pop si
    mov [0xe04],si
    mov word [0xe06],0
    mov [0xe02],bx
    mov [RV],si
    mov [CURV],si
    mov byte [RETN],0
    call PSETUP
    jmp STAT2               ; PERF40H: line 2 shows the new voice
.busy: mov bx,S_RS
    jmp NMSG
S_MRV: db 'REVERSE',0          ; FZED: play mode name (kept here for room)
S_MSE: db 'LOOP',0             ; FZED: loop mode name (kept here for room)
