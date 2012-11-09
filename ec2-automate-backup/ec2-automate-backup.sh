#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2012-09-24
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
#confirms that executables required for succesful script execution are available
prerequisite_check()
{
	for prerequisite in basename ec2-create-snapshot ec2-create-tags ec2-describe-snapshots ec2-delete-snapshot date
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use `basename $0`, the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

#get_EBS_List gets a list of available EBS instances depending upon the selection_method of EBS selection that is provided by user input
get_EBS_List()
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
				then echo "The selected selection_method \"tag\" (-s tag) requires a valid tag (-t key=value) for operation. Correct usage is as follows: \"-s tag -t backup=true\" or \"-s tag -t Name=my_tag.\"" 1>&2 ; exit 64
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

create_EBS_Snapshot_Tags()
{
	#snapshot tags holds all tags that need to be applied to a given snapshot - by aggregating tags we ensure that ec2-create-tags is called only onece
	snapshot_tags=""
	#if $name_tag_create is true then append ec2ab_${ebs_selected}_$date_current to the variable $snapshot_tags
	if $name_tag_create
		then
		ec2_snapshot_resource_id=`echo "$ec2_create_snapshot_result" | cut -f 2`
		snapshot_tags="$snapshot_tags --tag Name=ec2ab_${ebs_selected}_$date_current"
	fi
	#if $purge_after_days is true, then append $purge_after_date to the variable $snapshot_tags
	if [[ -n $purge_after_days ]]
		then
		snapshot_tags="$snapshot_tags --tag PurgeAfter=$purge_after_date --tag PurgeAllow=true"
	fi
	#if $snapshot_tags is not zero length then set the tag on the snapshot using ec2-create-tags
	if [[ -n $snapshot_tags ]]
		then echo "Tagging Snapshot $ec2_snapshot_resource_id with the following Tags:"
		ec2-create-tags $ec2_snapshot_resource_id --region $region $snapshot_tags
	fi
}

date_command_get()
{
	#finds full path to date binary
	date_binary_full_path=`which date`
	#command below is used to determine if date binary is gnu, macosx or other
	date_binary_file_result=`file -b $date_binary_full_path`
	case $date_binary_file_result in
		"Mach-O 64-bit executable x86_64") date_binary="macosx" ;;
		"ELF 64-bit LSB executable, x86-64, version 1 (SYSV)"*) date_binary="gnu" ;;
		*) date_binary="unknown" ;;
	esac
	#based on the installed date binary the case statement below will determine the method to use to determine "purge_after_days" in the future
	case $date_binary in
		gnu) date_command="date -d +${purge_after_days}days -u +%Y-%m-%d" ;;
		macosx) date_command="date -v+${purge_after_days}d -u +%Y-%m-%d" ;;
		unknown) date_command="date -d +${purge_after_days}days -u +%Y-%m-%d" ;;
		*) date_command="date -d +${purge_after_days}days -u +%Y-%m-%d" ;;
	esac
}

purge_EBS_Snapshots()
{
	#snapshot_tag_list is a string that contains all snapshots with either the key PurgeAllow or PurgeAfter set
	snapshot_tag_list=`ec2-describe-tags --show-empty-fields --region $region --filter resource-type=snapshot --filter key=PurgeAllow,PurgeAfter`
	#snapshot_purge_allowed is a list of all snapshot_ids with PurgeAllow=true
	snapshot_purge_allowed=`echo "$snapshot_tag_list" | grep .*PurgeAllow'\s'true | cut -f 3`
	
	for snapshot_id_evaluated in $snapshot_purge_allowed
	do
		#gets the "PurgeAfter" date which is in UTC with YYYY-MM-DD format (or %Y-%m-%d)
		purge_after_date=`echo "$snapshot_tag_list" | grep .*$snapshot_id_evaluated'\t'PurgeAfter.* | cut -f 5`
		#if purge_after_date is not set then we have a problem. Need to alter user.
		if [[ -z $purge_after_date ]]
			#Alerts user to the fact that a Snapshot was found with PurgeAllow=true but with no PurgeAfter date.
			then echo "A Snapshot with the Snapshot ID $snapshot_id_evaluated has the tag \"PurgeAllow=true\" but does not have a \"PurgeAfter=YYYY-MM-DD\" date. $app_name is unable to determine if $snapshot_id_evaluated should be purged." 1>&2
		else
			#convert both the date_current and purge_after_date into epoch time to allow for comparison
			date_current_epoch=`date -j -f "%Y-%m-%d" "$date_current" "+%s"`
			purge_after_date_epoch=`date -j -f "%Y-%m-%d" "$purge_after_date" "+%s"`
			#perform compparison - if $purge_after_date_epoch is a lower number than $date_current_epoch than the PurgeAfter date is earlier than the current date - and the snapshot can be safely removed
			if [[ $purge_after_date_epoch < $date_current_epoch ]]
				then
				echo "The snapshot \"$snapshot_id_evaluated\" with the Purge After date of $purge_after_date will be deleted."
				ec2-delete-snapshot --region $region $snapshot_id_evaluated
			fi
		fi
	done
}

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisite_check

app_name=`basename $0`

#sets defaults
selection_method="volumeid"
region="us-east-1"
#date_binary allows a user to set the "date" binary that is installed on their system and, therefore, the options that will be given to the date binary to perform date calculations
date_binary=""

#sets the "Name" tag set for a snapshot to false - using "Name" requires that ec2-create-tags be called in addition to ec2-create-snapshot
name_tag_create=false
#sets the Purge Snapshot feature to false - this feature will eventually allow the removal of snapshots that have a "PurgeAfter" tag that is earlier than current date
purge_snapshots=false
#handles options processing
while getopts :s:r:v:t:k:pn opt
	do
		case $opt in
			s) selection_method="$OPTARG";;
			r) region="$OPTARG";;
			v) volumeid="$OPTARG";;
			t) tag="$OPTARG";;
			k) purge_after_days="$OPTARG";;
			n) name_tag_create=true;;
			p) purge_snapshots=true;;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#sets date variable
date_current=`date -u +%Y-%m-%d`
#sets the PurgeAfter tag to the number of days that a snapshot should be retained
if [[ -n $purge_after_days ]]
	then
	#if the date_binary is not set, call the date_command_get function
	if [[ -z $date_binary ]]
		then date_command_get
	fi
	purge_after_date=`$date_command`
	echo "Snapshots taken by $app_name will be eligible for purging after the following date: $purge_after_date."
fi

#get_EBS_List gets a list of EBS instances for which a snapshot is desired. The list of EBS instances depends upon the selection_method that is provided by user input
get_EBS_List

#the loop below is called once for each volume in $ebs_backup_list - the currently selected EBS volume is passed in as "ebs_selected"
for ebs_selected in $ebs_backup_list
do
	ec2_snapshot_description="ec2ab_${ebs_selected}_$date_current"
	ec2_create_snapshot_result=`ec2-create-snapshot --region $region -d $ec2_snapshot_description $ebs_selected 2>&1`
	if [[ $? != 0 ]]
		then echo -e "An error occured when running ec2-create-snapshot. The error returned is below:\n$ec2_create_snapshot_result" 1>&2 ; exit 70
	else
		ec2_snapshot_resource_id=`echo "$ec2_create_snapshot_result" | cut -f 2`
	fi	
	create_EBS_Snapshot_Tags
done

#if purge_snapshots is true, then run purge_EBS_Snapshots function
if $purge_snapshots
	then echo "Snapshot Purging is Starting Now."
	purge_EBS_Snapshots
fi