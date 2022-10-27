# Extract the column 2 and 4 from a number of files.
awk '$1>0{print $2,$4}' $@ | sort -n
