; PERF38H part in the DC00h section (see fx5.asm)
RTB2:               ; MIDI realtime: the pattern's own clock count, then LFO 2's as before
    cmp al,0xf8
    jnz .a
    inc word [PCNT]
    cmp word [PCNT],768
    jb .x
    mov word [PCNT],0
    jmp short .x
.a: cmp al,0xfa
    jnz .x
    mov word [PCNT],0xffff
.x: jmp RTB


PNON2:              ; note-on (bx = channel): a note from silence restarts a free-running pattern
    cmp byte [bx+PHELD],0
    jnz .x
    mov byte [PRTG],1
.x: jmp PNON

LRMASK:             ; PERF38I, LENV: rate bytes compare without their direction bit (a direction flip is not a speed change)
    xor ch,ch
    cmp bl,8
    jb .m
    cmp bl,18
    jb .r
    cmp bl,26
    jae .r
.m: and al,0x7f
    and cl,0x7f
.r: ret
