#!/usr/bin/env bash

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
# Last revision: 5 August 2020
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.
#

function usage(){
cat << EOF

Usage: data2psf [options] file.data file.pdb

Convert a LAMMPS data file with "atom_style full" into a PSF topology file.

OPTIONS
 -d [number] Remove dummy bonds with coefficient [number].

EOF
}

dummy=-1

# Check the input arguments
if [ $# -eq 0 ]; then
  usage
  exit 0
fi
while getopts ":help:d:" opt; do
  case $opt in
    h|help) usage
            exit 0
            ;;
    d) dummy=$OPTARG
       ;;
    ?) echo "Invalid option: -$opt" >&2
       exit 0 ;;
  esac
done
shift "$((OPTIND-1))"
while (( "$#" )); do # While there are arguments still to be shifted...
  if [[ -e $1 ]]
  then
    if [[ $(grep -e LAMMPS -e atoms -c $1) -ge 2 ]]
    then
      data=$1
    fi
    if [[ $(grep -ih -e ^"ATOM " -e ^"HETATM " -c $1) -ge 1 ]]
    then
      pdb=$1
    fi
  fi
  shift
done

if [[ -z "$data" ]]
then
  echo "DATA file not found. Type data2psf to see the usage."
  exit
fi

if [[ -z "$pdb" ]]
then
  echo "PDB file not found. Type data2psf to see the usage."
  exit
fi

# DEBUG
#echo "Dummy: " $dummy
#echo "DATA: " $data
#echo "PDB: " $pdb
#exit

# Create the header of the PSF, from the PDB file.
echo "mol new $pdb
animate write psf header
quit" >psf_tmp.tcl
vmd -dispdev none -e psf_tmp.tcl >/dev/null 2>/dev/null
start=$(grep -m 1 --color=never -n NATOM header |sed 's/:/ /' |awk '{print $1+1}')
end=$(grep -m 1 --color=never -n NATOM header |sed 's/:/ /' |awk '{print $1+$2}')
stop=$((end+1))
# https://www-s.ks.uiuc.edu/Training/Tutorials/namd/namd-tutorial-win-html/node24.html
# The fields in the atom section are:
# atom ID, segment name, residue ID, residue name, atom name, atom type, charge, mass, and an unused 0

# http://prody.csb.pitt.edu/_modules/prody/trajectory/psffile.html
#            serials[n]  = line[:8]
#            segnames[n] = line[9:13].strip()
#            resnums[n]  = line[14:19]
#            resnames[n] = line[19:23].strip()
#            atomnames[n]= line[24:28].strip()
#            atomtypes[n]= line[29:35].strip()
#            charges[n]  = line[35:44]
#            masses[n]   = line[50:60]
# PSFLINE = ('%8d %-4s %-4d %-4s %-4s %-4s %10.6f %13.4f %11d\n')
# Add a SEQ name, if missing.
sed -n ''$start','$end'p;'$stop'q' header |\
awk '{if(NF==9){printf "%i %s %i %s %s %s %s\n",$1,$2,$3,$4,$5,$6,$8}
      if(NF==8){printf "%i DUM %i %s %s %s %s\n",$1,$2,$3,$4,$5,$7}}' > header.tmp1

# Patch the DATA file to remove dummy bonds
bonds=$(grep -m 1 --color=never -n ^Bonds $data | sed 's/:/ /'|awk '{print $1}')
angles=$(grep -m 1 --color=never -n ^Angles $data | sed 's/:/ /'|awk '{print $1}')
end=$((bonds+1))
sed -n '1,'$bonds'p;'$end'q' $data > patch_tmp.data
echo "" >> patch_tmp.data
end=$((end+1))
stop=$((angles-2))
sed -n ''$end','$stop'p;'$angles'q' $data > bonds.tmp
awk -v v=$dummy '$2!~v{c++;printf "%5i %3i %i %i\n",c,$2,$3,$4}' bonds.tmp >> patch_tmp.data
echo "" >> patch_tmp.data
sed -n ''$angles',$p' $data >> patch_tmp.data
# Read the number of bonds
bonds=$(grep -m 1 --color=never -B 2 ^Angles patch_tmp.data |awk 'NR==1{print $1}')
sed -i '4s/[ ]*[0-9]*/'$bonds'/' patch_tmp.data

# Create another PSF file, from the DATA file.
echo "topo readlammpsdata patch_tmp.data full
animate write psf ${data%????}psf
quit" >psf_tmp.tcl
vmd -e psf_tmp.tcl >/dev/null 2>/dev/null
start=$(grep -m 1 --color=never -n NATOM header |sed 's/:/ /' |awk '{print $1+1}')
end=$(grep -m 1 --color=never -n NATOM header |sed 's/:/ /' |awk '{print $1+$2}')
stop=$((end+1))
sed -n ''$start','$end'p;'$stop'q' ${data%????}psf |\
awk '{print $5}' > header.tmp2

# Reconstruct the patched PSF file.
#mv header header.old # debug
sed '6q' ${data%????}psf > header

# Format the section !NATOM
paste -d ' ' header.tmp1 header.tmp2 |\
awk '{printf "%8i %-4s %-4i %-4s %-4s %-4s %10.6f %13.4f %11i\n",$1,$2,$3,$4,$5,$6,$8,$7,0 }' >> header
sed -n ''$stop',$p' ${data%????}psf >> header
mv -f header ${data%????}psf

# Cleanup
rm -f psf_tmp.tcl header.tmp? bonds.tmp patch_tmp.data rep_tmp? rep.sed
