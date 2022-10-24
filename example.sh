#!/bin/bash

set -x


for pack in cy48t3_main+fypp.01.MIMPIIFC1905.2y.pack cy48t3_cpg_drv+list_gfl.01.MIMPIIFC1905.2y.pack
do
  \rm $pack.db
  ./drhook2sqlite.pl $pack.db example/$pack
  ./drhookmerge.pl $pack.db
done
