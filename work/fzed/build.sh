#!/bin/sh
# Build FZED from this folder: needs nasm and python3. LVMEASURE=1 sh build.sh makes the measurement build. Makes fzed.bin (as assembled), fzedflat.bin (the 34 KB that
# goes on disk at sector 17), fzed.map and, given a base FZ disk image (any earlier PERF / FZED image), FZ1_FZED.img.
# This is the FZED checkpoint (the FZED40N code, named FZED); later versions start from here.
set -e
cd "$(dirname "$0")"
nasm ${LVMEASURE:+-DLVMEASURE} -I fx/ -f bin fzed.asm -o fzed.bin -l fzed.lst
python3 -c "b=open('fzed.bin','rb').read(); open('fzedflat.bin','wb').write(b[:0x2000]+b[0x2400:])"
if [ -n "$1" ]; then python3 mkimg.py "$1" fzedflat.bin FZ1_FZED.img; fi
(echo "[map symbols fzed.map]"; cat fzed.asm) > _m.asm && nasm ${LVMEASURE:+-DLVMEASURE} -I fx/ -f bin _m.asm -o /dev/null && rm _m.asm
