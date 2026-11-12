import math, random
def signal(n=4096):
    r = random.Random(7); s = []
    for i in range(n):
        k = i // 256
        if k % 8 == 0: v = int(30000 * math.sin(i * 0.05))
        elif k % 8 == 1: v = r.randrange(-32768, 32768)
        elif k % 8 == 2: v = (32767, -32768, 32767, -32767, 0, 1, -1, 16384)[i % 8]
        elif k % 8 == 3: v = int(3000 * math.sin(i * 0.31) + 200 * math.sin(i * 2.9))
        elif k % 8 == 4: v = r.randrange(-64, 65)
        elif k % 8 == 5: v = max(-32768, min(32767, int(40000 * math.sin(i * 0.011))))
        elif k % 8 == 6: v = ((i * 517) & 0xffff) - 32768
        else: v = r.choice((-32768, 32767, 0, -1, 1, 12345, -12345, 0x4000, -0x4000, 0x7ffe, -0x7fff))
        s.append(v & 0xffff)
    return s
