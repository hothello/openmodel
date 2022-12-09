#!/usr/bin/perl

# Author: Otello M Roscioni
# email om.roscioni@materialx.co.uk
# Last revision: 9 December 2022
#
# Unauthorized copying of this file, via any medium is strictly prohibited.
# Proprietary and confidential.
# 
# Copyright (C) MaterialX LTD - All Rights Reserved.

use Time::Piece;
use File::Basename;

# Default values
$start=localtime(time);
$frame="";
$stype=0;
$deg2rad=3.14159265358979/180.;
$half2rad=3.14159265358979/360.;
# numerical tolerance for zero.
$tol=1e-6;

%mode=(
polymer => 0,
count => 0,
save => 0,
wrap => 0,
fix => 0,
merge => 0,
supercell => 0,
external => 0,
select => 0,
delete => 0,
do => 0,
debug => 0
);

$help="Usage: dumptools [options] file.dump [file2.dump]\n
Perform a series of operations on a DUMP file of the MOLC model.
Spatial operations can be performed on the whole sample or on a
subset of atoms or molecules, selected with the options -m.
The selection interval can be specified as individual
numbers separated by commas (such as 1,2,5) or with the
syntax start:end:(step). The interval sintax allows mixing,
e.g. 1:4,7,10 will select the molecules: 1 2 3 4 7 10.\n
Different tasks are available. To avoid unwanted results, just select
one of the following tasks:\n
*** Polymer Patch ***
Transform the first and last monomer's atom type into a new type, to be
used as a capping residue. If an atom type i is selected to become a
capping residue, the patched atom types will be:
FIRST N+2*i-1
END   N+2*i
Where N is the number of atom types in the sample.
Example:
dumptools -p 1 -p 2 -p 3 file.dump
Here, 3 atom types are present in the input system and all of them can be
on the polymer chain.
For each type, 2 more types will be created depending if the monomer is
the first (left) or last (right) of the chain. Conversion Table:
 ***********************
 * TYPE * FIRST * LAST *
 ***********************
 *    1 *     4 *    5 *
 *    2 *     6 *    7 *
 *    3 *     8 *    9 *
 ***********************
INPUT:
1-1-1-1-1-1-1  2-1-2-1-2-1-2  2-1-1-2-1-1-1  1-3-1-3-1-2-1  3-3-1-1-2-2
OUTPUT:
4-1-1-1-1-1-5  6-1-2-1-2-1-7  6-1-1-2-1-1-5  4-3-1-3-1-2-5  8-3-1-1-2-7\n
NOTE: When using the polymer patch mode, the program won't perform any
transformation on the coordinates such as wrapping, translation or
rotation.\n
*** Frame Count ***
Print the number of frames in the input system and other statistics.
Example:
dumptools -c file.dump\n
*** Post-processing ***
Perform one of the following tasks on the selected frames:
* distance
Example:
dumptools -a distance file.dump\n
*** Spatial operations ***
Translate, rotate, wrap specific molecules or the whole sample. These
operations are available when a frame is selected to be saved. Multiple
translations and rotations can be specified and will be executed in
that order.
Examples:
dumptools -r 90,0,1,0 -t 10,10,0 -m 200:500 -f 12000 file.dump
dumptools -w file.dump
Expression selection is applied after the spatial operations. Logic
operators and mathematical operations are applied to the Cartesian
coordinates to extract a subset of molecules. The original molid is
maintained, and the number of atoms updated. It worls only for single
configurations! Example:
dumptools file.dump -e \"(x**2+y**2)<500\"\n
*** Merge ***
Two or more files will be merged together. The input file must all have
the same data structure, i.e. same number of records in the ATOMS section.
Spatial operations can be used as well, but special care should be paid
when selecting specific molecules, as their value will refer to the
merged value. The option -f is not available in this mode.
The box vectors are taken from the first DUMP file provided.
Example:
dumptools -g s -o merged file1.dump file2.dump file3.dump\n
*** Supercell ***
Create a supercell. Example:
dumptools -s 1,2,2 -f 1 file.dump\n
 Option          Description
------------------------------------------------------------------------
  -h, --help     Print this help.
  -a [task]      Apply one of the following post-processing tasks on the
                 selected frames (default=use all frames):
		 distance  Compute the distance between atom types using
		           the minimum image convention.
  -o [basename]  Name of the output file. Default=basename(input)_f\%i.dump
  -p [integer]   Patch the atom types belonging to a polymer. This option
                 can be repeated multiple times.
  -c             Print the number of frames and atoms in the input file.
                 This mode disables the writing of a new file.
  -f [interval]  Save the selected frame. An interval can also be provided,
                 extracting a sub-trajectory. Input values are flexible:
                 \"last\", \"first\", and \"all\" are valid keywords;
                 -1 stands for the last frame, 0 for all frames.
  -m [interval]  Apply the operation to the specific molecule id(s).
                 Default=all.
  -x             Delete the selected molecules.
  -t [x,y,z]     Translate using the input vector.
  -r [a,x,y,z]   Rotate by an angle a around the vector x,y,z.
  -s [a,b,c]     Create a supercell. Each dimension must be at least 1.
  -e \"condition\" Expression select: print only the molecules or atoms
                 satisfying a logic operation on coordinates or atom types.
                 Examples: \"x > -10 & y < 7 & z >= 0\" or \"(x**2 + (y-4)**2) < 40\"
                           \"t < 3 || t == 5\" or \"x<300 && t == 1\".
  -w             Wrap molecules to the bounding box without splitting them.
                 It supports the atom styles:
                 * hybrid full ellipsoid
                 * hybrid molecular ellipsoid
		 * ellipsoid
  -u             Fix wrapped coordinates of multi-bead molecules. For some
                 cases,this option needs to be used twice, i.e. wrap again
		 the resulting dump file.
  -g [s|a]       Merge two or more files in a single dump. For this task,
                 only the first frame is used. Arguments are:
		 * s Sequence the atom types, e.g. 1 2 3 1 2 to 1 2 3 4 5.
		 * a Append the atom type without changes (default).
  -d             Debug mode.\n";
  
# Check the input arguments
for my $i(0 .. $#ARGV){
        if (-f $ARGV[$i]){push @files, $ARGV[$i];}
        elsif ($ARGV[$i] eq "-o"){
		$basename=$ARGV[$i+1];
		$mode{external}=1;
	}
        elsif ($ARGV[$i] eq "-p"){
		$mode{polymer}=1;
		push @type, $ARGV[$i+1];
	}
	elsif ($ARGV[$i] eq "-f"){$frame=$ARGV[$i+1];}
	elsif ($ARGV[$i] eq "-m"){@molecule=&decomma($ARGV[$i+1]);}
	elsif ($ARGV[$i] eq "-t"){
		my @translate=&decomma($ARGV[$i+1]);
		unshift (@translate, "T"); # Make the array 4 elements long.
		push @operations, @translate if $#translate == 3;
		$mode{save}=1;
	}
	elsif ($ARGV[$i] eq "-r"){
		my @rotate=&decomma($ARGV[$i+1]);
		push @operations, @rotate if $#rotate == 3;
		$mode{save}=1;
	}
	elsif ($ARGV[$i] eq "-s"){
		@replica=&decomma($ARGV[$i+1]);
		$replica[$_]-=1 for 0 .. 2;
		$mode{supercell}=1;
		$mode{save}=1;
		if ($replica[0] < 0 || $replica[1] < 0 || $replica[2] < 0 ){
			die "ERROR: A valid supercell must be greater than 1,1,1\n";
		}
	}
	elsif ($ARGV[$i] eq "-e"){
		$expression=$ARGV[$i+1];
		$expression =~ s/x/\$v[0]/gi;
		$expression =~ s/y/\$v[1]/gi;
		$expression =~ s/z/\$v[2]/gi;
		$expression =~ s/t/\$v[3]/gi;
		$expression =~ s/\\//g;
		$mode{select}=1;
		$mode{save}=1;
	}
        elsif ($ARGV[$i] eq "-c"){$mode{count}=1;}
        elsif ($ARGV[$i] eq "-w"){
		$mode{wrap}=1;
		$mode{save}=1;
	}
        elsif ($ARGV[$i] eq "-u"){
		$mode{wrap}=1;
		$mode{fix}=1;
		$mode{save}=1;
	}
        elsif ($ARGV[$i] eq "-g"){
		$mode{merge}=1;
		$stype=1 if $ARGV[$i+1] =~ /^s$/i;
	}
        elsif ($ARGV[$i] eq "-x"){
                $mode{delete}=1;
                $mode{save}=1;
        }
        elsif ($ARGV[$i] eq "-a"){
                $mode{do}=$ARGV[$i+1];
                $mode{save}=0;
        }
        elsif ($ARGV[$i] eq "-d"){$mode{debug}=1;}
        elsif ($ARGV[$i] eq "-h"||$ARGV[$i] eq "--help"){die $help;}
}
$mode{save}=1 if ($frame && !$mode{polymer});
$mode{save}=0 if ($mode{merge}); # Overwrite inconsistent input.
$frame=1 if ($mode{count} && !$frame);
if ($mode{do} =~ /distance/i){
	$mode{save}=0;
	$frame=0 if !$frame;
}

