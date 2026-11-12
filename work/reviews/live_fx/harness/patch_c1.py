import sys
p = sys.argv[1] + '/fx/fxkz.asm'; s = open(p).read()
old = """    mov bx,ax
    shr bx,5
    and bx,0xfffe
    and ax,63
    mov di,[bx+THT+2]
    sub di,[bx+THT]
    imul di
    shl ax,1                ; (dx:ax >> 6), low word
    rcl dx,1
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    xor ax,bp
    sub ax,bp
"""
new = """    mov bx,ax               ; tier (c): the nearest curve point, no interpolation
    add bx,32
    shr bx,5
    and bx,0xfffe
    mov ax,[bx+THT]
    xor ax,bp
    sub ax,bp
"""
assert s.count(old) == 2
open(p, 'w').write(s.replace(old, new))
