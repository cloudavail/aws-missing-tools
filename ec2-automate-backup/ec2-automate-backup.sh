#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2012-09-14
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
#confirms that executables required for succesful script execution are available
prerequisite_check()
{
	for prerequisite in basename ec2-create-snapshot
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use `basename $0`, the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

#get_EBS_List gets a list of available EBS instances depending upon the selection_method of EBS selection that is provided by user input
get_EBS_list()
{
	case $selection_method in
		volumeid)
			if [[ -z $volumeid ]]
				then echo "The selection method \"volumeid\" (which is $app_name's default selection_method of operation or requested by using the -s volumeid parameter) requires a volumeid (-v volumeid) for operation. Correct usage is as follows: \"-v vol-6d6a0527\",\"-s volumeid -v vol-6d6a0527\" or \"-v \"vol-6d6a0527 vol-636a0112\"\" if multiple volumes are to be selected." 1>&2 ; exit 64
			fi
			ebs_selection_string="$volumeid"
			;;
		tag) 
			if [[ -z $tag ]]
				then echo "The selected selection_method \"tag\" (-s tag) requires a valid tag (-t key=value) for operation. Correct usage is as follows: \"-s tag -t backup=true\" or \"-s tag -t Name=my_ebs_volume.\"" 1>&2 ; exit 64
			fi
			ebs_selection_string="--filter tag:$tag"
			;;
		*) echo "If you specify a selection_method (-s selection_method) for selecting EBS volumes you must select either \"volumeid\" (-s volumeid) or \"tag\" (-s tag)." 1>&2 ; exit 64 ;;
	esac
	#creates a list of all ebs volumes that match the selection string from above
	ebs_backup_list_complete=`ec2-describe-volumes --show-empty-fields --region $region $ebs_selection_string 2>&1`
	#takes the output of the previous command 
	ebs_backup_list_result=`echo $?`
	if [[ $ebs_backup_list_result -gt 0 ]]
		then echo -e "An error occured when running ec2-describe-volumes. The error returned is below:\n$ebs_backup_list_complete" 1>&2 ; exit 70
	fi
	ebs_backup_list=`echo "$ebs_backup_list_complete" | grep ^VOLUME | cut -f 2`
	#code to right will output list of EBS volumes to be backed up: echo -e "Now outputting ebs_backup_list:\n$ebs_backup_list"
}

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisite_check

app_name=`basename $0`

#sets defaults
selection_method="volumeid"
region="us-east-1"
#sets date variable
date_current=`date -u +%Y-%m-%d`
#sets the "Name" tag set for a snapshot to false - using "Name" requires that ec2-create-tags be called in addition to ec2-create-snapshot
name_tag_set=false

#handles options processing
while getopts :s:r:v:t:n opt
	do
		case $opt in
			s) selection_method="$OPTARG";;
			r) region="$OPTARG";;
			v) volumeid="$OPTARG";;
			t) tag="$OPTARG";;
			n) name_tag_set=true;;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#get_EBS_List gets a list of EBS instances for which a snapshot is desired. The list of EBS instances depends upon the selection_method that is provided by user input
get_EBS_list

#the loop below is called once for each volume in $ebs_backup_list - the currently selected EBS volume is passed in as "ebs_selected"
for ebs_selected in $ebs_backup_list
do
	ec2_snapshot_description="ec2ab_${ebs_selected}_$date_current"
	ec2_create_snapshot_result=`ec2-create-snapshot --region $region -d $ec2_snapshot_description $ebs_selected 2>&1`
	if [[ $? != 0 ]]
		then echo -e "An error occured when running ec2-create-snapshot. The error returned is below:\n$ec2_create_snapshot_result" 1>&2 ; exit 70
	elif $name_tag_set
		then
		ec2_snapshot_resource_id=`echo "$ec2_create_snapshot_result" | cut -f 2`
		ec2-create-tags $ec2_snapshot_resource_id --region $region --tag Name=$ec2_snapshot_description
	fi
done