import sys
p = sys.argv[1] + '/fzed.asm'; s = open(p).read()
old = "    call LVRUNX             ; PERF38H: paced LCD, curve steps, then live FX\n"
assert s.count(old) == 1
open(p, 'w').write(s.replace(old, old + "    call LVRUNW             ; a second live chunk in the same pass\n"))
