; ---------- PERF38O..Z/PERF39A/B capture mode overlay (disk sectors 44-45, loaded to D400h-DBFFh by CAPGO) ----------
; While capture mode runs, FZ calls stay on PERF's own stack (L6004X), as recording always did before PERF38G.
; Capture -> finish -> play the take as a chord (looped; intervals, velocities, staggered starts; held for passes,
; seconds, or until a recapture) -> capture again. Run from the main loop, so MIDI, the matrix, the pattern and the
; filter keep working. CT3 results: the voice reused (allocated again only when the length or rate changes), no
; pre-record, start / end snapped to zero crossings, the take looped, outputs switched straight back on.
; RECORD page while capturing (Gills Core 63 CAPTURE view):
;   P1 RATE (102)          record rate (applied at the next capture)
;   P2 LENGTH (103)        capture length, 16 steps: 10 ms .. 4 s
;   P3 GAIN (104)          input gain (applied at the next capture)
;   P4 AUTO TRIG (105)     hold: 1 / 2 / 4 / 8 passes, 2 / 4 / 8 s, until RECAPTURE
;   P5 ARM (106)           transpose -24..+24 semitones (centre = 0)
;   P6 START (107)         sync: free, or start each capture on 1/16, 1/8, 1/4, 1/2, 1, 2, 4 bars of MIDI clock
;   P7 RECORD AUTO (108)   below 64: leave capture mode
;   P8 STOP (109)          64 or more: RECAPTURE (end the hold now; the next capture follows, on the sync)
;   P9 MONITOR (110)       as normal
; CHOP / PATTERN page while capturing (Gills Core 63 CAPTURE 2 view):
;   P1 (96)  intervals: original, octaves, root+5th+octave, major, minor, major 7th, minor 7th, 5th+octave below, wide
;   P2 (97)  velocity: same, random, falling, rising
;   P3 (99)  stagger between the chord's notes: together, 20 ms .. 2.4 s
;   P4 (98 / 34)  PERF38U: FADE: OFF, 50 .. 1600 ms between the note-offs and the next capture (the release plays out)
; CC23 / CC33 work as P5 / P6 (PERF38N). Ignored while capturing: preset waves (refused), CC98 and CC100-101 (chop
; actions), FX (112-119), loop controls (86-88, 126). Leaving keeps the last take as a normal, looped voice.
CAPBASE equ 0xD400
CRLM equ CAPBASE+0x7C4      ; PERF38Z: release 0 together, 1 top first (one note per stagger step)
CHM equ CAPBASE+0x7C6       ; hold mode 0..7
CCH equ CAPBASE+0x7C7       ; interval set 0..8
CVM equ CAPBASE+0x7C8       ; velocity mode 0..3
CRQ equ CAPBASE+0x7C9       ; 1 = recapture asked for
CNN equ CAPBASE+0x7CA       ; notes in the chord
CNS equ CAPBASE+0x7CB       ; notes started
CPRN equ CAPBASE+0x7CC      ; word: random state
CNK equ CAPBASE+0x7CE       ; 4 keys
CNV equ CAPBASE+0x7D2       ; 4 velocities
CSGI equ CAPBASE+0x7D8      ; stagger step 0..15
CSGL equ CAPBASE+0x7D6      ; PERF38X: stagger step latched for the chord being played
CFAD equ CAPBASE+0x7D9      ; PERF38U: fade step 0..7
CTW equ CAPBASE+0x7DA       ; PERF38V: dword: words of the take being recorded
CAW equ CAPBASE+0x7E6       ; dword: allocated record words (0 = none) (PERF38V: variables from 7C6h)
CPRT equ CAPBASE+0x7DE      ; rate change waiting for the next capture (FFh = none)
CPGN equ CAPBASE+0x7DF      ; gain change waiting (FFh = none)
CST equ CAPBASE+0x7E0       ; 0 wait / start, 1 recording, 2 playing
CLEN equ CAPBASE+0x7E1      ; length step 0..15
CTR equ CAPBASE+0x7E3       ; transpose (signed)
CSYN equ CAPBASE+0x7E4      ; sync 0 free, 1..7
CFST equ CAPBASE+0x7E5      ; 1 = next take is the first in this allocation (set up as a new take)
CLAST equ CAPBASE+0x7EA     ; word: timer at the last pass
CEL equ CAPBASE+0x7EC       ; dword: timer units in this phase
CHLD equ CAPBASE+0x7F0      ; dword: hold time
CPCV equ CAPBASE+0x7F4      ; word: last clock division seen (FFFFh = none yet)
CGS equ CAPBASE+0x7F6       ; 4 words: start / end of the fresh allocation
CAPSIG equ CAPBASE+0x7FE

