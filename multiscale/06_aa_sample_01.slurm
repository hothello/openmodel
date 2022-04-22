#!/bin/bash
#
# Parallel script produced by bolt
#        Resource: ARCHER2 (HPE Cray EX (128-core per node))
#    Batch system: Slurm
#
# bolt is written by EPCC (http://www.epcc.ed.ac.uk)
#
#SBATCH --nodes=10
#SBATCH --tasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --job-name=pla01
#SBATCH --account=pr1ush02
#SBATCH --partition=standard
#SBATCH --qos=standard
#SBATCH --time=24:0:0

# Input file
inp=06_aa_sample_01.in

# Run the parallel program
module swap PrgEnv-cray PrgEnv-gnu
module load cray-fftw
export OMP_NUM_THREADS=1
lmp=/work/pr1ush02/pr1ush02/shared/bin/lmp_archer2b
srun --distribution=block:block --hint=nomultithread ${lmp} -in $inp 



