#!/bin/bash

set -x


for run in example/*
do
  run=$(basename $run)
  \rm $run.db
  ./drhook2sqlite.pl $run.db example/$run
  ./drhookmerge.pl $run.db
done

exit

./drhookdiff.pl \
  cy48t3_main+fypp.01.MIMPIIFC1905.2y.pack.db \
  cy48t3_cpg_drv+list_gfl.01.MIMPIIFC1905.2y.pack.db \
  Self 200
