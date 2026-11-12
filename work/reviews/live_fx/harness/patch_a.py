import sys
d = sys.argv[1]
def sub(fn, old, new, count=1):
    p = d + '/fx/' + fn; s = open(p).read()
    assert s.count(old) == count, (fn, old[:40], s.count(old))
    open(p, 'w').write(s.replace(old, new))
# 1. LVRDX: block move with DS on the sample window
sub('fxkz.asm', """    push di
    call LVSET
    pop di
.l: call LVRUNN             ; ax = words in this run, cx = words after it
    push cx
    mov cx,ax
    shr cx,1
    jnc .e
    mov ax,[es:si]
    mov [di],ax
    add si,2
    add di,2
.e: jcxz .d
.p: mov ax,[es:si]
    mov [di],ax
    mov ax,[es:si+2]
    mov [di+2],ax
    add si,4
    add di,4
    loop .p
.d: pop cx
    jcxz .r
    call LVBK
    jmp .l
.r: ret
""", """    push di
    call LVSET
    pop di
    cld
.l: call LVRUNN             ; ax = words in this run, cx = words after it
    xchg ax,cx
    push es                 ; rep movsw reads DS:SI: DS on the sample window, ES on PERF's memory
    push ds                 ; (the FZ's interrupt handlers load their own DS)
    pop es
    pop ds
    rep movsw
    push es
    push ds
    pop es
    pop ds
    mov cx,ax
    jcxz .r
    call LVBK
    jmp .l
.r: ret
""")
# 2. TapeHack interpolation shifts (FXLT, FXLTM)
sub('fxkz.asm', """    imul di
    shr ax,6
    shl dx,10
    or ax,dx
""", """    imul di
    shl ax,1                ; (dx:ax >> 6), low word
    rcl dx,1
    shl ax,1
    rcl dx,1
    mov al,ah
    mov ah,dl
""", 2)
# 3. one-multiply mix: out = dry + ((wet - dry) * FXW >> 14)
MIXOLD = """    imul word [FXW]
    mov bx,ax
    mov di,dx
    mov ax,[es:si]
    imul word [FXW2]
    add ax,bx
    adc dx,di
    shr ax,14
    shl dx,2
    or ax,dx
    mov [es:si],ax
    add si,2
    loop .l
    ret
"""
MIXNEW = """    mov bx,[es:si]          ; out = dry + ((wet - dry) * FXW >> 14): the same word as the two-product form
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov [es:si],dx
    add si,2
    loop .l
    ret
.of: call MIXOV
    jmp .j
"""
sub('fxkz.asm', MIXOLD, MIXNEW, 2)
sub('fxkz.asm', """    mov ax,dx
    imul word [FXW]
    push dx
    push ax
    mov ax,[es:si]
    imul word [FXW2]
    pop bx
    add ax,bx
    pop bx
    adc dx,bx
    shr ax,14
    shl dx,2
    or ax,dx
    mov [es:si],ax
    add di,[FXRIF]
    adc bp,[FXRII]
    add si,2
    loop .l
    mov [FXRPI],bp
    mov [FXRPF],di
    ret
""", """    mov ax,dx
    mov bx,[es:si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov [es:si],dx
    add di,[FXRIF]
    adc bp,[FXRII]
    add si,2
    loop .l
    mov [FXRPI],bp
    mov [FXRPF],di
    ret
.of: call MIXOV
    jmp .j
MIXOV:              ; wet - dry did not fit 16 bits (flags from the SUB): dx:ax = (wet - dry) * FXW all the same
    js .p
    imul word [FXW]
    sub dx,[FXW]
    ret
.p: imul word [FXW]
    add dx,[FXW]
    ret
""")
sub('fxkz.asm', """    mov ax,dx
    imul word [FXW]
    mov bx,ax
    mov di,dx
    mov ax,[es:si]
    imul word [FXW2]
    add ax,bx
    adc dx,di
    shr ax,14
    shl dx,2
    or ax,dx
    mov dx,ax
.st: mov [es:si],dx
    add si,2
    pop cx
    dec cx
    jz .x
    jmp .l
.x: ret
""", """    mov ax,dx
    mov bx,[es:si]
    sub ax,bx
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
.st: mov [es:si],dx
    add si,2
    pop cx
    dec cx
    jz .x
    jmp .l
.x: ret
.of: call MIXOV
    jmp .j
""")
# 4. Tube2 curve interpolation shifts
sub('fxkz.asm', """    imul dx
    shr ax,7
    shl dx,9
    or ax,dx
    add ax,[bx+THT]
    ret
""", """    imul dx
    shl ax,1                ; (dx:ax >> 7), low word
    rcl dx,1
    mov al,ah
    mov ah,dl
    add ax,[bx+THT]
    ret
""")
# 5. MIXW (rectifier, decimator, bit mangle, echo, position)
sub('fx2h.asm', """    push bx
    imul word [FXW]
    push dx
    push ax
    mov ax,[FXD]
    imul word [FXW2]
    pop bx
    add ax,bx
    pop bx
    adc dx,bx
    shr ax,14
    shl dx,2
    or ax,dx
    pop bx
.r: ret
""", """    push bx
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
""")
# 6. filter mix
sub('svfi.asm', """    imul word [FXW]         ; out = (wet * FXW + dry * (16384 - FXW)) >> 14
    mov [SVTMP],ax
    mov [SVTMP+2],dx
    mov ax,[SVDRY]
    imul word [FXW2]
    add ax,[SVTMP]
    adc dx,[SVTMP+2]
    shr ax,14
    shl dx,2
    or ax,dx
.st: mov [es:si],ax
    add si,2
    dec cx
    jz .x
    jmp .l
.x: mov [SVLH],di
    mov [SVBH],bp
    ret
""", """    mov bx,[SVDRY]          ; out = dry + ((wet - dry) * FXW >> 14)
    sub ax,bx
    jo .o
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov ax,dx
.st: mov [es:si],ax
    add si,2
    dec cx
    jz .x
    jmp .l
.x: mov [SVLH],di
    mov [SVBH],bp
    ret
.o: call MIXOV
    jmp .j
""")
print('patched', d)