# Sort the array containing the atom types for polymers.
@type = sort {$a <=> $b} @type if $#type > -1;

# State which molecules will be analysed.
if ($mode{debug} && $#molecule > -1){
	print STDERR "Molecules selected: ";
	foreach (@molecule){print STDERR "$_ "};
	print STDERR "\n";
}
print "\nExpression Selection: $expression\n" if ($mode{debug} && $mode{select});

# Verify that the input file has been specified.
if ($#files<0){
	print "ERROR: input file not specified.\n";
	exit;
}

# Compute the rotation matrix and quaternion.
if ($#operations>-1){
	my $op=($#operations+1)/4 - 1;
	for my $i(0 .. $op){
		my $j=4*$i;
		if ($operations[$j] ne "T"){
			my @rotate;
			$rotate[$_]=$operations[$j+$_] for 0 .. 3;
			my @rm=&rotmat(\@rotate);  
			my @rq=&rotquat(\@rotate);
			push @rm_g, @rm;
			push @rq_g, @rq;
		}
	}
}

# Read the header of the DUMP and store it into a hash.
# The hash is shared also for the $mode{merge}, assuming that
# all the DUMP files have the same structure.
$input=$files[0];
@item_atoms=&field(`awk '/^ITEM: ATOMS/{print; exit}' $input`);
shift @item_atoms for 0 .. 1;
$record{$item_atoms[$_]}=$_ for 0 .. $#item_atoms;
# Process the data header.
@pos=(-1,-1,-1);
for (0 .. $#item_atoms){
	if ($item_atoms[$_] =~ /^x/i){
		$pos[0]=$_;
	} elsif ($item_atoms[$_] =~ /^qw/i || $item_atoms[$_] =~ /^quatw/i || $item_atoms[$_] eq "c_q[1]" || $item_atoms[$_] eq "c_orient[4]"){
		$pos[1]=$_;
		$pos_quat[0]=$_;
	} elsif ($item_atoms[$_] =~ /^qx/i || $item_atoms[$_] =~ /^quatx/i || $item_atoms[$_] eq "c_q[2]" || $item_atoms[$_] =~ /^quati/i || $item_atoms[$_] eq "c_orient[1]"){
		$pos_quat[1]=$_;
	} elsif ($item_atoms[$_] =~ /^qy/i || $item_atoms[$_] =~ /^quaty/i || $item_atoms[$_] eq "c_q[3]" || $item_atoms[$_] =~ /^quatj/i || $item_atoms[$_] eq "c_orient[2]"){
		$pos_quat[2]=$_;
	} elsif ($item_atoms[$_] =~ /^qx/i || $item_atoms[$_] =~ /^quatz/i || $item_atoms[$_] eq "c_q[4]" || $item_atoms[$_] =~ /^quatk/i || $item_atoms[$_] eq "c_orient[3]"){
		$pos_quat[3]=$_;
	} elsif ($item_atoms[$_] =~ /^type/i){
		$pos[2]=$_;
	}
}
if ($mode{debug}){	
	print  STDERR "\nRecords in the ATOMS section:\n";
	printf STDERR "%2i %s\n",$_,$item_atoms[$_] for 0 .. $#item_atoms;
	printf STDERR "X  column: %i\n",$pos[0];
	printf STDERR "QW column: %i\n\n",$pos[1];
}

# Read the timestep of the first last frame.
$time[0]=`awk '{if(e==1){print \$1; exit};if(/^ITEM: TIMESTEP/){e=1}}' $input`;
chomp $time[0];
$tail=`awk '{if(e==1){print \$1+9; exit};if(/^ITEM: NUMBER OF ATOMS/){e=1}}' $input`;
chomp $tail;
$time[1]=0;
$stop=0;
while($time[1]==0 && $stop==0){
	my $last_frame=`tail -$tail $input | awk '{if(e==1){print \$1; exit};if(/^ITEM: TIMESTEP/){e=1}}'`;
	chomp $last_frame;
	$stop=`tail -$tail $input | awk '/^ITEM: TIMESTEP/{print 1; exit}'`;
	chomp $stop;
	if ($last_frame){
		$time[1]=$last_frame;
	} else {
		# Take care of gran-canonical simulations.
		$tail*=2;
	}
}

# Process the input frames. Use @trj to identify the frame number,
# and $frame the first or last timestep, which we need to locate
# while reading the DUMP file.
if ($frame =~ /[:,]+/i){
	@trj=&decomma($frame);
	if ($mode{debug}){
		printf STDERR "%i frames were selected for saving:\n",$#trj+1;
		printf STDERR "%i ",$trj[$_] for 0 .. $#trj;
		print  STDERR "\n";
	}
	$frame=-2;
	
} elsif ($frame eq -1 || $frame=~/^last/i){
	$frame=$time[1];	
	$trj[0]=-1;
} elsif ($frame eq 0 || $frame=~/^all/i){
	$trj[0]=0;
	$frame=-3;
} elsif ($frame eq 1 || $frame=~/^first/i){
	$frame=$time[0];
	$trj[0]=-1;
} elsif ($frame>1){
	$trj[0]=$frame;
	$frame=-1;
} else {
	printf "ERROR: Invalid frame specified: %s\n\n",$frame;
	exit;
}

# Open the required files for writing the output.
if ($mode{save} && !$mode{count}){
	 if ($basename eq ""){
		$output=basename($input);
		$output =~ s/\.dump[\w]*+$//;
		my $suff;
		if ($frame == -3 && $trj[0]==0){
			$suff="all";
		} elsif ($frame == -2 && $#trj>0) {
			$suff=sprintf("f%i-%i",$trj[0],$trj[$#trj]);
		} elsif ($frame == -1 && $trj[0]>1){
			$suff=sprintf("f%i",$trj[0]);
		} elsif ($frame >= 0 && $trj[0] == -1){
			$suff=sprintf("t%i",$frame);
		}
		$output=sprintf("%s_%s.dump",$output,$suff);
	} else {
		$output=$basename.".dump";
	}
	open(OUT,">$output");
}
if ($mode{polymer} && !$mode{count}){
	my $output=$basename;
	$output=basename($input) if $basename eq "";
	$output =~ s/\.dump[\w]*+$//;
	if ($mode{external}){
		$output .= ".dump";
	} else {
		$output .= "_polypatch.dump";
	}
	open(OUT,">$output");
}

# Read the dump file and process the desired frame(s),
# storing the data into an array-of-arrays.
$mode{save}=0 if ($mode{supercell});
if (!$mode{merge}){
	open(DUMP,"<$input") || die "File $input not found.\n";
	$fc=0; # Frame counter.
	$fi=0; # @trj frame index.
	$ac=0; # Atoms counter.
	$go=0; # Switch for processing the current frame.
	$box=0; # Switch for reading the box vectors.
	$stop=-1;
	my $noa=4; # line index in the DUMP telling the number of atoms (in case of grancanonical).
	while(my $line=<DUMP>){
		# Timestep interval
		if ($tsc){
			$tsc=0;
			chomp $line;
			push @timestep, $line;
		}
		if ($line =~ /^ITEM: TIMESTEP/){
			$tsc++;
			# Frame counter: from 1 to last.
			$fc++;
		}
		
		# Number of Atoms. It allows working with gran-canonical simulations,
		# where the number of particles changes over time.
		if ($atc){
			$atc=0;
			chomp $line;
			push @natm, $line;
		}
		$atc++ if $line =~ /^ITEM: NUMBER OF ATOMS/;
		
		# Read the current frame.
		# When $frame is used for the first or last frame, the eq operator must be used:
		# print "You should have not seen this message!\n" if $frame == $timestep[$fc-1]; # true when @timestep is undefined.
		if ($trj[$fi]==$fc || $frame eq $timestep[$fc-1] || $trj[0]==0){
			my @data=&field($line);
			#print STDERR "DEBUG $line \n";
			
			# Store the header.
			if (!$go){
				push @header, $line;
				$go=1 if $line =~ /^ITEM: ATOMS/;
				# PBC vectors.
				push @bb,$line if ($box && !$go);
				$box=1 if ($line =~ /^ITEM: BOX BOUNDS/);
				
				$stop=$natm[$fc-1] if $go;
			} else {
				# Store the atoms section.
				push @coord, \@data;
				$ac++;
			
				# Store the number of atom types in the current frame.
				@ftype=&unique(\@ftype,$data[$record{type}]);
			}
			
			# Process the current frame.
			if ($ac==$stop && $go){
				$go=0;
				$ac=0;
				$box=0;
				$fi++;
				
				# Sort the AoA containing the coordinates w.r.t. the index column.
				@coord = sort {$a->[0] <=> $b->[0]} @coord;
				# do the same for a simple array.
				@ftype = sort {$a <=> $b} @ftype;
				
				# Check that the frame has been read correctly.
				if ($mode{debug}){
					printf STDERR "\n";
					printf STDERR "Current line: %s\n",$line;
					printf STDERR "Current frame: %i\n",$fc;
					printf STDERR "Total atom types found: %i\nTypes: ",$#ftype+1;
					printf STDERR "%i ",$ftype[$_] for 0 .. $#ftype;
					printf STDERR "\n";
					printf STDERR "Bounding Box: ";
					printf STDERR "%s ",$bb[$_] for 0 .. 2;
					printf STDERR "\n";
					printf STDERR "First entry of \@coord: ";
					my @test=@{$coord[0]};
					printf STDERR "%s ",$test[$_] for 0 .. $#test;
					printf STDERR "\n";
					printf STDERR "Last entry of \@coord: ";
					@test=@{$coord[$#coord]};
					printf STDERR "%s ",$test[$_] for 0 .. $#test;
					printf STDERR "\n";
					printf STDERR "Number of molecules: %i\n",$test[$record{mol}] if $record{mol};
				}
				
				# Print min and max coordinates, only if one frame is being analysed.
				if ($mode{count} && $trj[0] != 0){
					# Find min-max coordinates.
					my @min=(1e10,1e10,1e10);
					my @max=(-1e10,-1e10,-1e10);
					for my $i(0 .. $#coord){
						for my $j(0 .. 2){
							$min[$j]=$coord[$i][$pos[0]+$j] if $coord[$i][$pos[0]+$j]<$min[$j];
							$max[$j]=$coord[$i][$pos[0]+$j] if $coord[$i][$pos[0]+$j]>$max[$j];
						}
					}
					printf "Current frame: %i\n",$fc;
					print "Coordinates:  MIN             MAX\n";
					printf "X %15g %15g\n",$min[0],$max[0];
					printf "Y %15g %15g\n",$min[1],$max[1];
					printf "Z %15g %15g\n",$min[2],$max[2];
				}
				
				# This line was skipped and must be reintroduced (only when saving the first and last frame).
				unshift(@header, "ITEM: TIMESTEP") if $frame > -1;
				@bb=&box(\@bb);
				my $atoms=&frame_save(\@header,\@bb,\@coord) if ($mode{save} && !$mode{count});
				&patch_polymer(\@header,\@bb,\@coord,\@ftype) if ($mode{polymer} && !$mode{count});
				&replica(\@header,\@bb,\@coord) if ($mode{supercell} && !$mode{count});
				# Patch the number of atoms, if a selection has been made.
				if ( !$mode{count} && ($mode{select}||$mode{delete}) ){
					close(OUT);
					system("sed -i '${noa}s/^$header[3]/$atoms/' $output");
					print STDERR "Executing: sed -i '${noa}s/^$header[3]/$atoms/' $output\n" if $mode{debug};
					open(OUT,">>$output");
					$noa+=$atoms+9;
				}
				# Post-processing.
				if ($mode{do} =~ /distance/i){
					my @test=&distance(\@bb,\@coord,\@ftype);
					push @distance, @test;
					@types=@ftype;
				}
				
				# Reset the frame storage arrays.
				undef @header;
				undef @bb;
				undef @coord;
				undef @ftype;
				
				# Break out the while loop if the job is done.
				last if ($trj[$#trj]==$fc || $frame==$timestep[$fc-1]) && (!$mode{count});
			}
		}
	}
	close(DUMP);
	close(OUT) if ($mode{save} || $mode{polymer} || $mode{supercell});
}

# Print stuff.
if ($mode{count}){
	printf "\nNumber of frames read: %i\n",$fc;
	printf "Timespan: %i-%i\n",$time[0],$time[1];
	my $df=$fc;
	$df=($timestep[$#timestep]-$timestep[0])/($fc-1) if $fc>1;
	printf "Dumping Frequency: %i\n",$df;
	printf "Atoms in the first frame: %i\n",$natm[0];
	printf "Atoms in the last frame:  %i\n",$natm[$#natm] if $fc>1;
}

# Print more stuff.
if ($mode{do}){
	my $output=$basename;
	$output=basename($input) if $basename eq "";
	$output =~ s/\.dump[\w]*+$//;
	$output .= ".postprocess";
	open(OUT,">$output");
	
	# Print the header.
	printf OUT "# Distance: ";
	my $c=0;
	for my $i(0 .. $#types){
		for my $j($i .. $#types){
			printf OUT "%i-%i ",$types[$i],$types[$j];
			$c++;
		}
	}
	$c--;
	printf OUT "\n";
	
	# Print the table.
	for my $i(0 .. $#distance){
		for my $j(0 .. $c){
			if ($distance[$i][$j] =~ /\d/){
				printf OUT "%8g ",$distance[$i][$j];
			} else {
				printf OUT "-%7s","";
			}
		}
		printf OUT "\n";
	}
	close(OUT);
}

# Merge two or more DUMP files.
if ($mode{merge}){
	my $output=$basename;
	my @header;
	my @bb;
	my @tcoord;
	
	if ($basename eq ""){
		$output .= basename($files[$_]) for 0 .. $#files;
		$output =~ s/\.dump[\w]*+$/_/g;
	}
	
	if ($mode{external}){
		$output .= ".dump";
	} else {
		$output .= "_merged.dump";
	}
	open(OUT,">$output");
	
	# Read all the input files and accumulate the different sections.
	# Each file should contain only one frame, otherwise the program will be sad :(
	for my $i(0 .. $#files){
		
		# Open the current file.
		open(DUMP,"<$files[$i]") || die "File $files[$i] not found.\n";
		my $go=1;
		my $box=0;
		my $natm=0;
		while(my $line=<DUMP>){
			# Store the header.
			if ($go){
				# Check that the number of recors does not change.
				if ($line =~ /^ITEM: ATOMS/){
					chomp $line;
					push @header, $line;
					$go=0;
				}
				
				# PBC vectors.
				push @bb,$line if ($box && $go);
				$box=1 if ($line =~ /^ITEM: BOX BOUNDS/);
			} else {
				# Stop reading after the first frame.
				if ($line =~ /^ITEM: TIMESTEP/){
					printf STDERR "WARNING: only the first frame of file %s was used.\n",$files[$i];
					last;
				}
				
				# Store the atoms section.
				my @data=&field($line);
				push @tcoord, \@data;
				$natm++;
				
				# Store the number of atom types in the current frame.
				@ftype=&unique(\@ftype,$data[$record{type}]) if $stype;
			}
		}
		
		# Sort the AoA containing the coordinates w.r.t. the index column.
		@tcoord = sort {$a->[0] <=> $b->[0]} @tcoord;
		push @coord, @tcoord;
		undef @tcoord;
		
		close(DUMP);
		push @natm_g, $natm;
		
		if ($stype){
			# Save the atom types into a unique sequence.
			@stype=&append(\@stype,\@ftype);
			push @tindex, $#ftype;
			
			# Reset the frame storage arrays.
			undef @ftype;
		}
	}
	
	# Check that the DUMP files were written with the same number of fields.
	for (1 .. $#header){
		printf STDERR "WARNING: ATOMS section of file %s has differ from %s\n",
		$files[$_],$files[0]  if $header[$_]!=$header[0];
	}
	if ($mode{debug} && $stype){
		printf STDERR "\nOutput atom types: ";
		printf STDERR "%i ",$stype[$_] for 0 .. $#stype;
		printf STDERR "\n";
	}
	
	# 1. Process the header.
	my $natm=0;
	$natm+=$natm_g[$_] for 0 .. $#natm_g;
	my $volume=0;
	my $prev=0;
	my $big=0;
	if ($mode{debug}){
		print STDERR "Bounding Boxes\n";
		printf STDERR "%i %s",$_,$bb[$_] for 0 .. $#bb;
		print STDERR "File  Volume\n";
	}
	
	# Find the biggest bounding box. (DISCARDED).
	#for my $i(0 .. $#files){
	#	my $j=$i*3;
	#	my @box;
	#	$box[$_]=$bb[$j+$_] for 0 .. 2;
	#	@box=&box(\@box);
	#	$volume=&volume(\@box);
	#	printf STDERR "%4i  %g\n",$i,$volume if $mode{debug};
	#	if ($volume>$prev){
	#		$prev=$volume;
	#		$big=$j;
	#	}
	#}
	my @header2=(
	"ITEM: TIMESTEP",
	0,
	"ITEM: NUMBER OF ATOMS",
	$natm,
	"ITEM: BOX BOUNDS pp pp pp"
	);
	my @bb2;
	#$bb2[$_]=$bb[$big+$_] for 0 .. 2;
	# Use the bounding box of the first DUMP file.
	$bb2[$_]=$bb[$_] for 0 .. 2;
	@bb2=&box(\@bb2);
	push @header2, "dummy" for 0 .. 2;
	push @header2, $header[0];
	
	# 2. Process the coordinates.
	my @coord2;
	if (!$stype){
		@coord2=&merge1(\@coord);
	} else {
		@coord2=&merge2(\@coord,\@stype,\@tindex,\@natm_g);
	}
	
	# 3. Write the output (easy!).
	&frame_save(\@header2,\@bb2,\@coord2);
	close(OUT);
}

# Let us know how slow perl is.
&endtime;

# Save the selected frame.
sub frame_save {
	# Dereference the input arrays.
	my @header=@{ $_[0] };
	my @bb=@{ $_[1] };
	my @coord=@{ $_[2] };
	
	# Print the header.
	printf OUT "%s\n",$header[$_] for 0 .. $#header-4;
	# Print the bounding box.
	&cm_format(\@bb);
	printf OUT "%s\n",$header[$#header];
	
	# Process the frame.
	my $next=0; # select the current molecule.
	my $old=$coord[0][$record{mol}]; # if the system  has holes in the molecule index, e.g. if the dump contains a selection of the whole system.
	my $aid=1;
	my $mid=1;
	my @coord2;
	for my $i(0 .. $#coord){
		# Dereference the AoA into a separate array.
		my @data=@{ $coord[$i] };
		$next++ if $molecule[$next+1] == $data[$record{mol}];
		
		# Perform additional operations on the coordinates.
		my $go=0;
		$go=1 if (!$record{mol} || $#molecule == -1 || $molecule[$next] == $data[$record{mol}]);
		if ($#operations>-1 && $go){
			my $op=($#operations+1)/4 - 1;
			my $rot=0; # Counter for rotations.
			for my $j(0 .. $op){
				my $start=4*$j;
				if ($operations[$start] eq "T"){
					# Translation.
					$data[ $pos[0]+$_ ] += $operations[$start+$_+1] for 0 .. 2;
				} else {
					# Rotation.
					@data=&rot_body(\@data,$rot);
					$rot++;
				}
			}
		}
		
		# Print the data.
		if (!$record{mol}){
			# simple wrap for single ellipsoids.
			@data=&wrap_single(\@data,\@bb) if $mode{wrap};
			
			# Expression Select.
			if ($mode{select}){
				my @v;
				$v[$_]=$data[$pos[0]+$_] for 0 .. 2;
				$v[3]=$data[$pos[2]];
				if (eval($expression)){
					printf OUT "%g ",$aid;
					printf OUT "%g ",$data[$_] for 1 .. $#data;
					print OUT "\n";
					$aid++;
				}
			} else {
				printf OUT "%g ",$aid;
				printf OUT "%g ",$data[$_] for 1 .. $#data;
				print OUT "\n";
				$aid++;
			}
		} elsif ($data[$record{mol}] != $old){
			# process the whole molecule.
			@coord2=&wrap(\@coord2,\@bb) if $mode{wrap};
			# Delete only selected molecules.
			my $check = 1;
			#$check = 0 if ($molecule[$next-1]==$old && $mode{delete} && $#molecule > -1 ); # Apparently is a bug.
			$check = 0 if ($molecule[$next]==$old && $mode{delete} && $#molecule > -1 );
			
			# Expression Select.
			if ($mode{select}){
				# Use the first ellipsoid for the expression selection.
				my @v;
				$v[$_]=$coord2[0][$pos[0]+$_] for 0 .. 2;
				$v[3]=$coord2[0][$pos[2]];
				if (eval($expression) && $check){
					#printf STDERR "Molecule selected: %s Position: %.2f %.2f %.2f\n",
					#$data[$record{mol}],$v[0],$v[1],$v[2] if ($mode{debug});
					for my $j(0 .. $#coord2){
						my @data2=@{ $coord2[$j] };
						
						# Overwrite the old molecular index with a sequential one.
						# Maybe there are cases where we want to keep the original ones:
						# if this necessity arises, make this substitution optional.
						$data2[$record{mol}]=$mid;
												
						printf OUT "%g ",$aid;
						printf OUT "%g ",$data2[$_] for 1 .. $#data2;
						print OUT "\n";
						$aid++;
					}
					$mid++;
				}
			} elsif($check) {
				for my $j(0 .. $#coord2){
					my @data2=@{ $coord2[$j] };
					printf OUT "%g ",$aid;
					printf OUT "%g ",$data2[$_] for 1 .. $#data2;
					print OUT "\n";
					$aid++;
				}
			}
			# Update the molecule.
			$old=$data[$record{mol}];
			undef @coord2;
		}
		
		# Store the molecule, if the record is present.
		push @coord2, \@data if $record{mol};
	}
	# Print the last molecule.
	@coord2=&wrap(\@coord2,\@bb) if $mode{wrap};
	# Delete only selected molecules.
	my $check = 1;
	$check = 0 if ($molecule[$next]==$old && $mode{delete} && $#molecule > -1 );
	
	# Expression Select.
	if ($mode{select} && $record{mol}){
		#  Use the first ellipsoid for the expression selection.
		my @v;
		$v[$_]=$coord2[0][$pos[0]+$_] for 0 .. 2;
		$v[3]=$coord2[0][$pos[2]];
		if (eval($expression) && $check){
			#printf STDERR "Molecule selected: %s\nPosition: %.2f %.2f %.2f\n",
			#$data[$record{mol}],$v[0],$v[1],$v[2] if ($mode{debug});
			for my $j(0 .. $#coord2){
				my @data2=@{ $coord2[$j] };
				$data2[$record{mol}]=$mid;
				printf OUT "%g ",$aid;
				printf OUT "%g ",$data2[$_] for 1 .. $#data2;
				print OUT "\n";
				$aid++;
			}
		}
	} elsif($check) {
		for my $j(0 .. $#coord2){
			my @data2=@{ $coord2[$j] };
			printf OUT "%g ",$aid;
			printf OUT "%g ",$data2[$_] for 1 .. $#data2;
			print OUT "\n";
			$aid++;
		}
	}
	$aid--;
	return $aid;
}

# Patch the atom types for a polymer.
sub patch_polymer {
	# Dereference the input arrays.
	my @header=@{ $_[0] };
	my @bb=@{ $_[1] };
	my @coord=@{ $_[2] };
	my @ftype=@{ $_[3] };
	my $aid=1;
	
	# Annoy the user if inconsistent options were selected :D
	print STDERR "WARNING: translations and rotations are not available in polymer-patch mode.\n" if $#operations>-1;
	print STDERR "WARNING: wrapping is not available in polymer-patch mode.\n" if $mode{wrap};
	print STDERR "WARNING: no fixing wrapped coordinates in polymer-patch mode!\n" if $mode{fix};
	
	# Determine the new atom types to be created.
	my $new=2;
	for my $i (0 .. $#type){
		$ntype[ $type[$i] ]{first}=$#ftype+$new;
		$new++;
		$ntype[ $type[$i] ]{last}=$#ftype+$new;
		$new++;
	}
	
	# Print a summary table
	print "***********************\n";
	print "* TYPE * FIRST * LAST *\n";
	print "***********************\n";
	printf "* %4i *  %4i * %4i *\n",
	$type[$_],$ntype[ $type[$_] ]{first},$ntype[ $type[$_] ]{last} for 0 .. $#type;
	print "***********************\n";
	
	# Print the header.
	printf OUT "%s\n",$header[$_] for 0 .. $#header-4;
	# Print the bounding box.
	&cm_format(\@bb);
	printf OUT "%s\n",$header[$#header];
	
	my $mol=0;
	for my $i(0 .. $#coord){
		my @data=@{ $coord[$i] };
		my @next=@{ $coord[$i+1] };
		
		# check when the molecule changes:
		my $go=&patch($data[$record{type}]);
		if ($mol ne $data[$record{mol}] && $go eq 1){
			# Patch the FIRST monomer of the polymer chain.
			$data[$record{type}]=$ntype[ $data[$record{type}] ]{first};
			$mol=$data[$record{mol}];
		} elsif ($mol ne $next[$record{mol}] && $go eq 1){
			# Patch the LAST monomer of the polymer chain.
			$data[$record{type}]=$ntype[ $data[$record{type}] ]{last};
		}
		
		# Print the line after modifications.
		printf OUT "%g ",$aid;
		printf OUT "%g ",$data[$_] for 1 .. $#data;
		print OUT "\n";
		$aid++;
	}
}

# Append new atom type to the current array.
sub append {
	# Dereference the input array.
	my @out=@{ $_[0] };
	my @inp=@{ $_[1] };
	my @tmp;
	my $last=$out[$#out];
	
	for my $i (0 .. $#inp){
		my $go=1;
		for my $j (0 .. $#out){
			$go=0 if $out[$j] == $inp[$i];
		}
		if ($go){
			push @tmp, $inp[$i];
		} else {
			$last++;
			push @tmp, $last;
		}
	}
	if ($mode{debug}){
		printf STDERR "Input types: ";
		printf STDERR "%i ",$out[$_] for 0 .. $#out;
		printf STDERR "\n";
		printf STDERR "Output types: ";
		printf STDERR "%i ",$tmp[$_] for 0 .. $#tmp;
		printf STDERR "\n";
	}
	push @out, @tmp;
	return @out;
}

# Merge the record ID and MOL.
sub merge1 {
	# Dereference the input array-of-arrays.
	my @coord=@{ $_[0] };
	
	# Process the frame.
	my $id=0;
	my $mol=0;
	my $old=-1;
	for my $i(0 .. $#coord){
		$id++;
		$coord[$i][ $record{id} ]=$id;
		if ($coord[$i][ $record{mol} ] != $old){
			$old=$coord[$i][ $record{mol} ];
			$mol++;
		}
		$coord[$i][ $record{mol} ]=$mol;
	}
	return @coord;
}

# Merge the record ID, TYPE, and MOL.
sub merge2 {
	# Dereference the input array-of-arrays.
	my @coord=@{ $_[0] };
	my @stype=@{ $_[1] };
	my @tindex=@{ $_[2] };
	my @natm=@{ $_[3] };
	
	# Process the frame.
	my $id=0;
	my $mol=0;
	my $old=-1;
	my $next=$natm[0]-1;
	my $d=0;
	my $shift=-1;
	for my $i(0 .. $#coord){
		$id++;
		$coord[$i][ $record{id} ]=$id;
		if ($coord[$i][ $record{mol} ] != $old){
			$old=$coord[$i][ $record{mol} ];
			$mol++;
		}
		$coord[$i][ $record{mol} ]=$mol;
		
		# Transform the old TYPE to the STYPE.
		if ($i>$next){
			$shift+=$tindex[$d]+1;
			$d++;
			$next+=$natm[$d];
			if ($mode{debug}){
				printf STDERR "line ";
				printf STDERR "%s ",$coord[$i][$_] for 0 .. $#item_atoms;
				printf STDERR "\n\n";
				printf STDERR "shift %i  next %i\n",$shift,$next;
			}
		}
		my $t=$coord[$i][ $record{type} ]+$shift;
		$coord[$i][ $record{type} ]=$stype[$t];
	}
	return @coord;
}

# Post-process: compute the distance for the current frame.
sub distance {
	# dereference the input array.
        my @bb=@{ $_[0] };
	my @coord=@{ $_[1] };
	my @ftype=@{ $_[2] };
	my @out;
	
	# Initialize the output table.
	my $c=0;
	my @index;
	my @tally;
	for my $i(0 .. $#ftype){
		for my $j($i .. $#ftype){
			$index[ $ftype[$i] ][ $ftype[$j] ]=$c;
			$index[ $ftype[$j] ][ $ftype[$i] ]=$c;
			$out[0][$c]=0;
			$tally[$c]=0;
			$c++;
		}
	}
	
	# Process the frame.
	for my $i(0 .. $#coord-1){
		for my $j($i+1 .. $#coord){
			my @data1=@{ $coord[$i] };
			my @data2=@{ $coord[$j] };
			my $type1=$data1[$record{type}];
			my $type2=$data2[$record{type}];
			my $c=$index[ $type1 ][ $type2 ];
			my $d=&dmic(\@data1,\@data2,\@bb);
			$out[ $tally[$c] ][$c]=$d;
			#print "DEBUG DISTANCE: $d INDEX $c T1 $type1 T2 $type2\n";
			$tally[$c]++;
		}
	}
	
	return @out;
}

# Split a string into an array
sub field {
	chomp $_[0];
	my @out = split /[\s\t]+/, $_[0];
	shift @out if $out[0] eq "";
	return @out;
}

# Grow the input array if a new value is found.
sub unique {
	# Dereference the input array.
	my @out=@{ $_[0] };
	my $index=$_[1];
	my $go=1;
	for my $i (0 .. $#out){
		$go=0 if $out[$i] == $index;
	}
	push @out, $index if $go;
	@out = sort {$a <=> $b} @out;
	return @out;
}

# Determine if the current atom type can be patched.
sub patch {
	my $out=0;
	for my $i (0 .. $#type){
		$out=1 if $type[$i] eq $_[0];
	}
	return $out;
}

# Print the execution time.
sub endtime {
	my $delta=localtime(time);
	# Time::Piece is installed.
	$delta-=$start;
	print "\nExecution time: ",$delta->pretty,"\n";
        # For system with basic Perl.
	#print "\nStart time: $start\n";
        #print "\nEnd time: $delta\n";
}

# Turn comma-separated input into a vector.
sub decomma {
	my @out;
	my @list = split /[,]+/, $_[0];
	foreach (@list){
		# Expand an interval, if specified with semi-column.
		if ($_ =~ /:/){
			my @int = split /[:]+/, $_;
			my $step=1;
			$step=$int[2] if $#int == 2;
			for (my $i=$int[0]; $i <= $int[1]; $i+=$step){
				push @out,$i;
			}
		} else {
			push @out,$_;
		}
	}
	return @out;
}

# Compute the distance between two points by applying the minimum image convention.
# Todo: check if it works equally well with wrapped and unwrapped coordinates.
sub dmic {
	# dereference the input array.
        my @p1=@{ $_[0] };
        my @p2=@{ $_[1] };
        my @bb=@{ $_[2] };
	
	# Translation vector.
	my @tr=(0,0,0);
	$tr[0]  =$bb[0][0];
	$tr[$_]+=$bb[1][$_] for 0 .. 1;
	$tr[$_]+=$bb[2][$_] for 0 .. 2;
	
	# The distance between two points cannot exceed half the lenth of the simulation box.
	my @dist;
	$dist[$_]=$p1[$pos[0]+$_]-$p2[$pos[0]+$_] for 0 .. 2;
	my @box;
	$box[$_]=sprintf("%.0f",$dist[$_]/$tr[$_]) for 0 .. 2;
	
	# Wrap the distance (minimum image convention).
	$dist[$_]-=$tr[$_]*$box[$_] for 0 .. 2;
	
	# Compute the distance.
	my $out=sqrt($dist[0]*$dist[0]+$dist[1]*$dist[1]+$dist[2]*$dist[2]);
	
	return $out;
}

# Wrap the coordinates of a single bead.
sub wrap_single {
	# dereference the input array.
        my @out=@{ $_[0] };
        my @bb=@{ $_[1] };
	
	# Translation vector.
	my @tr=(0,0,0);
	$tr[0]  =$bb[0][0];
	$tr[$_]+=$bb[1][$_] for 0 .. 1;
	$tr[$_]+=$bb[2][$_] for 0 .. 2;
	
	# Apply PBC.
	my @box;
	$box[$_]=sprintf("%.0f",$out[$pos[0]+$_]/$tr[$_]) for 0 .. 2;
	
	# Wrap the coordinates.
	$out[$pos[0]+$_]-=$tr[$_]*$box[$_] for 0 .. 2;
	
	return @out;
}

# Wrap the coordinates of a molecule.
sub wrap {
	# dereference the input array-of-arrays.
        my @out=@{ $_[0] };
        my @bb=@{ $_[1] };
	
	# Translation vector.
	my @tr=(0,0,0);
	$tr[0]  =$bb[0][0];
	$tr[$_]+=$bb[1][$_] for 0 .. 1;
	$tr[$_]+=$bb[2][$_] for 0 .. 2;
	if ($mode{debug}){
		printf STDERR "WRAP IN  ";
		printf STDERR "%10.3f ",$out[0][$pos[0]+$_] for 0 .. 2;
		printf STDERR "\n";
	}
	
	# Apply PBC.
	my @box1;
	if ($mode{fix}){
		# Use for the first ellipsoid (index 0) as reference, in case of broken molecules.
		$box1[$_]=sprintf("%.0f",$out[0][$pos[0]+$_]/$tr[$_]) for 0 .. 2;
	} else {
		# Use the geometrical centre of the molecule.
		my @com;
		for my $i(0 .. $#out){
			$com[$_]+=$out[$i][$pos[0]+$_] for 0 .. 2;
		}
		$com[$_]/=($#out+1) for 0 .. 2;
		$box1[$_]=sprintf("%.0f",$com[$_]/$tr[$_]) for 0 .. 2;
	}
	
	# Put the whole molecule on one side of the box.
	for my $i(0 .. $#out){
		#print STDERR "$out[$i][0] $out[$i][1] $out[$i][2]\n";
		
		# Check if the distance between each ellipsoid and ellipsoid(0) spans more than half the box.
		# It may break for molecules whose lenght is comparable in size with the bounding box. In
		# this case, change the box vectors with larger ones just to make the fix work.
		my @box2;	
		if ($mode{fix}){
			for my $j(0 .. 2){
				my $test=sprintf("%.0f",2*($out[$i][$pos[0]+$j]-$out[0][$pos[0]+$j])/$tr[$j]);
				if(abs($test) > 0){
					$box2[$j]=$test/2;
				} else {
					$box2[$j]=$box1[$j];
				}
			}
		} else {
			@box2=@box1;
		}
		
		# Wrap the coordinates.
		$out[$i][$pos[0]+$_]-=$tr[$_]*$box2[$_] for 0 .. 2;
		if ($mode{debug}){
			printf STDERR "WRAP OUT ";
			printf STDERR "%10.3f ",$out[$i][$pos[0]+$_] for 0 .. 2;
			printf STDERR "\n";
		}
	}
	return @out;
}

# Matrix multiplication: matrix, vector.
sub matmul {
	my @mat=@{ $_[0] };
	my @vinp=@{ $_[1] };
	my @vout=(0,0,0);
	for my $n(0 .. 2){
		$vout[$n] += $mat[$n][$_]*$vinp[$_] for 0 .. 2;
	}
	return @vout;
}

# Matrix x Matrix multiplication.
# http://rosettacode.org/wiki/Matrix_multiplication#Perl
sub mmult {
  our @a; local *a = shift;
  our @b; local *b = shift;
  my @p;
  my $rows = @a;
  my $cols = @{ $b[0] };
  my $n = @b - 1;
  for (my $r = 0 ; $r < $rows ; $r++){
      for (my $c = 0 ; $c < $cols ; $c++){
          $p[$r][$c] += $a[$r][$_] * $b[$_][$c] foreach 0 .. $n;
         }
     }
  return @p;
}

# Build a rotation matrix using an angle around an arbitrary axis.
# Adapted from moltemplate!
# formula from these sources:
# http://inside.mines.edu/~gmurray/ArbitraryAxisRotation/
# also check
# http://www.manpagez.com/man/3/glRotate/
sub rotmat {
	my @inp=@{ $_[0] }; # (angle,x,y,z)
	my $r=sqrt($inp[1]*$inp[1] + $inp[2]*$inp[2] + $inp[3]*$inp[3]);
	my @ax=(1,0,0);
	
	# check for non-sensical input.
	if ($r > 0.){
		$ax[$_]=$inp[$_+1]/$r for 0 .. 2;
	} else {
		$inp[0]=0.;
	}
	if ($mode{debug}){
		print  STDERR "Input axis of rotation: ";
		printf STDERR "%.3f ",$inp[$_+1] for 0 .. 2;
		print  STDERR "\n";
		print  STDERR "Normalised axis of rotation: ";
		printf STDERR "%.3f ",$ax[$_] for 0 .. 2;
		print  STDERR "\n";
	}
	
	$inp[0]*=$deg2rad;
	my $s=sin($inp[0]);
	my $c=cos($inp[0]);
	
	# Output matrix.
	my @rot;
	
	$rot[0][0]=$ax[0]*$ax[0]*(1-$c) + $c;
	$rot[0][1]=$ax[0]*$ax[1]*(1-$c) - $ax[2]*$s;
	$rot[0][2]=$ax[0]*$ax[2]*(1-$c) + $ax[1]*$s;
	
	$rot[1][0]=$ax[1]*$ax[0]*(1-$c) + $ax[2]*$s;
	$rot[1][1]=$ax[1]*$ax[1]*(1-$c) + $c;
	$rot[1][2]=$ax[1]*$ax[2]*(1-$c) - $ax[0]*$s;
	
	$rot[2][0]=$ax[2]*$ax[0]*(1-$c) - $ax[1]*$s;
	$rot[2][1]=$ax[2]*$ax[1]*(1-$c) + $ax[0]*$s;
	$rot[2][2]=$ax[2]*$ax[2]*(1-$c) + $c;
	
	if ($mode{debug}){
		print STDERR "Rotation Matrix: \n";
		printf STDERR "%6.3f %6.3f %6.3f\n",$rot[0][0],$rot[0][1],$rot[0][2];
		printf STDERR "%6.3f %6.3f %6.3f\n",$rot[1][0],$rot[1][1],$rot[1][2];
		printf STDERR "%6.3f %6.3f %6.3f\n",$rot[2][0],$rot[2][1],$rot[2][2];
	}
	return @rot;
}

# Compute a quaternion for a rotation of an angle around an arbitrary axis.
# http://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/index.htm
sub rotquat {
	my @inp=@{ $_[0] }; # (angle,x,y,z)
	my $r=sqrt($inp[1]*$inp[1] + $inp[2]*$inp[2] + $inp[3]*$inp[3]);
	my @ax=(1,0,0);
	
	# check for non-sensical input.
	if ($r > 0.){
		$ax[$_]=$inp[$_+1]/$r for 0 .. 2;
	} else {
		$inp[0]=0.;
	}
	
	$inp[0]*=$half2rad;
	my $s=sin($inp[0]);
	my $c=cos($inp[0]);
	my @q = (       $c,
	         $ax[0]*$s,
		 $ax[1]*$s,
		 $ax[2]*$s );
	return @q;
}

# Multiply 2 quaternions.
# https://en.wikipedia.org/wiki/Quaternion#Hamilton_product
sub multquat {
	my @q1=@{ $_[0] };
	my @q2=@{ $_[1] };
	my @out;
	$out[0] = $q1[0]*$q2[0] - $q1[1]*$q2[1] - $q1[2]*$q2[2] - $q1[3]*$q2[3];
	$out[1] = $q1[0]*$q2[1] + $q1[1]*$q2[0] + $q1[2]*$q2[3] - $q1[3]*$q2[2];
	$out[2] = $q1[0]*$q2[2] - $q1[1]*$q2[3] + $q1[2]*$q2[0] + $q1[3]*$q2[1];
	$out[3] = $q1[0]*$q2[3] + $q1[1]*$q2[2] - $q1[2]*$q2[1] + $q1[3]*$q2[0];
	return @out;
}

# Rotate the coordinates and orientation of a rigid body.
sub rot_body {
	my @data=@{ $_[0] };
	
	# 1. Extract the rotation matrix and quaternion from the global arrays.
	my @rm;
	my @rq;
	for my $i(0 .. 2){
		$rm[$i][$_]=$rm_g[$_[1]*3+$i][$_] for 0 .. 2;
	}
	$rq[$_]=$rq_g[$_[1]*4+$_] for 0 .. 3;
	
	# 2. Rotate the coordinates.
	my @tmp=($data[$pos[0]],$data[$pos[0]+1],$data[$pos[0]+2]);
	@tmp=&matmul(\@rm,\@tmp);
	$data[ $pos[0]+$_ ] = $tmp[$_] for 0 .. 2;
	
	# 3. Multiply the quaternions, if present.
	if ($pos[1]>-1){
		my @quat=($data[$pos_quat[0]],$data[$pos_quat[1]],$data[$pos_quat[2]],$data[$pos_quat[3]]);
		@quat=&multquat(\@rq,\@quat);
		$data[$pos_quat[$_ ]] = $quat[$_] for 0 .. 3;
	}
	
	return @data;
}

# Compute the Cartesian cell matrix.
# Dump parameters for triclinic boxes:
# $out[0][0] $out[0][1] $out[0][2] # xlo_bound xhi_bound xy
# $out[1][0] $out[1][1] $out[1][2] # ylo_bound yhi_bound xz
# $out[2][0] $out[2][1] $out[2][2] # zlo_bound zhi_bound yz
sub box {
	my @data=@{ $_[0] };
	my @out;
	for my $i (0 .. $#data){
		my @fields=&field($data[$i]);
		push @out, \@fields;
	}
	my @test=@{ $out[0] };
	my @box;
	for my $i (0 .. 2){
		$box[$i][$_]=0 for 0 .. 2;
	}
	if ($#test == 1){
		# Orthorombic.
		$box[$_][$_]=$out[$_][1]-$out[$_][0] for 0 .. 2;
		print STDERR "Orthorombic box:\n" if $mode{debug};
	} elsif ($#test == 2) {
		# Triclinic. Formulas from "How to Triclinic, LAMMPS manual.
		my @xtilt=(0, $out[0][2], $out[1][2], $out[0][2]+$out[1][2]);
		my @ytilt=(0, $out[2][2]);
		@xtilt = sort {$a <=> $b} @xtilt;
		@ytilt = sort {$a <=> $b} @ytilt;
		$box[0][0]=$out[0][1]-$out[0][0]+$xtilt[0]-$xtilt[3]; # xx
   		$box[1][0]=$out[0][2]; # xy
   		$box[1][1]=$out[1][1]-$out[1][0]+$ytilt[0]-$ytilt[1]; # yy
   		$box[2][0]=$out[1][2]; # xz
   		$box[2][1]=$out[2][2]; # yz
   		$box[2][2]=$out[2][1]-$out[2][0]; # zz
		print STDERR "Triclinic box:\n" if $mode{debug};
	} else {
		# This should never happen.
		print  STDERR "WARNING: incorrect cell vectors. Use a very large cubic cell.\n";
		print  STDERR "Offending line: ";
		printf STDERR "%g ",$test[$_] for 0 .. $#test;
		print  STDERR "\n";
		$box[$_][$_]=1e10 for 0 .. 2;
	}
	# Append the original bounding box to the Cartesian matrix.
	push @box, @out;
	if ($mode{debug}){
		printf STDERR "%8.3f ", $box[0][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%8.3f ", $box[1][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%8.3f ", $box[2][$_] for 0 .. 2;
		print  STDERR "\n";
	}
	return @box;
}

# Compute the volume of the simulation box using the Cartesian matrix.
sub volume {
	my @data=@{ $_[0] };
	my $volume=$data[0][0]*$data[1][1]*$data[2][2];
	
	# Triclinic cell. Formulas from "How to Triclinic, LAMMPS manual.
	my $test=abs($data[1][0])+abs($data[2][0])+abs($data[2][1]);
	if ($test> $tol){
		my $b=sqrt($data[1][0]*$data[1][0]+$data[1][1]*$data[1][1]);
		my $c=sqrt($data[2][0]*$data[2][0]+$data[2][1]*$data[2][1]+$data[2][2]*$data[2][2]);
		my $calpha=($data[1][0]*$data[2][0] + $data[1][1]*$data[2][1])/$b/$c;
		my $cbeta=$data[2][0]/$c;
		my $cgamma=$data[1][0]/$b;
		$volume*=sqrt( 1.-$calpha*$calpha-$cbeta*$cbeta-$cgamma*$cgamma+2.*$calpha*$cbeta*$cgamma);
	}
	return $volume;
}

# Format the Cartesian matrix to the bounding box.
sub cm_format {
	my @bb=@{ $_[0] };
	
	# Rotate the cell box (NOT WORKING, deactivated for now).
	if ($#operations>-1 && $go){
		my $op=($#operations+1)/4 - 1;
		my $rot=0; # Counter for rotations.
		my @rm;
		my @bb2;
		for my $i(0 .. 2){
			$bb2[$i][$_]=$bb[$i][$_] for 0 .. 2;
		}
		if ($mode{debug}){
			print STDERR "BB before rotation.\n";
			print STDERR "$bb2[0][0] $bb2[0][1] $bb2[0][2]\n";
			print STDERR "$bb2[1][0] $bb2[1][1] $bb2[1][2]\n";
			print STDERR "$bb2[2][0] $bb2[2][1] $bb2[2][2]\n";
		}
		for my $j(0 .. $op){
			my $start=4*$j;
			if ($operations[$start] ne "T"){
				# Rotation matrix.
				for my $i(0 .. 2){
					$rm[$i][$_]=$rm_g[$rot*4+$i][$_] for 0 .. 2;
				}
				@bb2=&mmult(\@rm,\@bb2);
				$rot++;
			}
		}
		if ($mode{debug}){
			print STDERR "BB after rotation(s).\n";
			print STDERR "$bb2[0][0] $bb2[0][1] $bb2[0][2]\n";
			print STDERR "$bb2[1][0] $bb2[1][1] $bb2[1][2]\n";
			print STDERR "$bb2[2][0] $bb2[2][1] $bb2[2][2]\n";
		}
		# Update the bounding box.
		for my $i(0 .. 2){
			$bb[$i][$_]=$bb2[$i][$_] for 0 .. 2;
		}
	}
	
	my $test=abs($bb[1][0])+abs($bb[2][0])+abs($bb[2][1]);
	if(!$mode{wrap} && !$mode{supercell}){ # && $#operations==-1
		# Use the bounding box as is.
		if ($test> $tol){
			# Triclinic.
			printf OUT "%g %g %g\n",$bb[$_][0],$bb[$_][1],$bb[$_][2] for 3 .. 5;
			print  STDERR "Triclinic no wrap\n" if $mode{debug};
		} else {
			# Orthorombic.
			printf OUT "%g %g\n",$bb[$_][0],$bb[$_][1] for 3 .. 5;
			print  STDERR "Orthorombic no wrap\n" if $mode{debug};
		}
	} else {
		# Center the bounding box.
		if ($test> $tol){
			# Triclinic.
			my @xtilt=(0, $bb[1][0], $bb[2][0], $bb[1][0]+$bb[2][0]); # 0, xy, xz, xy+xz
			my @ytilt=(0, $bb[2][1]); # 0, yz
			@xtilt = sort {$a <=> $b} @xtilt;
			@ytilt = sort {$a <=> $b} @ytilt;
			printf OUT "%g %g %g\n",-$bb[0][0]/2+$xtilt[0],$bb[0][0]/2+$xtilt[3],$bb[1][0];
			printf OUT "%g %g %g\n",-$bb[1][1]/2+$ytilt[0],$bb[1][1]/2+$ytilt[1],$bb[2][0];
			printf OUT "%g %g %g\n",-$bb[2][2]/2,$bb[2][2]/2,$bb[2][1];
			print  STDERR "Triclinic wrap\n" if $mode{debug};
		} else {
			# Orthorombic.
			printf OUT "%g %g\n",-$bb[$_][$_]/2,$bb[$_][$_]/2 for 0 .. 2;
			print  STDERR "Orthorombic wrap\n" if $mode{debug};
		}
	}
}

# Replicate and save the selected frame.
sub replica {
	# Dereference the input arrays.
	my @header=@{ $_[0] };
	my @bb=@{ $_[1] };
	my @coord=@{ $_[2] };
	my $aid=1;
	
	# Print the header.
	printf OUT "%s\n",$header[$_] for 0 .. 2;
	printf OUT "%i\n",$header[3]*($replica[0]+1)*($replica[1]+1)*($replica[2]+1);
	printf OUT "%s\n",$header[4];
	
	# Replicate the box.
	my @bb2;
	$bb2[0][0]=$bb[0][0]*($replica[0]+1);
	$bb2[1][$_]=$bb[1][$_]*($replica[1]+1) for 0 .. 1;
	$bb2[2][$_]=$bb[2][$_]*($replica[2]+1) for 0 .. 2;
	if ($mode{debug}){
		print  STDERR "Original Bounding Box:\n";
		printf STDERR "%.3f ", $bb[0][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%.3f ", $bb[1][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%.3f ", $bb[2][$_] for 0 .. 2;
		print  STDERR "\n";
		print  STDERR "Replicated Bounding Box:\n";
		printf STDERR "%.3f ", $bb2[0][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%.3f ", $bb2[1][$_] for 0 .. 2;
		print  STDERR "\n";
		printf STDERR "%.3f ", $bb2[2][$_] for 0 .. 2;
		print  STDERR "\n";
	}
	
	# Print the bounding box.
	&cm_format(\@bb2);
	printf OUT "%s\n",$header[$#header];
	
	# Process the frame.
	my @data=@{ $coord[$#data] };
	my $mol=$data[$record{mol}]; # Total number of molecules.
	my $mol_rep=0;
	undef @data;
	my $count=0;
	for my $nx(0 .. $replica[0]){
		for my $ny(0 .. $replica[1]){
			for my $nz(0 .. $replica[2]){
				
				# Translation vector.
				my @tr=(0,0,0);
				$tr[0] +=$bb[0][0]*$nx;
				$tr[$_]+=$bb[1][$_]*$ny for 0 .. 1;
				$tr[$_]+=$bb[2][$_]*$nz for 0 .. 2;
				
				# Replicate the coordinates.
				for my $i(0 .. $#coord){
					# Dereference the AoA into a separate array.
					my @data=@{ $coord[$i] };
					
					# Update atom ID.
					$count++;
					$data[0]=$count;
					
					# Update molecule ID.
					$data[$record{mol}]+=$mol_rep if $record{mol};
					
					# Update the position.
					$data[$pos[0]+$_]+=$tr[$_] for 0 .. 2;
					
					# Print the data.
					printf OUT "%g ",$aid;
					printf OUT "%g ",$data[$_] for 1 .. $#data;
					print OUT "\n";
					$aid++;
				}
				$mol_rep+=$mol;
			}
		}
	}
}
