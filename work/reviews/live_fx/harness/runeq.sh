#!/bin/sh
# usage: runeq.sh OLD NEW TAG   -> sweeps, chase and render for all bands, old and new in parallel
S=$(dirname "$0"); O=$1; N=$2; T=$3; B=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
for kind in sweep chase render; do
  python3 -I $S/eq.py $O $S/eq_old_${T}_$kind.json $B $kind > $S/eq_old_${T}_$kind.log 2>&1 &
  python3 -I $S/eq.py $N $S/eq_new_${T}_$kind.json $B $kind > $S/eq_new_${T}_$kind.log 2>&1
  wait
  echo "== $kind"; python3 -I $S/cmp.py $S/eq_old_${T}_$kind.json $S/eq_new_${T}_$kind.json | tail -12
done
