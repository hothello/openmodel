#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

# Input variables.
sample_aa="06_aa_sample_01"
catdcd=/usr/local/lib/vmd/plugins/LINUXAMD64/bin/catdcd5.2/catdcd

# Extract the relaxed atomistic structure (last frame of trajectory).
last=$(catdcd -num $sample_aa.dcd |awk '$0~/Total frames:/{print $3}')
$catdcd -o $sample_aa.pdb -otype pdb -s $sample_aa.psf -stype psf -first $last -dcd $sample_aa.dcd
