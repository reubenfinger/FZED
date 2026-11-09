; PERF38H part in 6000h-7FFFh: start-up, tables (see fx5.asm)
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

PSYN: db 3,4,6,8,12,16,24,48   ; clocks per step: 1/32, 1/16T, 1/16, 1/8T, 1/8, 1/4T, 1/4, 1/2
PTAB: dw 0xffff,0xffff, 0x5555,0x1111, 0xffff,0x5555, 0x1111,0x1111   ; steps on, steps accented (bit n = step n)
      dw 0x4949,0x0101, 0xaaaa,0x8888, 0xbbbb,0x1111, 0xdddd,0x1111
      dw 0x0f0f,0x0101, 0x55ff,0x0101, 0x2449,0x0041, 0xf511,0xf000
      dw 0x0501,0x0001, 0x6b2d,0x0101


FMNAME:             ; PERF38I, FXCC CC112: al = FXMOF value -> 'FX name' padded to 15 at FMBUF, paced message
    cmp byte [MXQ],0
    jnz .r
    push si
    push es
    push ds
    pop es
    cld
    mov si,S_FMN
    mov cl,al
.f: dec cl
    js .c
.s: lodsb
    or al,al
    jnz .s
    jmp .f
.c: mov di,FMBUF
    mov ax,0x5846           ; 'FX'
    stosw
    mov al,' '
    stosb
.k: lodsb
    or al,al
    jz .p
    stosb
    jmp .k
.p: mov al,' '
.q: cmp di,FMBUF+15
    jae .e
    stosb
    jmp .q
.e: mov byte [di],0
    pop es
    pop si
    mov bx,FMBUF
    jmp NMSGD
.r: ret
S_FMN: db 'POCKEY2',0,'TAPEHACK',0,'TAPE>POCKEY',0,'LINEAR CRUSH',0,'RING MOD',0,'WAVEFOLDER',0,'KARPLUS-STRG',0
       db 'TUBE2',0,'FILTER',0,'RECTIFIER',0,'DECIMATOR',0,'BIT MANGLE',0,'ECHO / COMB',0,'POSITION',0,'XOVER FUZZ',0

ECHOF:              ; PERF38I, main loop after DISPATCH: al = value. CC echo in decimal 'C=ccc vvv' ('P=ppp vvv' for CC11,
    mov di,S_C+6            ; with the parameter chosen by CC10 on that channel); none if the control drew its own message
    call DEC3
    mov word [S_C],0x3d43   ; 'C='
    mov al,[cs:LASTCC]
    cmp al,11
    jnz .c
    mov byte [S_C],'P'
    mov bl,[CCCH]
    and bx,15
    mov al,[bx+PSEL]
.c: mov di,S_C+2
    call DEC3
    cmp byte [LCDE],2
    jz .s
    mov byte [LCDE],1
    jmp LCDCHK
.s: mov byte [LCDE],0
    ret

