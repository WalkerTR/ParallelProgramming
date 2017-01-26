#!/bin/bash

if [ -z $1 ]; then
    echo "Missing problem size"
    exit 1
fi

if [ -z $PPPJAVAV ]; then
    echo "Missing PPPJAVAV environment variable"
    exit 1
fi

VERSION=$PPPJAVAV

module load prun

N=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)


echo "DAS4 JOBS EXECUTION WITH INPUT SIZE $1" > timings/out_${VERSION}_${1}.txt
echo >> timings/out_${VERSION}_${1}.txt
echo >> timings/out_${VERSION}_${1}.txt
echo >> timings/out_${VERSION}_${1}.txt


echo "### OUTPUT FROM SEQUENTIAL PROGRAM ###" >> timings/out_${VERSION}_${1}.txt
prun -v -1 -np 1 ./bin/java-run sokoban.sequential.Sokoban tests/${1}.txt &>> timings/out_${VERSION}_${1}.txt
echo >> timings/out_${VERSION}_${1}.txt



for i in ${N[@]}; do
    echo "### OUTPUT FROM PARALLEL PROGRAM ON ${i} NODES ###" >> timings/out_${VERSION}_${1}.txt
    ./runipl.bash ${i} tests/${1}.txt &>> timings/out_${VERSION}_${1}.txt
    echo >> timings/out_${VERSION}_${1}.txt
done


echo -e "\n\n\n\n\n" >> timings/out_${VERSION}_${1}.txt
