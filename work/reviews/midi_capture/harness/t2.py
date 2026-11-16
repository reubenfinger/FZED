import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# A controller sweeping K knobs at R messages per second each, against a build with a live effect on (or none).
# Time: emulator clocks; SHARE = the part of the 8 MHz CPU FZED gets (0.285 measured on the FZ at light load).
# Reports CCs applied per second, the wait of each CC, the ring backlog, and what was applied after the ring was lapped.
import mh
bd = sys.argv[1]; band = int(sys.argv[2]); knobs = int(sys.argv[3]); rate = float(sys.argv[4]); secs = float(sys.argv[5])
share = float(os.environ.get('SHARE', '0.285')); running = os.environ.get('RUNNING') == '1'
h = mh.M(bd)
if band >= 0: h.live(mh.cen15(band))
h.to_loop(); CPS = 8e6 * share
ccs = [74, 75, 71, 73, 78, 79][:knobs]; ev = []; n = int(rate * secs)
for k, cc in enumerate(ccs):
    for i in range(n):
        t = (i + k / knobs) / rate * CPS; v = (i * 3 + 7 * k) % 128
        bs = [cc, v] if (running and (i or k)) else [0xb0, cc, v]
        if running and knobs > 1: bs = [0xb0, cc, v] if (i == 0 and k == 0) else [cc, v]
        ev.append((t, bs, (cc, v)))
h.stream(ev); h.watch_dispatch(); h.reset_counts(); h.t0 = 0
maxpend = 0
while h.v30 < secs * CPS * 1.0:
    h.step(); p = h.pending()
    if p > maxpend: maxpend = p
sent = [(t, tag) for t, tag, lap in h.sent]; lapped = sum(1 for t, tag, lap in h.sent if lap)
got = h.got
# match applied (cc, value) pairs against what was sent, in order
si = 0; waits = []; wrong = []; lost = 0
for t, cc, v in got:
    j = si
    while j < len(sent) and sent[j][1] != (cc, v): j += 1
    if j == len(sent): wrong.append((round(t / CPS, 3), cc, v)); continue
    lost += j - si; waits.append((t - sent[j][0]) / CPS); si = j + 1
p = h.acc['pass']
print('build %s  band %d  knobs %d x %g/s (%d CC/s, %s)  %.1f s at %.1f%% of the CPU' % (os.path.basename(bd), band, knobs, rate, knobs * rate, 'running status' if running else 'full status', secs, share * 100))
print('  passes per second %.1f, clocks per pass %.0f' % (p[0] / secs, p[1] / max(1, p[0])))
print('  sent %d, applied %d (%.1f per second), applied but never sent (mis-parsed) %d, skipped %d, messages that arrived on a full ring %d' % (len(sent), len(got), len(got) / secs, len(wrong), lost, lapped))
if waits: print('  wait from arrival to DISPATCH: median %.0f ms, max %.0f ms; largest backlog %d bytes' % (sorted(waits)[len(waits) // 2] * 1000, max(waits) * 1000, maxpend))
if wrong: print('  first mis-parsed:', wrong[:6])