CAPSTART:
    push es
    push ds
    pop es
    cld
    mov di,CRLM
    mov cx,0x1D             ; PERF38V/Z: variables 7C4h-7FDh
    cmp byte [LVBUF+0x40],0xCA
    jnz .z
    mov si,LVBUF            ; PERF38R: re-entered for a new allocation (CAPRE): the settings come back, the take
    rep movsw               ; state starts again
    pop es
    xor ax,ax
    mov [LVBUF+0x40],al
    mov [CAW],ax
    mov [CAW+2],ax          ; (CST and CNS are already 0: re-entry comes from CSTART)
    jmp short .c
.z: xor ax,ax
    rep stosw               ; all variables 0
    pop es
    mov al,[LRAW]
    shr al,3
    mov [CLEN],al
    mov al,[0x4d6]          ; P4 is stored x2
    shr al,5
    mov [CHM],al
    mov ax,[0x40a]
    or al,1
    mov [CPRN],ax
.c: mov byte [CFST],1
    mov ax,0xffff
    mov [CPCV],ax
    mov [CPRT],ax           ; (and CPGN); CAPON was set by CAPGO
    inc ax                  ; PERF39B: (room) ax = 0
    mov [RST],al
    jmp CSHOW

CAPFLT:             ; DISPATCH while capturing: CF=1 = handled / ignored here
    mov dl,[cs:LASTCC]
    mov bx,CMAP             ; CC23 transpose, CC33 sync (Gills Core 64 CAPTURE view P5 / P6; PERF ignores both outside
    cmp byte [MXQ],0        ; PERF39B: CC87 / CC88 = capture length / rate only when the matrix sends them; from MIDI
    jnz .m                  ; they move the captured loop (loop 0, inside the take) until the next take resets it
    add bx,4
.m: cmp dl,[cs:bx]          ; capture, so setting them can't arm a recording as CC106 / CC107 do); PERF38V: CC87 / CC88
    jnz .mn                 ; (loop start / end, matrix destinations 10 / 11) = capture length / rate
    mov dl,[cs:bx+1]
    jmp short .cc
.mn: inc bx
    inc bx
    cmp bx,CMAP+8
    jb .m
    cmp dl,102
    jb .ig
    cmp dl,110
    ja .ig
.cc: call CAPCC
    stc
    ret
.ig: cmp dl,96              ; CAPTURE 2: intervals, velocity, stagger
    jnz .i97
    mov ah,9
    mul ah
    shl ax,1
    mov [CCH],ah
    jmp short .s2
.i97: cmp dl,97
    jnz .i99
    shr al,5
    mov [CVM],al
    jmp short .s2
.i99: cmp dl,99
    jnz .i98
    shr al,3
    mov [CSGI],al
.s2: call CSHOW2
    stc
    ret
.i98: cmp dl,41              ; PERF38Z: CC41 (Gills Core 72 CAPTURE 2 P8): release together / top first
    jnz .i9x
    shr al,6
    mov [CRLM],al
    stc
    ret
.i9x: cmp dl,98              ; PERF38U: fade, CC98 or CC34 (Gills Core 67 CAPTURE 2 P4: PERF ignores CC34 outside
    jz .fd                  ; capture, where CC98 would chop)
    cmp dl,34
    jnz .i86
.fd: shr al,4
    mov [CFAD],al
    call CSHOWF
    stc
    ret
.i86: cmp dl,86              ; loop mode (start / end are mapped above)
    jz .y
    cmp dl,126
    jz .y
    cmp dl,98
    jb .n
    cmp dl,101
    jbe .y
    cmp dl,111
    jb .n
    cmp dl,119
    ja .n
.y: stc
    ret
.n: clc
    ret

CMAP: db 87,103,88,102,23,106,33,107   ; PERF39B: matrix-only pairs first
CAPCC:              ; al = value, dl = 102..110 (PERF38V: by table)
    sub dl,102
    mov bl,dl
    xor bh,bh
    shl bx,1
    jmp [cs:bx+CCTB]
CCTB: dw .c2,.c3,.c4,.c5,.c6,.c7,.c8,.c9,.rw
.c2: shr al,5                ; rate and gain wait for the next capture (mid-recording they crashed the FZ)
    mov [CPRT],al
    jmp short .sh
.c3: mov [LRAW],al
    shr al,3
    mov [CLEN],al
    jmp short .sh
.c4: shr al,6
    mov [CPGN],al
    ret
.c5: shl al,1
    mov [0x4d6],al
    shr al,5
    mov [CHM],al
    jmp short .sh
.c6: mov ah,49
    mul ah
    shl ax,1
    mov al,ah
    sub al,24
    mov [CTR],al
    jmp short .sh
.c7: shr al,4
    mov [CSYN],al
    mov word [CPCV],0xffff
.sh: jmp CSHOW
.c8: cmp al,64
    jb CAPEND
    ret
.c9: cmp al,64              ; 109: RECAPTURE
    jb .r9
    mov byte [CRQ],1
.r9: ret
.rw: jmp RWRITE             ; CC110 NORM FILTER: PERF39A: RWRITE keeps it (NFV) for every record setup

CAPEND:             ; leave: the take in hand is kept as a normal voice (PERF38V: every caller has CAPON 1)
    mov al,[CST]
    cmp al,1
    jnz .np
    call CSTOP              ; mid-recording: finish the take (and PERF's copy of it)
    jmp short .m
.np: cmp al,2               ; playing, fading (none left) or releasing (PERF38Z): notes off
    jb .m
    call CALLOFF
.m: call CAPPLY             ; waiting rate / gain now (RECORD page in step)
    mov bx,S_COFF           ; PERF38Q: shown now, while this string's memory is still owned
    call NMSG
    mov byte [CAPON],0      ; only now (FZ calls above stay off the overlay's area)
    ret

CAPRUN:             ; one main-loop pass
    cmp byte [BKON],0       ; PERF38Q: a bank switch (handled before capture sees CCs) ends capture
    jnz CAPEND
    mov ax,[0x40a]
    mov dx,ax
    sub ax,[CLAST]
    mov [CLAST],dx
    add [CEL],ax
    adc word [CEL+2],0
    mov al,[CST]
    cmp al,1
    jb CSTART
    jz .rc
    cmp al,4
    jz .rl
    cmp al,3
    jnz .pl
    call CFDU               ; PERF38U: fading: the release plays out, then the next capture
    mov cx,5184             ; 50 ms
    mul cx
    call CELLT
    jb .fr
    mov byte [CST],0
.fr: ret
.rc: jmp CREC
.rl: mov al,[CNN]           ; PERF38Z: releasing, highest first: note k (released so far) is due at k x stagger
    sub al,[CNS]
    call CSTM
    call CELLT
    jb .fr
    call CALL1
    cmp byte [CNS],0
    jnz .rl
    call CZERO              ; all released: the fade from now
    jmp short .s3
.pl: mov al,[CNS]           ; playing: start the notes that are due
    cmp al,[CNN]
    jae .h
    call CSTM               ; due at note x stagger
    call CELLT
    jb .h
    mov bl,[CNS]
    xor bh,bh
    mov al,[bx+CNK]
    mov cl,[bx+CNV]
    mov ah,0x90
    call CPNOTE
    inc byte [CNS]
    jmp .pl
.h: cmp byte [CRQ],0        ; recapture asked for: now
    jnz .end
    cmp byte [CHM],7        ; until RECAPTURE (turning P4 away ends it at the next check)
    jz .r
    mov ax,[CHLD]           ; otherwise until the hold time
    mov dx,[CHLD+2]
    call CELLT
    jb .r
.end: xor ax,ax              ; PERF39B: (room)
    mov [CRQ],al
    dec ax
    mov [CPCV],ax           ; PERF38Q: the sync wait takes its reference now, then waits for the next boundary
    call CZERO
    cmp byte [CRLM],0       ; PERF38Z: TOP FIRST: one note off per stagger step (state 4), then the fade
    jz .e0
    mov byte [CST],4
    ret
.e0: call CALLOFF
.s3: mov byte [CST],3        ; PERF38U: fade first (no fade: on to the capture at the next pass)
    ret
.r: ret
CELLT:              ; PERF38W: CF=1 while CEL < dx:ax (bx, cx changed)
    mov cx,[CEL]
    mov bx,[CEL+2]
    sub cx,ax
    sbb bx,dx
    ret

CSTART:             ; wait for the sync division, then arm and record
    mov al,[0xbde]          ; PERF38P: not until the ROM has taken every queued key event (the chord's note-offs):
    cmp al,[0xbe0]          ; one handled after rec_start makes the ROM wait on the busy gate array for ever
    jnz .r
    mov bl,[CSYN]
    or bl,bl
    jz .go
    xor bh,bh
    mov cx,[PCNT]
    cmp cx,768
    jae .r                  ; no clock yet
    mov al,[cs:bx+CSYT-1]
    xor ah,ah
    mov dx,6
    mul dx                  ; division in clocks
    xchg ax,cx
    xor dx,dx
    div cx
    cmp word [CPCV],0xffff
    jz .set
    cmp ax,[CPCV]
    jz .r
    mov [CPCV],ax
    jmp short .go
.set: mov [CPCV],ax
.r: ret
.go: call CAPPLY
    call CMS                ; PERF38W: this take's duration, latched (CHLD is free while recording): CREC stops the
    mov cx,104              ; recording on it, CHOLD counts passes from it
    mul cx
    mov [CHLD],ax
    mov [CHLD+2],dx
    call CWORDS             ; dx:ax = words wanted
    mov [CTW],ax
    mov [CTW+2],dx
    mov si,[0xe04]
    cmp word [si+0x10],0
    jz .a1                  ; no voice: allocate
    cmp dx,[CAW+2]          ; PERF38V grow only: a take that fits the allocation (any length, any rate) is recorded
    ja .new                 ; inside it; only a bigger one allocates again
    jb .fit
    cmp ax,[CAW]
    ja .new
.fit: call CTRIM            ; the allocation's start, the take's end
    jmp short .rs
.new: jmp CAPRE               ; PERF38R: a voice to delete: re-enter capture so the FZ's delete (API 119, a 412h-byte
.a1: mov [CAW],ax            ; stack frame) runs on the 2 KB KSB stack with the overlay released, not on PERF's 1 KB stack
    mov [CAW+2],dx
    add ax,8
    adc dx,0
    push dx
    push ax
    push word [0xe06]
    push word [0xe04]
    APIC 117,8
    or bx,bx
    jz .ok
    xor ax,ax
    mov [CAW],ax
    mov [CAW+2],ax
    mov byte [RST],6
    mov bx,S_CMEM           ; PERF38Q: shown before the overlay is released
    call NMSG
    mov byte [CAPON],0
    ret
.ok: mov si,[0xe04]
    push si
    add si,8
    mov di,CGS
    call CPY4
    pop si
    mov byte [CFST],1
.rs: push word 0            ; no pre-record
    push word [0xe06]
    push word [0xe04]
    APIC 45,6
    cmp byte [0x4d9],3      ; 4.5k: anti-alias filter an octave below 9k, as normal recording
    jnz .f45
    mov al,0x5c
    out 0xbe,al
.f45: call NFAP              ; PERF39A: a NORM FILTER / cutoff chosen with CC110, over the rate's default (resident)
    mov al,[0x46d]          ; outputs straight back on (the FZ muted them for recording)
    or al,0x20
    mov [0x46d],al
    out 0x78,al
    mov byte [RST],1        ; (main loop polls the MIDI UART; other record / edit functions refuse)
    APIC 46,0
    mov byte [0x4d7],3
    call CZERO
    mov byte [CST],1
    ret

CREC:               ; recording: until the take's duration (PERF38W: the ROM records to the allocation's end, voice +04h,
    mov ax,[CHLD]           ; not to the take's end, so a shorter take inside it is stopped here) or both record
    mov dx,[CHLD+2]         ; generators have stopped
    call CELLT
    jnb .done
    push word 1
    APIC 49,2
    test bl,1
    jnz .rr
    push word 0
    APIC 49,2
    test bl,1
    jz .done
.rr: ret
.done: call CSTOP
    mov di,8                ; start / end to zero crossings inside the take
    call CTZ
    mov di,0xc
    call CTZ
    mov ax,[si+0xc]         ; snapped into nothing (end - start 16 words or less, or crossed): the take as it was
    mov dx,[si+0xe]         ; (PERF38Z: high bits cancel, start and end are in one block)
    sub ax,[si+8]
    sbb dx,[si+0xa]
    jb .un
    jnz .lp
    cmp ax,16
    ja .lp
.un: call CGSR
.lp: mov word [si+0x12],0   ; loop 0 = the take, sustain and end loop, no crossfade
    mov ax,[si+8]
    mov [si+0x14],ax
    mov ax,[si+0xa]
    and ax,0x1f
    mov [si+0x16],ax
    mov ax,[si+0xc]
    mov [si+0x34],ax
    mov ax,[si+0xe]
    and ax,0x1f
    mov [si+0x36],ax
    add word [si+0xc],8     ; PERF38S: play end 8 words past the loop end (into the allocation's 8 guard words). With
    adc word [si+0xe],0     ; the loop end equal to the play end the generator stopped first and never looped (PERF's
    mov word [si+0x54],0    ; own one-shot mode parks the loop there for exactly that reason)
    mov word [si+0x64],1022
    call CSNAP
    call CHORD
    call CHOLD
    xor al,al               ; PERF39B: (room)
    mov [CNS],al
    mov [CRQ],al            ; presses during the recording don't count
    call CZERO
    mov byte [CST],2
.r: ret

CHORD:              ; si = voice: CNN keys / velocities for the interval set, transpose and velocity mode
    mov al,[CSGI]           ; PERF38X: this chord's stagger, latched (the hold is counted from it); a new setting applies
    mov [CSGL],al           ; to the next chord
    mov bl,[CCH]
    xor bh,bh
    shl bx,2
    add bx,CHT
    xor di,di
.n: cmp di,4
    jae .x
    mov al,[cs:bx+di]
    cmp al,0x80
    jz .x
    add al,[CTR]
    cbw
    mov cl,[si+0xb0]        ; original key
    xor ch,ch
    add ax,cx
    jns .k1
    xor ax,ax
.k1: cmp ax,127
    jbe .k0
    mov al,127
.k0: mov [di+CNK],al
    mov al,[CVM]            ; velocity
    cmp al,1
    jb .vs
    jz .vr
    mov ax,di
    mov ah,27
    mul ah
    cmp byte [CVM],2
    jz .vf
    add al,46               ; rising: 46, 73, 100, 127
    jmp short .vw
.vf: neg al                 ; falling: 127, 100, 73, 46
    add al,127
    jmp short .vw
.vr: mov ax,[CPRN]          ; random: 40..127
    shr ax,1
    jnc .r1
    xor ax,0xB400
.r1: mov [CPRN],ax
    mov ah,88
    mul ah
    mov al,ah
    add al,40
    jmp short .vw
.vs: mov al,100
.vw: mov [di+CNV],al
    inc di
    jmp .n
.x: mov ax,di
    mov [CNN],al
    ret

CHOLD:              ; CHLD = the hold: passes of the take at the transposed pitch, seconds, or until RECAPTURE;
    mov al,[CHM]            ; plus the stagger of the last note
    cmp al,7
    jb .a
    xor ax,ax               ; until RECAPTURE: no time (CAPRUN waits for P8)
    mov [CHLD],ax
    mov [CHLD+2],ax
    ret
.a: cmp al,4
    jb .p
    mov cl,al               ; 2 / 4 / 8 s = 207360 (32A00h) units << n
    sub cl,4
    mov ax,0x2A00
    mov dx,3
    jmp short .sh
.p: mov al,[CTR]             ; PERF38Z: transpose rounded to octaves (-24..+24 -> -2..+2) for the pass time, so the
    add al,30               ; take plays a little over or under a whole number of loops away from octaves (pitch is
    xor ah,ah               ; unchanged); the exact 2^(-t/12) table went to make room
    mov cl,12
    div cl
    sub al,2
    mov ch,al
    mov ax,[CHLD]           ; PERF38W: the take's latched duration = one pass at the original pitch
    mov dx,[CHLD+2]
    or ch,ch
    jz .ps
    js .up
.dn: shr dx,1
    rcr ax,1
    dec ch
    jnz .dn
    jmp short .ps
.up: shl ax,1
    rcl dx,1
    inc ch
    jnz .up
.ps: mov cl,[CHM]           ; 1 / 2 / 4 / 8 passes
.sh: or cl,cl
    jz .st
.s1: shl ax,1
    rcl dx,1
    dec cl
    jnz .s1
.st: mov [CHLD],ax
    mov [CHLD+2],dx
    cmp byte [CHM],4        ; PERF38Q: seconds are counted from the first note, no stagger added
    jae .r
    mov al,[CNN]            ; + (notes - 1) x stagger
    dec al
    jle .r
    call CSTM
    add [CHLD],ax
    adc [CHLD+2],dx
.r: mov si,[0xe04]
    ret

CTRIM:              ; PERF38V: CGS end = CGS start + the take's words, then CGSR (PERF38Z: start and end lie in the same
    mov ax,[CGS]            ; block, so the end takes the start's high bits as they are)
    mov dx,[CGS+2]
    add ax,[CTW]
    adc dx,[CTW+2]
    mov [CGS+4],ax
    mov [CGS+6],dx
CGSR:               ; voice si: start / end of the take (in the allocation) back
    push si
    lea di,[si+8]
    mov si,CGS
    call CPY4
    pop si
    ret
CPY4: push es               ; 4 words si -> di
    push ds
    pop es
    cld
    mov cx,4
    rep movsw
    pop es
    ret

CSTM:               ; dx:ax = al x stagger (ah is ignored) (PERF38W: from the stagger step, table in 20 ms x 2080 units; PERF38X: the
    mov bl,[CSGL]           ; chord's latched step; bx, cx changed)
    xor bh,bh
    mul byte [cs:bx+CSGT]
    mov cx,2080
    mul cx
    ret

CAPPLY:             ; rate / gain changes made since the last capture
    mov al,[CPRT]
    cmp al,0xff
    jz .g
    mov [0x4d9],al
    mov byte [CPRT],0xff
.g: mov al,[CPGN]
    cmp al,0xff
    jz .r
    mov [0x4d8],al
    mov byte [CPGN],0xff
    xor ah,ah
    push ax
    APIC 48,2
.r: ret

CSTOP:              ; rec_stop, pre-record 0 as at rec_start; then the MIDI dropped, the take finished (PERF38U: merged)
    push word 0
    push word [0xe06]
    push word [0xe04]
    APIC 47,6
    call CMIDI

CFIN:               ; finished take: a normal voice; the first in an allocation is set up as a new take
    mov si,[0xe04]
    mov word [si+0x10],0x1d7
    mov byte [RST],4
    mov al,[0x4d9]          ; PERF38V: the take's rate (it may be lower than the allocation's first take)
    mov [si+0xb1],al
    mov word [si+0xae],0x007F   ; PERF38Y: key range as wide as PERF allows, so chord notes are not refused: highest 127,
    call WRITE.cl           ; lowest 0, then PERF's own rule (within 3 octaves of the original key, lowest <= orig <= highest)
    jmp CSNAP               ; then PERF's copy = the take as recorded, so the zero-crossing snap searches inside this take
                            ; (CREC takes the copy again after the loop set-up)
CSNAP:              ; PERF38V: PERF's copy of the voice (PERF exit, SAMPLE START / END) = this take, every take; the filter
    mov al,0                ; and envelopes are set up only for a new allocation (RETN 1 keeps them)
    xchg al,[CFST]
    xor al,1
    mov [RETN],al
    call AFTER
    mov byte [RETN],0
    jmp L61DB

CALLOFF:            ; note off for every note started
    call CALL1
    jnz CALLOFF
    ret
CALL1:              ; PERF38Z: note off for the last note started (the highest: every chord set is ascending); ZF=1 none
    mov bl,[CNS]
    or bl,bl
    jz .r
    dec bl
    mov [CNS],bl
    xor bh,bh
    mov al,[bx+CNK]
    mov ah,0x80
    call CPNOTE
    or sp,sp
.r: ret

CPNOTE:             ; ah = status (the ROM adds the basic channel), al = key, cl = velocity (on only)
    xor bx,bx
    cmp ah,0x90
    jnz .v
    mov bl,cl
.v: push bx
    mov bl,al
    push bx
    mov bl,ah
    push bx
    APIC 0x33,6
    ret

CMS:                ; ax = capture ms for CLEN
    mov bl,[CLEN]
    xor bh,bh
    shl bx,1
    mov ax,[cs:bx+CMST]
    ret

CWORDS:             ; dx:ax = record words for CLEN at the current rate (36 words per ms at 36k)
    call CMS
    mov cx,36
    mul cx
    mov cl,[0x4d9]          ; (ch is still 0) PERF38Y: halved per rate step with LOOP
    jcxz .r
.s: shr dx,1
    rcr ax,1
    loop .s
.r: ret

CTZ:                ; voice si, field di (8 start / 0Ch end): nearest zero crossing inside the take
    push si
    mov bx,si
    add bx,di
    mov ax,[bx]
    mov dx,[bx+2]
    and dx,0x1f
    push bx
    call ZCNEAR
    pop bx
    mov [bx],ax
    mov cx,[bx+2]
    and cx,0xffe0
    or dx,cx
    mov [bx+2],dx
    pop si
    ret

CSHOW:              ; 'CLLLL HH +TT S': ms, hold, transpose, sync
    call CMS
    xor dx,dx
    mov di,S_CAP+4
    mov cx,4
    call DECN
    mov bl,[CHM]
    xor bh,bh
    shl bx,1
    mov ax,[cs:bx+CHMC]
    mov [S_CAP+6],ax
    mov al,[CTR]
    mov ah,'+'
    or al,al
    jns .p
    neg al
    mov ah,'-'
.p: mov [S_CAP+9],ah
    mov di,S_CAP+10
    call DEC2
    mov bl,[CSYN]
    xor bh,bh
    mov al,[cs:bx+CSYC]
    mov [S_CAP+13],al
    mov bx,S_CAP
CMSG: jmp NMSGD             ; paced message; no CC echo for this control

CSHOW2:             ; 'IIII VVV SSSSMS': intervals, velocity, stagger
    mov bl,[CCH]
    xor bh,bh
    shl bx,2
    mov ax,[cs:bx+CHNM]
    mov [S_CP2],ax
    mov ax,[cs:bx+CHNM+2]
    mov [S_CP2+2],ax
    mov bl,[CVM]
    xor bh,bh
    mov al,3
    mul bl
    mov bx,ax
    mov ax,[cs:bx+CVN]
    mov [S_CP2+5],ax
    mov al,[cs:bx+CVN+2]
    mov [S_CP2+7],al
    mov bl,[CSGI]
    xor bh,bh
    mov al,[cs:bx+CSGT]
    mov ah,20
    mov di,S_CP2+12
    mov bx,S_CP2
CSMS: mul ah                ; ax = al x ah ms, 4 digits ending at di; show bx
    xor dx,dx
    push bx
    mov cx,4
    call DECN
    pop bx
    jmp CMSG
CFDU: mov bl,[CFAD]         ; PERF38U: ax = fade in 50 ms steps
    xor bh,bh
    mov al,[cs:bx+CFDT]
    xor ah,ah
    ret
CSHOWF: call CFDU           ; 'FADE 0000MS'
    mov ah,50
    mov di,S_CF+8
    mov bx,S_CF
    jmp CSMS

CMST: dw 10,20,30,50,75,100,150,200,300,500,750,1000,1500,2000,3000,4000   ; capture ms
CHMC: db 'x1x2x4x82s4s8sRC' ; hold: passes, seconds, until RECAPTURE
CSGT: db 0,1,2,3,4,6,8,10,15,20,25,30,40,60,90,120   ; PERF38T: stagger / 20 ms: 0 .. 2.4 s
CHT: db 0,0x80,0x80,0x80    ; original           (intervals in semitones, 80h = none)
     db -12,0,12,0x80       ; octaves (PERF38Z: every set ascending)
     db 0,7,12,0x80         ; root + 5th + octave
     db 0,4,7,0x80          ; major
     db 0,3,7,0x80          ; minor
     db 0,4,7,11            ; major 7th
     db 0,3,7,10            ; minor 7th
     db -12,-7,0,0x80       ; 5th + octave below
     db -12,0,7,16          ; wide spread
S_CAP: db 'C0000 x1 +00 F',0
S_CP2: db 'ORIG SAM 0000MS',0
CVN: db 'SAMRNDFALRIS'      ; PERF39A: back from the resident data
CFDT: db 0,1,2,4,8,16,24,32   ; fade / 50 ms (PERF39A: back from the resident data)
S_CF: db 'FADE 0000MS',0
%if ($-$$) > 0x7C4
%error capture overlay too big (variables at DBC4h)
%endif
    times 0x7FE-($-$$) db 0
    dw 0xCA9E
