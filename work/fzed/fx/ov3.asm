; ---------- PERF40F tools overlay 2: disk sector 47, loaded into D400h by OVCALL like sector 46 (signature 402Fh at
; D400h and D7BEh). COPY VOICE (moved here from the resident code); PERF40L: STRETCH moved to tools overlay 4 (sector 49). Code that makes FZ calls comes first, so
; it stays below the FZ-call stack (DBFEh downwards).
    dw 0x402F
                            ; (strings used after FZ calls sit low: the FZ-call stack can reach this area's top)
S_DU: db 'UNUSED DELETED ',0
S_SHR: db 'VOICE IS SHARED',0
DELUN:              ; CC100 DELETE UNUSED (>= 120 once per arm; below 64 re-arms): the FZ cuts the wave to start..end
    cmp al,64
    jae .d1
    mov byte [DARM],0
    ret
.d1: cmp al,120
    jb .r
    cmp byte [DARM],0
    jnz .r
    mov byte [DARM],1
    call CHOK
    jc .r
    call SHARED             ; PERF40A: the FZ would cut the wave another voice plays
    jnz .d2
    mov bx,S_SHR
    jmp NMSG
.d2: push word 0
    push si
    APIC 170,4              ; FZ: delete unused part of this voice
    call L61DB
    call ADDREF
    mov bx,S_DU
    jmp NMSG
.r: ret

COPYV:              ; 126 COPY VOICE (rising edge to >= 120): the edit voice into the first empty voice, sharing its
    cmp al,64               ; wave memory as the FZ's own COPY VOICE does; the copy becomes the edit voice
    jae .h
    and byte [CPARM],0x80   ; (bit 7 is the per-slice mode)
    ret
.h: cmp al,120
    jb .r
    test byte [CPARM],1
    jnz .r
    or byte [CPARM],1
    cmp byte [BKON],0
    jnz .r
    call L61DB
    cmp word [si+0x10],0
    jnz .go
    mov bx,S_VE
    jmp NMSG
.go: push si
    mov byte [ADDV],0       ; NEW VOICE does the checks, the choice and the switch
    mov al,127
    call NEWVOICE
    pop di
    call L61DB
    cmp si,di
    jz .r                   ; not done (its message says why)
    push si
    push ds
    pop es
    cld
    xchg si,di
    mov cx,0xc0
    rep movsb
    pop si
    mov byte [RETN],1       ; keep the copied sound
    call PSETUP
    mov byte [RETN],0
    jmp STAT2               ; PERF40H: line 2 shows the copy
.r: ret

STRET2:             ; PERF40L: STRETCH-style controls kept in this overlay (from tools overlay 4): 6 CHOP INTO, 7 CAPTURE ON,
    mov bl,[STSEL]          ; 10 slices' filter / envelopes / LFO 1
    cmp bl,10
    jz PERSL
    cmp bl,6
    jz CHINTO
    cmp bl,9
    jz STOFF
    cmp bl,7
    jz CAPIN
    ret
STOFF:              ; PERF40M (from tools overlay 4): STRETCH OFF: the loops as before STRETCH (loop points as edited,
    and byte [STSU],0x7f    ; loop times and sustain / end from PERF's copy), and its start if LEAD-IN CUT moved it
    call L61DB
    cmp byte [STMV],0
    jz .n
    mov byte [STMV],0
    mov ax,[si+8]
    cmp ax,[si+0x14]
    jnz .n
    mov al,[si+0xa]
    xor al,[si+0x16]
    and al,0x1f
    jnz .n
    mov ax,[STRS]
    mov [si+8],ax
    mov al,[STRSH]
    and byte [si+0xa],0xe0
    or [si+0xa],al
.n: push si
    lea di,[si+0x54]
    mov si,BUF+0x40
    mov cx,16
    call MOVB
    pop si
    call ..@ORGKEEP         ; as loop mode ORIGINAL (sustain / end loop, loop times, trace / skip) but the loop points
                            ; are the ones edited before STRETCH, not the voice's set-up copy
    mov bx,S_STO
    jmp NMSG
S_STO: db 'STRETCH OFF    ',0
PERSL:              ; PERF40G: >= 64 per slice (edits to filter / envelopes / LFO 1 go to the slice chosen with SLICE);
    cmp al,64               ; < 64 shared: the source's are copied to every slice again (start over)
    jb .sh
    or byte [CPARM],0x80
    mov bx,S_PSO
    jmp NMSG
.sh: test byte [CPARM],0x80
    jz .r
    and byte [CPARM],0x7f
    mov si,[CHOWN]
    or si,si
    jz .m
    call CHPROP
.m: mov bx,S_PSS
    jmp NMSG
.r: ret

CAPIN: cmp al,64           ; PERF40K: >= 64 capture mode. A jump, not a call: the capture overlay replaces this one in D400h
    jb .r
    jmp CAPGO
.r: ret
CHINTO:             ; PERF40J: < 64 new chops go into their own CHOP bank, >= 64 into the bank being built (target)
    xor ah,ah
    mov bx,S_CI0
    cmp al,64
    jb .s
    inc ah
    mov bx,S_CI1
.s: mov [CHTO],ah
    jmp NMSG

S_PSO: db 'SLICES: OWN F/E',0
S_CI0: db 'CHOP INTO: OWN  ',0
S_CI1: db 'CHOP INTO TARGET',0
S_PSS: db 'SLICES: SHARED ',0
%if ($-$$) > 0x3A0
%error tools overlay 2 reaches its scratch area (D7A0h)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x402F
    times 0x400-($-$$) db 0x5a
