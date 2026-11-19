; ---------- EXT disk modules (FZED41B). FZED 19 (CC10 = 88, CC11 = 19, then CC10 = 89, CC11 = value) picks module n:
; 0-7 off, then 8-step bands for modules 1-15 (module n = disk sector 51+n). Render (CC118) then runs the module
; instead of the CC112 effect. Modules are loaded only by Render, never by a knob, so FZED 19 itself reads no disk.
;
; Module sector, ABI 1 (built with the program, fx/ext1.asm and on; loaded into D400h by OVCALL):
;   +00h  dw 4000h + sector                 +02h  db 1 (ABI)        +03h  db kind: 1 render effect, 2 tool
;   +04h  dw LOWEND, HIGHEND, LVEND, XTEND  (the program it was built with: any other build is refused)
;   +0Ch  name, 16 characters and 0 (shown when Render starts)
;   +20h  init (3-byte jump): after FXPAR, before anything is rendered. CF=1 refuses (it shows its own message).
;         It may read the FX controls' raw values: FXREZ (CC113), FXDF (CC114), FXIN (CC115), FXOUT (CC116),
;         FXMODE+5 (CC117), and FXW (CC117 as the Q14 wet weight).
;   +23h  render effect: cx words (1-256) at es:si, processed in place; si advanced by 2*cx; ds and es kept.
;         tool: run once, si = the edit voice; it shows its own message. Nothing is rendered after it.
;   +3BEh dw 4000h + sector. Code fills upward from 26h; keep the top clear: FZ calls use the stack from DBFEh down.
; A render module runs through FXRUN's fast-loop path (FXM = 9, LVLP = D423h; FXPAR sets both back before any
; other render or live effect), for the edit voice and every chop slice, and FXONE leaves D400h-DBFFh alone.

EXTS: db 0                  ; FZED 19's module (in the program's own memory: 0 at every start)

EXTSEL:             ; parameter 89 with STSEL 19: al = 0-127
    shr al,3
    mov [EXTS],al
    mov bx,S_EXO
    or al,al
    jz .m
    mov di,S_EXN+4
    call DEC2
    mov bx,S_EXN
.m: jmp NMSG

EXTPREP:            ; FXRUN with a module chosen: load sector 51+n (OVCALL refuses in capture, CF=1), then EXTHDR
    mov al,[EXTS]
    add al,51
    mov ah,0x40
    push word EXTHDR
    push ax
    jmp OVCALL
EXTHDR:             ; module loaded: same ABI and build, then its init; CF=1 = nothing to render
    cld
    mov si,0xD404
    mov di,EXTSTMP
    mov cx,4
.c: lodsw
    cmp ax,[di]
    jnz .bad                ; (the build check covers the ABI byte too: it is kept for later)
    inc di
    inc di
    loop .c
    mov bx,0xD40C
    call NMSG
    call 0xD420
    jc .r
    mov al,[0xD403]
    cmp al,1
    jnz .tl
    mov byte [FXM],9
    mov word [LVLP],0xD423
    ret                     ; (CF=0 from cmp)
.tl: cmp al,2
    jnz .bad
    call L61DB
    call 0xD423
    stc
.r: ret
.bad: mov bx,S_EXB
    call NMSG
    stc
    ret
EXTSTMP: dw LOWEND,HIGHEND,LVEND,XTEND
S_EXO: db 'EXT OFF',0
S_EXN: db 'EXT 00',0
S_EXB: db 'EXT: BAD MODULE',0
