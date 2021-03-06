#!/bin/bash

#Read in param path and make absolute, then shift for optargs
paramPath="$1"
shift

setting="custom"
date=`date +%Y-%m-%d-T%H-%M-%S`
walltime=12:00:00
memory=12g
outfile="Jobname.o"
repeats=1
nMC=1
model=${PWD##*/}
basePath=$PWD
jobname=""
folderName=""
sweepDefs=""
sweepfile=""
rows=""
num_cores=1
forceFlag=""
savePop=""
popPath=""

while getopts m:j:T:S:r:n:f:w:W:R:Fc:p:P: option
do
    case "${option}"
        in
	m) memory=${OPTARG};;
	j) jobname=${OPTARG};;
	T) walltime=${OPTARG};;
	S) setting=${OPTARG};;
	r) repeats=${OPTARG};;
	n) nMC=${OPTARG};;
	f) folderName=${OPTARG};;
	w) sweepDefs+="-w ${OPTARG} ";;
	W) sweepfile="-W ${OPTARG}";;
	R) rows="-r ${OPTARG}";;
	F) forceFlag="-F";;
	c) num_cores=${OPTARG};;
	p) savePop="--savepop";;
	P) popPath="--poppath ${OPTARG}";;
    esac
done

if [[ $jobname == "" ]]; then
	jobname="Analysis_$setting_$date"
fi

if [[ $folderName == "" ]]; then
	folderName="$setting"
fi

outPath="$HOME/scratch/$folderName"

usage() {
echo "
usage: ./subTitan.sh {Parameter file or directory} [-T walltime] [-m memory] [-S setting] [-j jobname] [-r repeats] [-n iterations] [-b use_base] [-f folder_name] [-w sweep_defs] [-F force] [-c num_cores ]

Starts a TITAN simulation in ~/scratch/{SourceFolder}/{jobname}

options:
  -j jobname	  name of analysis for organization (default: {SourceFolder}_date)
  -T walltime     as hh:mm:ss, max compute time (default: $walltime)
  -m memory       per node, as #[k|m|g] (default: $memory)
  -S setting      name of setting for this model
  -r repeats      number of times to repeat the analysis (default: $repeats)
  -n iterations   number of mode iterations per job (default: $nMC)
  -f folder_name  What the parent folder for the model run outputs should be called (default: <setting>)
  -w sweep_defs   Optionally, definitions of sweep parameters in the format param:start:stop[:step]
  -W sweepfile    Optionally, a csv file with sweep definitions (if used, -w flag is ignored)
  -R rows         Optionally, which data rows of the sweep file to use in format start:stop
  -F force	  If the number of sweep combinations exceeds 100, run anyway
  -c num_cores	  How many cores to request and run the job on (default: $num_cores)
  -p savePop	  Save the population (by default, does not save the population)
  -P popPath	  Load population from the provided path (by default, creates a new population)
"
exit 0
}

# if no commands, print help
if [ ! $paramPath ]; then
    usage;
		exit 0;
fi

prepSubmit() {
    #Move into output folder
		mkdir -p $finalPath
    echo -e "\t$finalPath"

    #Submit job to cluster
    sbatch --output=$finalPath/slurm.out -J $jobname -t $walltime --mem=$memory -c $num_cores --mail-type=FAIL --mail-type=END --mail-user=NoMail $HOME/.local/bin/run_titan -S $setting -p $paramPath -n $nMC $forceFlag $sweepDefs $sweepfile $rows $savePop $popPath -o $finalPath/results

    #Move back to base directory
    cd $basePath
}

if [ -d $outPath/$jobname ]; then
    echo -e "\n\n!! WARNING !!\nThe folder $jobname already exists and will be OVERWRITTEN!\n"
    read -p "Continue (y/n)?" choice
    case "$choice" in
      y|Y ) echo "Proceeding";;
      n|N|* ) echo "Aborting"
	    exit 0;;
    esac
fi

echo "
    jobname     $jobname
    outPath     $outPath
    paramPath   $paramPath
    user        $USER
    date        $date
    walltime    $walltime
    memory      $memory
    outfile     $outfile
    model       $model"
echo -e "\n"

echo -e "\tMaking parent directory in scratch"
mkdir -p $outPath
echo -e "\t $outPath"

if [ $repeats -gt 1 ]; then
    # mkdir -p $outPath$jobname
    basejobname=$jobname
    for ((i=1; i<=repeats; i++)); do
        echo -e "\n\nWorking on repeat $i"
        jobname=$basejobname"_"$i
        finalPath=$outPath"/"$basejobname"/"$jobname
        prepSubmit;
    done
else
    finalPath=$outPath"/"$jobname
    prepSubmit;
fi
