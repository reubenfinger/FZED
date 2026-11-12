import sys
d = sys.argv[1]
def sub(fn, old, new, count=1):
    p = d + '/fx/' + fn; s = open(p).read()
    assert s.count(old) == count, (fn, old[:50], s.count(old))
    open(p, 'w').write(s.replace(old, new))
sub('fx2h.asm', """    push bx
    mov bx,[FXD]
    sub ax,bx
    jo .o
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    xchg ax,dx
    pop bx
.r: ret
.o: call MIXOV
    jmp .j
""", """    push bx
    mov bx,[FXD]
    sub ax,bx
    jo .o
.q: times 7 nop             ; tier (c): (wet - dry) * 0 / 1 / 2 / 3 quarters, written here by MIXQ
    add ax,bx
    pop bx
.r: ret
.o: jmp MIXWO
""")
sub('fx4m.asm', "FXLXW:              ; rectifier, fully wet\n", """MIXWO:              ; MIXW, wet - dry past 16 bits: the multiply as before
    call MIXOV
    shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    xchg ax,dx
    pop bx
    ret
MIXQ:               ; FXPAR: Wet/Dry to the nearest quarter, and MIXW's step for it
    mov ax,[FXW]
    add ax,2048
    and ax,0xf000
    mov [FXW],ax
    mov cx,16384
    sub cx,ax
    mov [FXW2],cx
    shr ax,12
    mov si,ax
    shl si,3
    sub si,ax
    add si,.t
    mov di,MIXW.q
    mov cx,7
    cld
    push es
    push ds
    pop es
    rep movsb
    pop es
    ret
.t: db 0x31,0xc0, 0xeb,3, 0x90,0x90,0x90            ; 0:   xor ax,ax
    db 0xc1,0xf8,2, 0xeb,2, 0x90,0x90               ; 1/4: sar ax,2
    db 0xd1,0xf8, 0xeb,3, 0x90,0x90,0x90            ; 1/2: sar ax,1
    db 0x8b,0xd0, 0xc1,0xfa,2, 0x2b,0xc2            ; 3/4: mov dx,ax / sar dx,2 / sub ax,dx
    db 0xeb,5, 0x90,0x90,0x90,0x90,0x90             ; 1:   as it is (MIXW returns before this)
FXLXW:              ; rectifier, fully wet
""")
sub('fxkz.asm', """    mov [FXW2],cx
.m: mov al,[FXIN]
""", """    mov [FXW2],cx
    call MIXQ
.m: mov al,[FXIN]
""")
