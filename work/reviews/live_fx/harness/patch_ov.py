# "needs the wave overlay" set.  The scratch build stands in for the overlay by cutting the wave generator out of lv.
import sys, re
d = sys.argv[1]
def sub(fn, old, new, count=1):
    p = d + '/fx/' + fn; s = open(p).read()
    assert s.count(old) == count, (fn, old[:50], s.count(old))
    open(p, 'w').write(s.replace(old, new))
p = d + '/fx/fx4m.asm'; s = open(p).read()
a = s.index('WVLOAD:'); b = s.index('NEWVOICE:')
NEW = """WVLOAD: ret                 ; (scratch build only: the wave generator is cut out to stand in for the overlay)
FXLXW:              ; rectifier, fully wet
.l: mov ax,[es:si]
    or ax,ax
    jns .p
    imul word [RCK]
    shl ax,1
    rcl dx,1
    mov ax,dx
.p: sub ax,[RCDC]
    jno .m
    mov ax,0x8000
.m: mov [es:si],ax
    add si,2
    loop .l
    ret
FXLDW:              ; decimator, fully wet: block place and held word in registers
    mov dx,[FXPOS]
    mov bx,[DCN]
    mov ax,[FXHELD]
.l: or dx,dx
    jnz .h
    mov ax,[es:si]
.h: mov [es:si],ax
    inc dx
    cmp dx,bx
    jb .n
    xor dx,dx
.n: add si,2
    loop .l
    mov [FXPOS],dx
    mov [FXHELD],ax
    ret
FXLEW:              ; echo / comb, fully wet
    mov di,DBUF
    mov bx,[EG]
.l: mov ax,[di]
    imul bx
    shl ax,1
    rcl dx,1
    mov ax,[es:si]
    add dx,ax
    jno .m
    mov dx,0x7fff
    or ax,ax
    jns .m
    mov dx,0x8000
.m: mov [es:si],dx
    add si,2
    add di,2
    loop .l
    ret
"""
open(p, 'w').write(s[:a] + NEW + s[b:])
sub('fxkz.asm', "LPW: dw 0,FXLT,FXLT,FXLC,FXLR,FXLT,1,FXLU,SVLV,FXLX,FXLD,FXLBW,FXLE,FXLQW", "LPW: dw 0,FXLT,FXLT,FXLC,FXLR,FXLT,1,FXLU,SVLV,FXLXW,FXLDW,FXLBW,FXLEW,FXLQW")
# Karplus-Strong mix: one multiply (this one is shorter than the code it replaces, so it also fits today)
sub('fxkz.asm', """    push bx
    push dx
    mov ax,dx
    imul word [FXW]
    mov bx,ax
    mov di,dx
    mov ax,[si]
    imul word [FXW2]
    add ax,bx
    adc dx,di
    shr ax,14
    shl dx,2
    or ax,dx
    mov dx,ax
    pop bx
    pop bx
.st: mov [si],dx
    add si,2
    add bx,2
    loop .l
    pop es
    ret
""", """    push bx
    mov ax,dx
    mov bx,[si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    pop bx
.st: mov [si],dx
    add si,2
    add bx,2
    loop .l
    pop es
    ret
.of: call MIXOV
    jmp .j
""")
print('patched', d)
