#!/bin/bash
 
#SBATCH --cpus-per-task=12
#SBATCH -t 0-12:00                  # wall time (D-HH:MM)
##SBATCH -A fzhang59                 # Account hours will be pulled from (commented out with double # in front)
#SBATCH -o slurm.%j.out             # STDOUT (%j = JobId)
#SBATCH -e slurm.%j.err             # STDERR (%j = JobId)
#SBATCH --mail-type=ALL             # Send a notification when the job starts, stops, or fails
#SBATCH --mail-user=fzhang59@asu.edu # send-to address

module load rstudio/1.1.423
srun Rscript Agave_76to100Reps_noLimitCores.R
date
