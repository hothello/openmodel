#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

# Convert the CG sample of a polymer in a box of solvent to atomic coordinates.

# Input variables.
cg_dump="04_cg_sample_01.dump"
lt_template="initial_guess/06_aa_sample_01.template"
lt_input="06_aa_sample_01.lt"
output="05_sample_aa"
plga=../molc/plga
wat=../molc/tip4p

# 1. Wrap the last frame of the CG sample.
perl ../scripts/dumptools.pl -f last -w $cg_dump

# 2. Patch the CG polymer slab, introducing separate head and tail residues in post-processing.
tmp="tmp_cg_sample"
perl ../scripts/dumptools.pl -p 1 -p 2 -o $tmp -f 1 ${cg_dump/.dump/}_t*dump

# 3. Back-map the CG sample to atomic coordinates.
# NOTE: the order of the atomic coordinates in XYZ files, must reflect the atom types
# in the patched DUMP file containing the CG sample.
backmap -t $plga/lac.xyz -t $plga/gly.xyz -t $wat/tip4p.xyz \
-t $plga/lac1.xyz -t $plga/lac2.xyz -t $plga/gly1.xyz -t $plga/gly2.xyz \
-o $output $tmp.dump
mv -f $output.????* $output.pdb

# 4.1 Render the input script with MOLTEMPLATE.
molecules=$(grep new ${cg_dump/.dump/.lt} | awk '$0~/=/{printf "%s\\n",$0}')
sed -e 's/REPLACE_MOLECULES/'"$molecules"'/' $lt_template > $lt_input
moltemplate.sh -overlay-all -pdb $output.pdb $lt_input

# 4.2 Create the structure file (PSF) to read the DCD file.
# NOTE: requires VMD.
bash ../scripts/data2psf.sh ${lt_input/.lt/.data} $output.pdb
rm -fr output_ttree $tmp.dump
