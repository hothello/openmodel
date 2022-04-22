#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

# Transform a bulk model of a polymer into a slab.
# Assumptions:
# * The simulation cell must be orthorombic.
# * The slab lies in the XY plane.

# Input variables.
output="01_slab"
gap=150
polymer_dump="initial_guess/plga_cg_amorphous.dump"
lt_template="initial_guess/02_cg_slab_01.template"
lt_input="02_cg_slab_01.lt"

# 1. Create a 2x2x1 supercell of PLGA.
# NOTE: the bulk structure must be wrapped to the box,
# i.e. its COM should be rougly at 0,0,0 and the box coordinates
#      be symmetric around this value.
perl ../scripts/dumptools.pl -s 2,2,1 -o $output $polymer_dump

# 2. Read the box vectors of the supercell.
vect=$(grep -A 3 "ITEM: BOX" ${output}_*dump |tail -n+2 | awk '{printf "%g %g ",$1,$2}')
z_old=$(grep -A 3 "ITEM: BOX" ${output}_*dump |tail -1)

# 2.1 Split the vectors into an array.
read -r -a pbc <<< "$vect"

# 3. Create a slab geometry by adding vacuum on top of the slab.

# 3.1 Patch the Z length of the supercell.
z_max=$(echo ${pbc[5]}+$gap|bc)
z_new=$(printf "%g %g" ${pbc[4]} $z_max)
sed -i -e 's/'"$z_old"'/'"$z_new"'/' ${output}_*dump

# 3.2 Update the number of particles in the template file for the next calculation.
nslab=$(perl ../scripts/dumptools.pl -c ${output}_*dump -d 2>&1 | awk '$0~/Number of molecules:/{print $4}')
sed -e 's/REPL_SLAB/'$nslab'/' $lt_template > $lt_input

# 3.3 Render the input script with MOLTEMPLATE.
moltemplate.sh -atomstyle "hybrid molecular ellipsoid" -molc -dump ${output}_*dump $lt_input

# 3.3 the "f f f" periodic boundaries are used to tell MOLTEMPLATE not to use a costly
# long-range Coulomb solver. After the settings have been rendered, this option is
# changed back to "p p p" in the INIT file.
sed -i 's/ f f f/ p p p/' ${lt_input%??}in.init
rm -fr output_ttree
