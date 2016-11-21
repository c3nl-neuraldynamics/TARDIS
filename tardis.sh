#!/bin/sh

usage() {
    cat <<EOF

tardis.sh v0.1 (beta)

Usage: tardis <window> <anchors.txt> <output_directory> <input1> <input2> <input3> ...
e.g.   tardis.sh 10 anchors.txt standard_filtered_func1.nii.gz output standard_filtered_func2.nii.gz

<window>                      Length of time window (in volumes)
<anchors.txt>                 Anchor point file   
<output_directory>            This directory will be created to hold all output 
<input1> <input2> ...         List of all individuals' (preprocessed, standard-space) 4D datasets

EOF
    exit 1
}

echoandrun() { 
	echo ${*} 
	eval ${*}
}

############################################################################

[ "$#" -lt 4 ] && usage

LengthWindow=$1; shift
AnchorFileName=$1; shift
OutputDir=$1; shift



while [ -d "${OutputDir}" ]
do	
	OutputDir="${OutputDir}+";
done
mkdir -p ${OutputDir}/tempvols;
mkdir -p ${OutputDir}/tempsamples;

echo "created output directory (${OutputDir})";
 
echo "processing $(($#)) input/s"
n=1;
while [ $# -ge 1 ]
do
  	echo "$((n)) $1";
	
	InputData=`${FSLDIR}/bin/remove_ext $1`; 
	SampleFile="recoded_`printf %04d $((n))`";
	
	rm -f ${OutputDir}/temp*/* # wipe temporary images
	
	# split the input data into separate volumes 
	${FSLDIR}/bin/fslsplit $InputData ${OutputDir}/tempvols/ -t
	
	AnchorTimePoints=$(<$AnchorFileName)
	for TP in $AnchorTimePoints;
	do
		# make a list of volumes to extract 
		cat /dev/null > ${OutputDir}/temptimes.txt;

		for ((i=$TP - 1; i < $TP+$LengthWindow -1 ; i++))
		do
			printf "${OutputDir}/tempvols/%04d " $i >> ${OutputDir}/temptimes.txt;
		done;
		
		# spatially concatenate the volumes into a numbered sample
		ConcatFile="tempsamples/`printf %04d $TP`";
		${FSLDIR}/bin/fslmerge -x ${OutputDir}/${ConcatFile} `cat ${OutputDir}/temptimes.txt`
	done;
	
	# temporally merge the individual's samples
	${FSLDIR}/bin/fslmerge -t ${OutputDir}/${SampleFile} ${OutputDir}/tempsamples/*;
	
	# demean the individual's volumes
	${FSLDIR}/bin/fslmaths ${OutputDir}/${SampleFile} -Tmean ${OutputDir}/tempmean
	${FSLDIR}/bin/fslmaths ${OutputDir}/${SampleFile} -sub ${OutputDir}/tempmean ${OutputDir}/${SampleFile}
	
	shift
	n=$(( $n + 1 ));
done;

rm -fr ${OutputDir}/temp* # wipe temporary files

echo "temporally concatenating all samples";
${FSLDIR}/bin/fslmerge -t ${OutputDir}/recoded_all ${OutputDir}/recoded_*;

echo "run melodic on concatenated samples";
echo "melodic -i ${OutputDir}/recoded_all -o ${OutputDir}/recoded_all.ica -v --nobet --report --dim=20 --mmthresh=0.5";


