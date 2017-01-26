#!/bin/bash

export PPPJAVAV=1

./das4job.bash t1
./das4job.bash t2
./das4job.bash t3
./das4job.bash t4

export PPPJAVAV=2

./das4job.bash t1
./das4job.bash t2
./das4job.bash t3
./das4job.bash t4

export PPPJAVAV=3

./das4job.bash t1
./das4job.bash t2
./das4job.bash t3
./das4job.bash t4

export PPPJAVAV=4

./das4job.bash t1
./das4job.bash t2
./das4job.bash t3
./das4job.bash t4


