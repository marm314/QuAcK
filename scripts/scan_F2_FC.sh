#! /bin/bash

MOL="F2"
BASIS="cc-pvqz"
R_START=2.0
R_END=2.5
DR=0.1

for R in $(seq $R_START $DR $R_END)
do
  echo "# nAt nEla nElb nCore nRyd"           > examples/molecule.$MOL
  echo " 2   9     9   4     0"              >> examples/molecule.$MOL
  echo "# Znuc   x            y           z" >> examples/molecule.$MOL
  echo "  F     0.           0.         0."  >> examples/molecule.$MOL
  echo "  F     0.           0.         $R"  >> examples/molecule.$MOL
  ./GoDuck $MOL $BASIS > ${MOL}_${BASIS}_FC_${R}.out
  echo $R `./extract.sh ${MOL}_${BASIS}_FC_${R}.out | tail -4 | head -1`
done

