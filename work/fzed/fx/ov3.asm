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

NVSCAN:             ; FZED41C (from NEWVOICE, fx4m.asm): first empty voice, then switch to it
    mov si,0x2288
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

CHSLICE:            ; FZED41H (from CHOP in fzed.asm, for room): 4. each slice; bx = 0 done, else the message
    mov byte [CHI],0
.sl: mov al,[CHI]           ; 4. each slice
    cmp al,[NBND]
    jae .sld
    mov bx,[CHBANK]         ; PERF40J: a bank holds 64 places
    cmp word [bx],64
    jb .s0
.sld: jmp CHFIN.done        ; FZED41K: on into the finish (from CHOP, for room)
.s0: call L61DB
    mov di,0x2288           ; free voice slot
    mov cx,64
.fv: cmp di,si
    jz .fn
    cmp word [di+0x10],0
    jz .got
.fn: add di,0xc0
    loop .fv
    mov bx,S_CV
    jmp CHFIN.err
.got: mov bl,[CHI]           ; length = SBND[i+1] - SBND[i]
    xor bh,bh
    shl bx,2
    mov ax,[bx+SBND+4]
    mov dx,[bx+SBND+6]
    sub ax,[bx+SBND]
    sbb dx,[bx+SBND+2]
    mov [CHL],ax
    mov [CHL+2],dx
    push di
    push dx
    push ax
    push word 0
    push di
    APIC 117,8              ; FZ allocates wave memory for the slice
    pop di
    or bx,bx
    jz .al
    mov bx,S_CM
    jmp CHFIN.err
.al: call L61DB
    push si                 ; copy all settings except addresses
    push di
    mov ax,[si+0x10]
    mov [di+0x10],ax
    add si,0x54
    add di,0x54
    mov cx,0xc0-0x54
    call MOVB
    pop di
    pop si
    mov word [di+0x12],0x0808   ; one-shot, loops parked at the slice end, no loop time
    mov ax,[di+0xc]
    mov dx,[di+0xe]
    and dx,0x1f
    xor bx,bx
.lp: mov [bx+di+0x14],ax
    mov [bx+di+0x16],dx
    mov [bx+di+0x34],ax
    mov [bx+di+0x36],dx
    add bx,4
    cmp bx,32
    jb .lp
    xor bx,bx
.lt: mov word [bx+di+0x64],0
    inc bx
    inc bx
    cmp bx,16
    jb .lt
    call CHKEY              ; FZED41R: keys by LAYOUT (fzed.asm; ONE KEY: C2 + slice)
    push di                 ; wave data: SBND[i] -> slice start, CHL words
    mov bl,[CHI]
    xor bh,bh
    shl bx,2
    mov ax,[bx+SBND]
    mov dx,[bx+SBND+2]
    mov cx,[di+8]
    mov bx,[di+0xa]
    call WCOPY
    pop di
    mov bx,[CHBANK]         ; bank area
    mov al,[CHI]
    xor ah,ah
    mov si,ax
    add bx,si
    add bx,[CHBASE]         ; PERF40J: after the places already in the bank
    mov al,[di+0xae]        ; FZED41R: the bank area's keys as the slice's
    mov [bx+2],al
    mov al,[di+0xaf]
    mov [bx+0x42],al
    mov al,[di+0xb0]
    mov [bx+0x102],al
    mov byte [bx+0x82],0x7f
    mov byte [bx+0xc2],0
    mov byte [bx+0x1c2],0
    mov al,[CHOKV]          ; PERF40A: FFh all outputs, 01h output 1 = choke
    mov [bx+0x182],al
    call CHCHAN             ; PERF40J: the FZ's channel (own CHOP bank) or Gills' (CHOP INTO TARGET)
    mov [bx+0x142],al
    mov bx,[CHBANK]
    shl si,1
    mov [si+CHV],di
    add bx,[CHBASE]
    add bx,[CHBASE]
    mov [bx+si+0x202],di
    mov bx,[CHBANK]
    inc word [bx]
    inc byte [CHI]
    mov al,[CHI]
    mov [CHCNT],al
    jmp .sl

CHFIN:              ; FZED41K (from CHOP in fzed.asm, for room): 5. after the slices: .err with bx = why it stopped,
.err: mov [CHWHY],bx
    call NMSG
    cmp byte [CHCNT],0
    jz .r
    jmp .dz
.done: mov word [CHWHY],0
.dz: call L61DB
    mov [CHOWN],si
    mov ax,si               ; bank name 'CHOP Vnn' = source voice number
    sub ax,0x2288
    mov cl,0xc0
    div cl
    inc al
    call CHNMD              ; PERF40J: (a chop into a target bank leaves the bank's name alone)
    mov byte [di+0x287],'V'
    add di,0x288
    call DEC2
    call CHPROP
    call CHON
    push word CHOPMSG       ; FZED41P: the message from the wave overlay (sector 50; fx/ov6.asm), for room
    push word 0x4032
    jmp OVCALL
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
%if ($-$$) > 0x3BE
%error tools overlay 2 reaches its end signature (D7BEh) (FZED41K: it keeps no scratch at D7A0h, so the code may go on to it)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x402F
    times 0x400-($-$$) db 0x5a
