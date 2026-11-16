import sys
d = sys.argv[1]
def sub(fn, old, new, count=1):
    p = d + '/fx/' + fn; s = open(p).read()
    assert s.count(old) == count, (fn, old[:50], s.count(old))
    open(p, 'w').write(s.replace(old, new))
# 7. SQRTQ: quicker normalising, cheaper shifts, no CS prefix (DS = CS here)
sub('fxkz.asm', """    xor cl,cl
.n: cmp ax,16384
    jae .t
    shl ax,2
    inc cl
    jmp .n
.t: mov bx,ax
    sub bx,16384
    shr bx,9
    shl bx,1
    and ax,511
    push cx
    mov cx,[cs:bx+SQN2+2]
    sub cx,[cs:bx+SQN2]
    mul cx
    shr ax,9
    shl dx,7
    or ax,dx
    add ax,[cs:bx+SQN2]
""", """    xor cl,cl
    or ah,ah
    jnz .n
    xchg al,ah              ; below 256: four of the steps below at once
    mov cl,4
.n: cmp ax,16384
    jae .t
    shl ax,2
    inc cl
    jmp .n
.t: mov bx,ax
    sub bx,16384
    mov bl,bh               ; (bx >> 9) * 2
    and bx,0x00fe
    and ax,511
    push cx
    mov cx,[bx+SQN2+2]
    sub cx,[bx+SQN2]
    mul cx
    shr dx,1                ; (dx:ax >> 9), low word
    rcr ax,1
    mov al,ah
    mov ah,dl
    add ax,[bx+SQN2]
""")
# 8. mod matrix: a record with nothing routed now or last pass only needs the glide step
sub('matrixz.asm', """    mov ax,[MXNU]
    mov [bx+MXUSE],ax
    mov word [MXD0],1       ; fast destinations 1-7: written every pass while used
""", """    mov ax,[MXNU]
    mov [bx+MXUSE],ax
    cmp word [MXOLD],0      ; nothing routed now or last pass: both destination loops would do nothing
    jnz .w
    jmp PTICK
.w: mov word [MXD0],1       ; fast destinations 1-7: written every pass while used
""")
# 9. fully wet loops without the MIXW call: bit mangle (high area) and position (xt)
sub('fxkz.asm', "LPW: dw 0,FXLT,FXLT,FXLC,FXLR,FXLT,1,FXLU,SVLV,FXLX,FXLD,FXLB,FXLE,FXLQ", "LPW: dw 0,FXLT,FXLT,FXLC,FXLR,FXLT,1,FXLU,SVLV,FXLX,FXLD,FXLBW,FXLE,FXLQW")
sub('fxkz.asm', """MIXOV:              ; wet - dry did not fit""", """FXLBW:              ; bit mangle, fully wet
    mov ax,[MGM]
.l: xor [es:si],ax
    add si,2
    loop .l
    ret
MIXOV:              ; wet - dry did not fit""")
sub('fx3i.asm', """FXLQ:               ; position: DBUF word, mix
""", """FXLQW:              ; position, fully wet: the chunk is DBUF
    mov di,si
    mov si,DBUF
    rep movsw
    ret
FXLQ:               ; position: DBUF word, mix
""")
# bytes for the above: CS prefixes that repeat what DS already gives (these routines read their variables through DS)
for old in ("mov ax,[cs:bx+KSPT]", "mov ax,[cs:bx+LPW]", "mov ax,[cs:bx+LPM]", "mov ax,[cs:STAB+512]", "mov dx,[cs:bx+STAB+2]", "sub dx,[cs:bx+STAB]", "add ax,[cs:bx+STAB]",
            "mov dx,[cs:di+LOGT+2]", "sub dx,[cs:di+LOGT]", "add ax,[cs:di+LOGT]", "mov dx,[cs:bx+DEXT+2]", "sub dx,[cs:bx+DEXT]", "add ax,[cs:bx+DEXT]"):
    sub('fxkz.asm', old, old.replace('cs:', ''))
sub('fx2h.asm', "mov al,[cs:bx+FXMT]", "mov al,[bx+FXMT]")
print('patched', d)
