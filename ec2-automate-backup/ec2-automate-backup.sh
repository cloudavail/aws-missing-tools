#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-02-13
# Version 0.9
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
	#if $hostname_tag_create is true then append --tag InitiatingHost=`hostname -f` to the variable $snapshot_tags
	if $hostname_tag_create
		then
		ec2_snapshot_resource_id=`echo "$ec2_create_snapshot_result" | cut -f 2`
		snapshot_tags="$snapshot_tags --tag InitiatingHost='`hostname -f`'"
	fi
	#if $purge_after_days is true, then append $purge_after_date to the variable $snapshot_tags
	if [[ -n $purge_after_days ]]
		then
		snapshot_tags="$snapshot_tags --tag PurgeAfter=$purge_after_date --tag PurgeAllow=true"
	fi

	#if $user_tags is true, then append Volume=$ebs_selected and Created=$current_date to the variable $snapshot_tags
	if $user_tags
		then
		snapshot_tags="$snapshot_tags --tag Volume=${ebs_selected} --tag Created=$date_current"
	fi

	#if $snapshot_tags is not zero length then set the tag on the snapshot using ec2-create-tags
	if [[ -n $snapshot_tags ]]
		then echo "Tagging Snapshot $ec2_snapshot_resource_id with the following Tags:"
		ec2-create-tags $ec2_snapshot_resource_id --region $region $snapshot_tags
	fi
}

date_binary_get()
{
	#`uname -o (operating system) would be ideal, but OS X / Darwin does not support to -o option`
	#`uname` on OS X defaults to `uname -s` and `uname` on GNU/Linux defaults to `uname -s`
	uname_result=`uname`
	case $uname_result in
		Darwin) date_binary="osx-posix" ;;
		Linux) date_binary="linux-gnu" ;;
		*) date_binary="unknown" ;;
	esac
}

get_purge_after_date()
{
#based on the date_binary variable, the case statement below will determine the method to use to determine "purge_after_days" in the future
case $date_binary in
	linux-gnu) echo `date -d +${purge_after_days}days -u +%Y-%m-%d` ;;
	osx-posix) echo `date -v+${purge_after_days}d -u +%Y-%m-%d` ;;
	*) echo `date -d +${purge_after_days}days -u +%Y-%m-%d` ;;
esac
}

get_purge_after_date_epoch()
{
#based on the date_binary variable, the case statement below will determine the method to use to determine "purge_after_date_epoch" in the future
case $date_binary in
	linux-gnu) echo `date -d $purge_after_date +%s` ;;
	osx-posix) echo `date -j -f "%Y-%m-%d" $purge_after_date "+%s"` ;;
	*) echo `date -d $purge_after_date +%s` ;;
esac
}

get_date_current_epoch()
{
#based on the date_binary variable, the case statement below will determine the method to use to determine "date_current_epoch" in the future
case $date_binary in
	linux-gnu) echo `date -d $date_current +%s` ;;
	osx-posix) echo `date -j -f "%Y-%m-%d" $date_current "+%s"` ;;
	*) echo `date -d $date_current +%s` ;;
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
		purge_after_date=`echo "$snapshot_tag_list" | grep .*$snapshot_id_evaluated'\s'PurgeAfter.* | cut -f 5`
		#if purge_after_date is not set then we have a problem. Need to alert user.
		if [[ -z $purge_after_date ]]
			#Alerts user to the fact that a Snapshot was found with PurgeAllow=true but with no PurgeAfter date.
			then echo "A Snapshot with the Snapshot ID $snapshot_id_evaluated has the tag \"PurgeAllow=true\" but does not have a \"PurgeAfter=YYYY-MM-DD\" date. $app_name is unable to determine if $snapshot_id_evaluated should be purged." 1>&2
		else
			#convert both the date_current and purge_after_date into epoch time to allow for comparison
			date_current_epoch=`get_date_current_epoch`
			purge_after_date_epoch=`get_purge_after_date_epoch`
			#perform compparison - if $purge_after_date_epoch is a lower number than $date_current_epoch than the PurgeAfter date is earlier than the current date - and the snapshot can be safely removed
			if [[ $purge_after_date_epoch < $date_current_epoch ]]
				then
				echo "The snapshot \"$snapshot_id_evaluated\" with the Purge After date of $purge_after_date will be deleted."
				ec2-delete-snapshot --region $region $snapshot_id_evaluated
			fi
		fi
	done
}

app_name=`basename $0`

#sets defaults
selection_method="volumeid"

#date_binary allows a user to set the "date" binary that is installed on their system and, therefore, the options that will be given to the date binary to perform date calculations
date_binary=""

#sets the "Name" tag set for a snapshot to false - using "Name" requires that ec2-create-tags be called in addition to ec2-create-snapshot
name_tag_create=false
#sets the "InitiatingHost" tag set for a snapshot to false
hostname_tag_create=false
#sets the user_tags feature to false - user_tag creates tags on snapshots - by default each snapshot is tagged with volume_id and current_data timestamp
user_tags=false
#sets the Purge Snapshot feature to false - this feature will eventually allow the removal of snapshots that have a "PurgeAfter" tag that is earlier than current date
purge_snapshots=false
#handles options processing
while getopts :s:c:r:v:t:k:pnhu opt
	do
		case $opt in
			s) selection_method="$OPTARG";;
			c) cron_primer="$OPTARG";;
			r) region="$OPTARG";;
			v) volumeid="$OPTARG";;
			t) tag="$OPTARG";;
			k) purge_after_days="$OPTARG";;
			n) name_tag_create=true;;
			h) hostname_tag_create=true;;
			p) purge_snapshots=true;;
			u) user_tags=true;;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#sources "cron_primer" file for running under cron or other restricted environments - this file should contain the variables and environment configuration required for ec2-automate-backup to run correctly
if [[ -n $cron_primer ]]
	then if [[ -f $cron_primer ]] 
		then source $cron_primer
	else
		echo "Cron Primer File \"$cron_primer\" Could Not Be Found." 1>&2 ; exit 70
	fi
fi

#if region is not set then:
if [[ -z $region ]]
	#if the environment variable $EC2_REGION is not set set to us-east-1
	then if [[ -z $EC2_REGION ]]
		#if both 
		then region="us-east-1"
	else
		region=$EC2_REGION
	fi
fi

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisite_check

#sets date variable
date_current=`date -u +%Y-%m-%d`
#sets the PurgeAfter tag to the number of days that a snapshot should be retained
if [[ -n $purge_after_days ]]
	then
	#if the date_binary is not set, call the date_binary_get function
	if [[ -z $date_binary ]]
		then date_binary_get
	fi
	purge_after_date=`get_purge_after_date`
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