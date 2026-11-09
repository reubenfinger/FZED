#!/usr/bin/env python3
"""Casio FZ-1 disk images: raw .img (1,310,720 bytes) <-> HxC .hfe, and blank FZ data disks.

img -> hfe patches a template HFE made by the HxC software with the Casio FZ-1 layout (same gaps, sync and
sector order as HxC writes), re-encoding only each sector's data field and CRC, so the result matches what the
HxC software would produce from the same .img.

  python3 fz_img_hfe.py tohfe  disk.img  disk.hfe  [--template "Raw Image.hfe"]
  python3 fz_img_hfe.py toimg  disk.hfe  disk.img
  python3 fz_img_hfe.py blank  "PERF SAVE 1" out.img [out.hfe]   (empty FZ data disk, optional .hfe too)
  python3 fz_img_hfe.py selftest [--template ...]                 (template -> img -> hfe must be byte-identical)
"""
import argparse, struct, sys
from pathlib import Path

SECTOR, SECTORS, TRACKS, SIDES = 1024, 1280, 80, 2
HERE = Path(__file__).resolve().parent
DEFAULT_TEMPLATE = Path.home() / "mnt/Casio FZ optional software/FZ CC control/Casio FZ voices/Raw Image.hfe"

def crc16(data, crc=0xFFFF):
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc

def tracks(h):
    """yield (cyl, side, list of stream byte positions in the file) for every track side"""
    for cyl in range(TRACKS):
        off, length = struct.unpack_from("<HH", h, 0x200 + cyl * 4)
        start = off * 512
        for side in range(SIDES):
            pos = []
            for blk in range((length + 511) // 512):
                base = start + blk * 512 + side * 256
                pos.extend(range(base, base + 256))
            yield cyl, side, pos[: length // 2]

def bits_of(h, pos):
    out = []
    for p in pos:
        v = h[p]
        out.extend((v >> k) & 1 for k in range(8))
    return out

def decode_bits(bits):
    return bytes(sum(bits[i + 1 + 2 * k] << (7 - k) for k in range(8)) for i in range(0, len(bits) - 15, 16))

def sectors_in(h, cyl, side, pos):
    """-> list of (sector number, decoded index of first data byte) and the decoded track"""
    dec = decode_bits(bits_of(h, pos))
    found, pending, i = [], None, 0
    while i + 10 < len(dec):
        if dec[i:i + 3] == b"\xA1\xA1\xA1" and dec[i + 3] in (0xFE, 0xFB):
            if dec[i + 3] == 0xFE:
                pending = dec[i + 4:i + 8]; i += 10; continue
            if pending is not None:
                c, hd, r, n = pending
                found.append((r, i + 4)); pending = None; i += 4 + SECTOR + 2; continue
        i += 1
    return found, dec

def encode_into(h, pos, first, values, prev_bit):
    """MFM-encode `values` starting at decoded byte index `first` (16 raw bits each), LSB-first raw byte order"""
    raw = []
    for v in values:
        for k in range(7, -1, -1):
            d = (v >> k) & 1
            raw.append(1 if (prev_bit == 0 and d == 0) else 0); raw.append(d); prev_bit = d
    for j in range(0, len(raw), 8):
        byte = 0
        for k in range(8):
            byte |= raw[j + k] << k
        h[pos[first * 2 + j // 8]] = byte

def hfe_to_img(h):
    img = bytearray(SECTORS * SECTOR); seen = 0
    for cyl, side, pos in tracks(h):
        found, dec = sectors_in(h, cyl, side, pos)
        for r, d in found:
            loc = 16 * cyl + 8 * side + (r - 1)
            img[loc * SECTOR:(loc + 1) * SECTOR] = dec[d:d + SECTOR]; seen += 1
    if seen != SECTORS: raise SystemExit(f"only {seen} of {SECTORS} sectors found")
    return bytes(img)

def img_to_hfe(img, template):
    h = bytearray(template); done = 0
    for cyl, side, pos in tracks(h):
        found, dec = sectors_in(h, cyl, side, pos)
        for r, d in found:
            loc = 16 * cyl + 8 * side + (r - 1)
            data = img[loc * SECTOR:(loc + 1) * SECTOR]
            crc = crc16(b"\xA1\xA1\xA1\xFB" + data)
            tail = dec[d + SECTOR + 2] if d + SECTOR + 2 < len(dec) else 0x4E
            encode_into(h, pos, d, data + bytes([crc >> 8, crc & 0xFF, tail]), dec[d - 1] & 1)
            done += 1
    if done != SECTORS: raise SystemExit(f"only {done} of {SECTORS} sectors written")
    return bytes(h)

def blank_img(name, like):
    """empty FZ data disk: disk ID like the template's, CAT = sectors 0-1 used, empty directory"""
    img = bytearray(like)
    nm = name.upper().encode("ascii")[:12].ljust(12, b" ")
    s0 = bytearray(like[0:SECTOR])
    s0[0:12] = nm; s0[16:28] = nm
    s0[128:128 + 768] = bytes(768); s0[128] = 0x03
    img[0:SECTOR] = s0
    img[SECTOR:2 * SECTOR] = bytes(SECTOR)
    for loc in range(2, SECTORS):
        img[loc * SECTOR:(loc + 1) * SECTOR] = b"\x5a" * SECTOR
    return bytes(img)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("cmd"); ap.add_argument("args", nargs="*")
    ap.add_argument("--template", default=str(DEFAULT_TEMPLATE)); a = ap.parse_args()
    tpl = Path(a.template).read_bytes()
    if tpl[:8] != b"HXCPICFE": raise SystemExit("template is not an HFE")
    if a.cmd == "tohfe":
        Path(a.args[1]).write_bytes(img_to_hfe(Path(a.args[0]).read_bytes(), tpl))
    elif a.cmd == "toimg":
        Path(a.args[1]).write_bytes(hfe_to_img(Path(a.args[0]).read_bytes()))
    elif a.cmd == "blank":
        img = blank_img(a.args[0], hfe_to_img(tpl)); Path(a.args[1]).write_bytes(img)
        if len(a.args) > 2:
            h = img_to_hfe(img, tpl); assert hfe_to_img(h) == img; Path(a.args[2]).write_bytes(h)
    elif a.cmd == "selftest":
        img = hfe_to_img(tpl); h = img_to_hfe(img, tpl)
        print("template -> img -> hfe identical:", h == tpl)
        b = blank_img("SELFTEST", img); print("blank img survives hfe round trip:", hfe_to_img(img_to_hfe(b, tpl)) == b)
    else: raise SystemExit(__doc__)

if __name__ == "__main__": main()
