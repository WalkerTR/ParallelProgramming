#!/bin/bash

if [ -z $3 ]; then
    echo "Missing arguments"
    exit 1
fi

if [ -z $PPPMPIV ]; then
    echo "Missing PPPMPIV environment variable"
    exit 1
fi

VERSION=$PPPMPIV

module load prun
module load openmpi/gcc

N=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)

cd gol
make clean all
cd ..


prun -v -1 -np 1 gol/gol-seq $1 $2 $3 &> out_${VERSION}_${1}_${2}_${3}_\$.txt &

for i in ${N[@]}; do
    prun -v -1 -np ${i} -sge-script /cm/shared/package/reserve.sge/etc/prun-openmpi gol/gol-par $1 $2 $3 &> out_${VERSION}_${1}_${2}_${3}_${i}.txt &
done


for job in `jobs -p`; do
    wait $job
done

echo "DAS4 JOBS EXECUTION WITH INPUT SIZE $1 $2 $3" > timings/out_${VERSION}_$1_$2_$3.txt
echo >> timings/out_${VERSION}_${1}_${2}_${3}.txt
echo >> timings/out_${VERSION}_${1}_${2}_${3}.txt
echo >> timings/out_${VERSION}_${1}_${2}_${3}.txt

echo "### OUTPUT FROM SEQUENTIAL PROGRAM ###" >> timings/out_${VERSION}_${1}_${2}_${3}.txt
cat out_${VERSION}_${1}_${2}_${3}_\$.txt >> timings/out_${VERSION}_${1}_${2}_${3}.txt
echo >> timings/out_${VERSION}_${1}_${2}_${3}.txt
rm out_${VERSION}_${1}_${2}_${3}_\$.txt

for i in ${N[@]}; do
    echo "### OUTPUT FROM PARALLEL PROGRAM ON ${i} NODES ###" >> timings/out_${VERSION}_${1}_${2}_${3}.txt
    cat out_${VERSION}_${1}_${2}_${3}_${i}.txt >> timings/out_${VERSION}_${1}_${2}_${3}.txt
    echo >> timings/out_${VERSION}_${1}_${2}_${3}.txt
    rm out_${VERSION}_${1}_${2}_${3}_${i}.txt
done