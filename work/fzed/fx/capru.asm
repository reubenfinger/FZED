; ---------- PERF38M capture mode: resident part (main section). The mode itself is loaded from disk sectors 44-45
; into D400h-DBFFh (fx/capo.asm) when it is entered. CAPON is set first, so FZ calls (the loads included) stay on
; PERF's own stack and not on the KSB area being loaded.
CAPON equ 0xD2DA            ; 1 = capture mode running (overlay at D400h loaded)
CAPGO:              ; RECORD AUTO (CC108) >= 64 while not armed: load the capture overlay and start it
    cmp byte [BKON],0
    jz .vm
    mov bx,S_RS             ; voice mode only, as recording
    jmp NMSG
.vm: mov al,[RST]
    cmp al,2
    jb .ok
    cmp al,3
    jbe .r
.ok: call LVOFF
    mov word [CBK],0xffff   ; no curve build in progress (CSH shares D400h)
    mov si,[0xe04]          ; PERF38R: the edit voice is deleted here, while FZ calls still use the 2 KB KSB stack;
    cmp word [si+0x10],0    ; the FZ's delete (API 119) has a 412h-byte stack frame, which on PERF's 1 KB stack
    jz .e                   ; overwrote the code at EB3Ah-EBFFh (PNON2 and others): the capture freezes
    call WDEL
.e: mov byte [CAPON],1
    push word 0
    push word CAPBASE
    push word 44
    APIC 0xbf,6
    or ax,ax
    jnz .bad
    push word 0
    push word CAPBASE+0x400
    push word 45
    APIC 0xbf,6
    or ax,ax
    jnz .bad
    cmp word [CAPSIG],0xCA9E
    jnz .bad
    jmp CAPSTART
.bad: mov byte [CAPON],0
    mov bx,S_CAPD
    jmp NMSG
.r: ret
CMIDI:              ; PERF38S (moved from the overlay): MIDI that arrived while recording is dropped for the ROM's
    mov al,[0x9d8]          ; reader (PERF's own reader has handled the controllers)
    mov [0x9d6],al
    ret
CSYC: db 'FSEQH124'         ; PERF38U (from the overlay): sync letters: free, 16th, 8th, quarter, half, 1 / 2 / 4 bars
