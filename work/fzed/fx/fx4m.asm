; ---------- PERF38G (PERF38L loop / reload fixes): preset waves written by PERF, and FZ calls on a big stack (code at B900h-BBFFh) ----------
; Preset waves: CC111 picks one of 8 bands (v / 8: 0 off, 1-7 waves), CC9 below 64 arms, 120-127 loads it once.
; PERF writes 1800 words (11 cycles, 220 Hz at 36k) at the edit voice's start, sets loop 0 over them as both the
; sustain and the end loop, original key 57 (A), keys 21-93, rate 36k, then takes the voice as its new baseline
; (as at start: snapshots, no INIT). No FZ synthesis calls. The rest of the sample stays after the loop end.
; Refused with capture on or in bank mode (here), then (in the overlay, after live FX are released) with chop slices,
; while recording, if a new voice can't be allocated, or if the voice is under 1808 words.
; FZED: the generator (WVLOAD, the waves, SIN) is in the wave overlay, disk sector 50 (fx/ov6.asm).
WSEL equ 0xD2E0             ; (free RAM D2D0h-D3FFh)
WARM equ 0xD2E1
WPH equ 0xD2E4              ; dword
WST equ 0xD2E8              ; dword
SWSP equ 0xD2EC
SWBX equ 0xD2EE
WTV equ 0xD2D6              ; PERF38K: voice the wave goes into
NWAVE equ 7                 ; FZED: preset waves in the wave overlay's WVT (CC111 bands 1-7)
WNEW equ 0xD2D8             ; PERF38K: 1 = it was empty and has just been allocated
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
    cmp byte [WSEL],NWAVE
    jae .r
    cmp byte [CAPON],0      ; FZED: capture and bank mode refused here, before the wave overlay (sector 50) is
    jnz .no                 ; loaded: loading it would release live FX and say TOOLS NOT LOADED instead
    cmp byte [BKON],0
    jnz .no
    push word WVLOAD
    push word 0x4032
    jmp OVCALL
.no: mov bx,S_WR
    jmp NMSG
.r: ret

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
