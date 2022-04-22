#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

# Create a slab of polymer in a box of solvent.

# Input variables.
polymer_dump="02_cg_slab_01.dump"
solvent_dump="initial_guess/tip4p_box.dump"
merged="03_merged"
lt_template="initial_guess/04_cg_sample_01.template"
lt_input="04_cg_sample_01.lt"
delta=5 # This distance should be the sum of the largest sigma of the slab and the solvent.

# 1. Extract the last configuration of the slab, after a short annealing.
perl ../scripts/dumptools.pl -f last $polymer_dump
last=${polymer_dump/.dump/}_f*.dump

# 2. Find the max value along Z of the slab coordinates.
z_min=$(perl ../scripts/dumptools.pl -c $last | awk '$1~/^Z/{print $2}')
z_max=$(perl ../scripts/dumptools.pl -c $last | awk '$1~/^Z/{print $3}')

# 3. Read the box vectors of the slab and the solvent: compute the length.
vect1=$(grep -A 3 "ITEM: BOX" $last |tail -n+2 | awk '{printf "%g ",$2-$1}')
vect2=$(grep -A 3 "ITEM: BOX" $solvent_dump |tail -n+2 | awk '{printf "%g ",$2-$1}')

# 3.1 Split the vectors into an array.
read -r -a pbc1 <<< "$vect1"
read -r -a pbc2 <<< "$vect2"

# 4. Compute the supercell indexes for the solvent.
for i in {0..2}; do
  ind[$i]=$(awk -v a=${pbc1[$i]} -v b=${pbc2[$i]} 'BEGIN{printf "%.0f",a/b+.5}')
done

# 5.1 Create a supercell of solvent.
echo "Creating a "${ind[0]}"x"${ind[1]}"x"${ind[2]} "supercell of solvent..."
out="tmp_water"
perl ../scripts/dumptools.pl -s ${ind[0]},${ind[1]},${ind[2]} -o $out $solvent_dump

# 5.2 Center the supercell.
echo "Centering the supercell..."
mv -f ${out}_f*dump /tmp/solvent.dump
perl ../scripts/dumptools.pl -w -o $out /tmp/solvent.dump

# 5.3 Cut the solvent supercell to fit on top of the slab.
echo "Cutting the solvent supercell to fit on top of the slab..."
mv -f ${out}_f*dump /tmp/solvent.dump
vect3=$(grep -A 3 "ITEM: BOX" $last |tail -n+2 | awk '{printf "%g %g ",$1,$2}')
vect4=$(grep -A 3 "ITEM: BOX" /tmp/solvent.dump |tail -n+2 | awk '{printf "%g %g ",$1,$2}')
read -r -a pbc3 <<< "$vect3"
read -r -a pbc4 <<< "$vect4"
# The upper limit should not overlap with the bottom of the slab.
upper=$(awk -v zmin=${pbc3[4]} -v zmax=${pbc3[5]} -v slab=$z_min -v c=$delta 'BEGIN{printf "%g",zmax-zmin+slab-c}')
zshift=$(awk -v a=${pbc4[4]} -v b=$z_max -v c=$delta 'BEGIN{printf "%g",b+c-a}')
perl ../scripts/dumptools.pl -t 0,0,$zshift -e "x > ${pbc3[0]} & x < ${pbc3[1]} & y > ${pbc3[2]} & y < ${pbc3[3]} & z < $upper" -o $out /tmp/solvent.dump

# 6. Merge the slab and the solvent into a single sample.
echo "Merge the slab and the solvent together..."
perl ../scripts/dumptools.pl -g s -o $merged $last ${out}_f*dump

# 7.1 Update the number of molecules in the template file for the next calculation.
nslab=$(perl ../scripts/dumptools.pl -c $last -d 2>&1 | awk '$0~/Number of molecules:/{print $4}')
nsolv=$(perl ../scripts/dumptools.pl -c ${out}_f*dump -d 2>&1 | awk '$0~/Number of molecules:/{print $4}')
sed -e 's/REPL_SLAB/'$nslab'/; s/REPL_WATER/'$nsolv'/' $lt_template > $lt_input

# 7.2 Render the input script with MOLTEMPLATE.
moltemplate.sh -atomstyle "hybrid molecular ellipsoid" -molc -dump ${merged}.dump $lt_input
rm -fr output_ttree $last ${out}_f*dump
