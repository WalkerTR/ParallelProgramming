#!/bin/bash

module load prun

prun -1 -np 1 ./bin/ipl-server &> socket &
PID=$!

sleep 5

SERVER_ADDRESS=`cat socket | head -n 1 | grep -o ' [^ ]*$' | tail -c +2`



prun -v -1 -np $1 ./bin/java-run -Dibis.server.address=$SERVER_ADDRESS -Dibis.pool.name=test -Dibis.pool.size=$1 sokoban.ipl.Sokoban $2


kill $PID
rm -f socket




