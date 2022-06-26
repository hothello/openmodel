#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

# Compute the density profile of both CG and AA samples. 

# Input variables.
temp=$(tempfile -d /tmp)
cg_dump="04_cg_sample_01.dump"
aa_dcd="06_aa_sample_01.dcd"
lmp=/usr/local/bin/lmp_30Oct19

# 1. Patch the DUMP file for the rerun.
sed -f ../scripts/quat_patch.sed $cg_dump > ${temp}.dump

# 2. Compute the density profile of the CG sample.
mpirun -np 4 $lmp -v dumpfile ${temp}.dump -in 09_cg_analysis.in

# 3. Compute the density profile of the AA sample.
mpirun -np 4 $lmp -in 09_aa_analysis.in
 
# 4. Shift the CG density profile to have a better comparison with the AA profile,
#    whose structure was centered on the slab prior to run the MD simulation.
awk 'NF>1{printf "%g %g\n",$1-182,$2}' 09_cg_analysis_slab.out | awk '$1>-90&&$1<-38.5' > 09_cg_analysis_slab.out2
awk 'NF>1{printf "%g %g\n",$1-182,$2}' 09_cg_analysis_slab.out | awk '$1>=-38.5' > tmp.1
awk '$1<=6.5&&NF>1' 09_cg_analysis_slab.out > tmp.2
paste tmp.1 tmp.2 | awk '{printf "%g %g\n",$1,$2+$4}' >> 09_cg_analysis_slab.out2
awk '$1>6.5&&NF>1&&$1<90' 09_cg_analysis_slab.out >> 09_cg_analysis_slab.out2
# same for the solvent.
awk 'NF>1{printf "%g %g\n",$1-182,$2}' 09_cg_analysis_solvent.out > tmp.1
awk 'NF>1&&$1>6.5' 09_cg_analysis_solvent.out >> tmp.1
sort -n tmp.1 | uniq | awk '$1>-90&&$1<90' > 09_cg_analysis_solvent.out2
rm -f tmp.?

# 5. Plot the results. Gnuplot is used to plot the data, with a lot of manual thinkering.
gnuplot 09_cg_profiles.gnu
gnuplot 09_aa_profiles.gnu
