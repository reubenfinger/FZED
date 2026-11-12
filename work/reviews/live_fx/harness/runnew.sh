#!/bin/sh
# usage: runnew.sh NEWDIR TAG  -> sweep, chase, render on one build, compared with the stored results of the unmodified build
S=$(dirname "$0"); N=$1; T=$2; B=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
for kind in sweep chase render; do
  python3 -I $S/eq.py $N $S/eq_new_${T}_$kind.json $B $kind > $S/eq_new_${T}_$kind.log 2>&1
  echo "== $T $kind"; python3 -I $S/cmp.py $S/eq_old_a2_$kind.json $S/eq_new_${T}_$kind.json | grep -v "^skip\|^coverage old" | tail -14
done
