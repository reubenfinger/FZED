; ---------- FZED start-up overlay (FZED41A): disk sector 51 (signature 4033h at D400h and D7BEh). MAIN0 loads it into
; D400h-D7FFh with the program; MAIN calls INITX once, before the main loop, then the window is free again (live FX
; buffers, capture and tools overlays). Everything here runs only at start-up: moved unchanged from the resident areas
; (MAIN's start, MINIT, MXINIT, PINIT, SVINIT, FXINIT, FX5INIT, PBGET, CAPINIT, S_TITLE, S_E) to free them.
; Nothing here may call an overlay (OVCALL): CHFINDO stays in MAIN. FZ calls made from here run on the stack at DBFEh
; (L6004X, live FX and capture off), which stays well above this code: no 412h-byte calls are made at start-up.
    dw 0x4033
INITX:
    mov byte [CAPON],0      ; PERF38Q (was CAPINIT): capture flag cleared first
    mov word [CURV],0
    call MINIT
    call MXINIT
    mov byte [MODE],1
    mov byte [0x8002],0xff
    mov bx,S_TITLE
    mov cx,1
    xor dx,dx
    call PRT
    mov byte [RST],0
    mov byte [AFL],0
    mov byte [PREADY],0
    mov word [LEN],50
    mov byte [LRAW],4
    mov byte [CBITS],8
    mov byte [CARM],0
    call FXINIT
    call PBGET
    push es
    push ds
    pop es
    cld
    mov di,LRATE
    xor ax,ax
    mov cx,0x20
    rep stosw
    pop es
    mov word [LOUT],0x8000
    mov word [LRND],0x1234
    mov byte [CHN],8
    mov word [ZCM],0x4001   ; (review: ZCM 1 and TSENS 64, neighbours at 8242h / 8243h, in one write)
    xor ax,ax               ; (review: CHARM, DARM, CHCNT, CHBANK, CHPLAY are 81EDh-81F2h in a row: three word writes;
    mov [CHARM],ax          ; the same zeros as the six separate writes, 18 bytes less)
    mov [CHCNT],ax
    mov [CHBANK+1],ax
    mov [CHOWN],ax
    mov word [CHOKV],0xff   ; PERF40A: choke off, slice 1
    mov byte [CPARM],1
    mov word [VPICK],0x00ff ; PERF40H: no voice picked, no remote exit
    mov byte [L7F],0
    mov byte [KEEPA],0      ; PERF40I: ENTER keeps the sound only (as before) until Gills says otherwise
    xor ax,ax               ; PERF40J: chops into their own bank; no target-bank chop
    mov [CHTO],ax
    mov [CHBASE+1],ax
    mov [0x801A],ax         ; PERF40L: STRETCH next TRACE, order FORWARD,
    mov word [0x801C],64    ; skew even; PERF40M: start not moved (STMV)
    mov word [STN],0x407F   ; PERF40F STRETCH: 8 segments, stretch 64, grain 100%
    mov word [STG],0x007F   ; crossfade 0
    mov word [STZ],0x007F   ; snap on, sustain none, off
    mov ax,[0xdfc]
    mov [DFCSV],ax
    mov ax,[0x40a]
    mov [LTM2],ax
    mov byte [0x4d9],0
    mov byte [0x4d6],0x40
    call L61DB
    cmp word [si+0x10],0
    jz .emp
    mov byte [RETN],1       ; existing voice: keep its filter and envelopes
    call PSETUP
    mov byte [RETN],0
    or sp,sp                ; ZF=0: MAIN calls CHFINDO
    ret
.emp:
    mov bx,S_E
    xor cx,cx
    mov dx,7
    call PRT
    mov byte [L7F],1
    cmp al,al               ; ZF=1
    ret

; (from fx/multi.asm)
MINIT:              ; startup: record 0 = the FZ's edit voice, voice mode
    xor ax,ax
    mov [BKON],al
    mov [ACTIVE],al
    mov byte [BKARM],1      ; disarmed until CC15 sits in the middle
    mov byte [ADDV],1      ; CC16 must first be below 64 before NEW VOICE can fire
    mov word [BKBANK],0
    mov [CURV],ax
    mov di,RV
    mov cx,8
.z: mov [di],ax
    inc di
    inc di
    loop .z
    mov al,[0xdea]
    mov [DEASV],al
    mov al,[0xdeb]
    and al,0x0f
    mov [CURCH],al
    mov [RC],al
    call L61DB
    mov [RV],si
    mov [CURV],si
    ret
; (from fx/matrixz.asm)
MXINIT:             ; startup
    call PINIT
    call SVINIT
    mov al,[0xbe0]          ; follow the FZ's own event queues from now on
    mov [IQP],al
    mov al,[0xde8]
    mov [IQP+1],al
    mov word [IQS],0
    push es
    push ds
    pop es
    cld
    xor al,al
    mov di,MISC
    mov cx,0x150
    rep stosb
    mov di,MTX
    mov cx,0x1d0
    rep stosb
    mov di,CNOTE
    mov cx,16
    mov al,60
    rep stosb
    mov si,0x5288
    mov di,EFSAVE
    mov cx,24
    rep movsb
    pop es
    mov ax,[0x40a]
    or ax,1
    mov [RNDS],ax
    xor bx,bx
.c: push bx
    call MXCLR
    pop bx
    inc bx
    cmp bx,8
    jb .c
    ret
; (from fx/portai.asm)
PINIT:
    xor ax,ax
    mov di,PGT
    mov cx,(PHN+16-PGT)/2
.c: mov [di],ax
    add di,2
    loop .c
    mov al,64
    jmp PSETT
; (from fx/svfi.asm)
SVINIT:
    call SVRESET
    jmp SVCLR
; (from fx/fxkz.asm)
FXINIT:
    mov byte [FXMODE],5      ; TapeHack (PERF38C order)
    mov byte [FXREZ],79     ; 12 bit
    mov byte [FXDF],0
    mov byte [FXIN],13      ; x1.0
    mov byte [FXOUT],127
    mov byte [FXMIX],127
    mov byte [FXARM],0
    mov byte [LVON],0
    mov byte [LVDIRTY],0
    mov byte [FXRF],80      ; ring carrier about 68 Hz
    mov byte [CHSBV],0
    mov byte [LVWAS],0
    mov byte [FXRSH],0
    jmp FX5INIT
; (from fx/fx5ak.asm)
FX5INIT:            ; FXINIT (start): pattern and pacing state
    push es
    push ds
    pop es
    cld
    mov di,PATN
    mov cx,0x24
    xor al,al
    rep stosb
    pop es
    mov byte [PATS],48
    mov word [WSEL],0x00ff  ; no preset wave selected; WARM starts disarmed
    mov byte [PV],127
    mov word [CBK],0xffff
    ret
; (from fzed.asm)
PBGET:              ; PBSV = play-bank pointer; then play the edit voice directly (voice's own original/highest/lowest)
    mov ax,[0xdfe]
    mov [PNEG2],ax
    mov ax,[0xe00]
    mov [E00SV],ax
    mov ax,[0xdfe]
    or ax,ax
    jz .calc
    js .calc
    mov [PBSV],ax
    jmp VDIRECT
.calc:
    xor ax,ax
    mov [PBSV],ax
    mov ax,[0xdfc]
    cmp ax,8
    jae VDIRECT
    mov cx,0x290
    mul cx
    add ax,0xe08
    mov [PBSV],ax
S_TITLE: db 'FZED',0
S_E: db 'EMPTY-REC READY',0

%if ($-$$) > 0x3A0
%error start-up overlay reaches the top of its sector (keep D7A0h-D7BDh clear for the FZ-call stack margin)
%endif
    times 0x3BE-($-$$) db 0
    dw 0x4033
    times 0x400-($-$$) db 0x5a
