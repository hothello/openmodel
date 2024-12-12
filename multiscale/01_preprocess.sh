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

# 1. Create a 2x2x1 supercell of PLGA and add a vacuum gap to Zhi.
perl ../scripts/dumptools.pl -s 2,2,1 -o $output -f 1 -b z,0,$gap $polymer_dump

# 2.1 Update the number of particles in the template file for the next calculation.
nslab=$(perl ../scripts/dumptools.pl -c ${output}.dump -d 2>&1 | awk '$0~/Number of molecules/{print $6}')
sed -e 's/REPL_SLAB/'$nslab'/' $lt_template > $lt_input

# 2,2 Render the input script with MOLTEMPLATE.
moltemplate.sh -atomstyle "hybrid molecular ellipsoid" -overlay-bonds -dump ${output}.dump $lt_input
rm -fr output_ttree
