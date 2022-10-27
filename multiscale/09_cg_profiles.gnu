# Settings
set encoding iso_8859_1
set term pdfcairo enh color dashed font "Arial,18" rounded size 4.5,3 
set output '09_cg_profiles.pdf'

set tics scale .5
set xrange [-87.5:87.5]
set yrange [0:1.4]
set format y "%.1f"
set key bottom center samplen 1.4

sc=3
set style line 1 pt 7 ps .2 lc rgbcolor "#d7191c" lw sc
set style line 2 pt 7 ps .2 lc rgbcolor "#d8b365" lw sc
set style line 3 pt 7 ps .1 lc rgbcolor "#7fc97f" lw sc
set style line 4 pt 7 ps .2 lc rgbcolor "#444444" lw sc

set xlabel "Sample profile (\305)"
set ylabel "Density (g/cm^3)" offset -.4,0

scale=18.0152/40.4364
total="<paste 09_cg_analysis_slab.out2 09_cg_analysis_solvent.out2 | awk 'NF>3{print $1,$2+$4*18.0152/40.4364}'"
p '09_cg_analysis_slab.out2' w l ls 1 t'PLGA',\
  '09_cg_analysis_solvent.out2' u 1:($2*scale) w l ls 2  t'water',\
  total every 2 w p ls 3 t'','' u ($1+1/0):2 w l ls 3 t'total'

# Highlight the soft interface.
x1=-50.7
x2=-18.1
x3=24.8
x4=54.8
set object 1 rectangle from x1,0 to x2,1.4 fc rgb "gray90" behind fs noborder
set object 2 rectangle from x3,0 to x4,1.4 fc rgb "gray90" behind fs noborder
rep
