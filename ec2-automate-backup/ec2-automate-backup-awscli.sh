#!/bin/bash -
# Date: 2014-04-12
# Version 0.10
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
# Author:
# Colin Johnson / https://github.com/colinbjohnson / colin@cloudavail.com
# Contributors:
# Alex Corley / https://github.com/anthroprose
# Jon Higgs / https://github.com/jonhiggs
# Mike / https://github.com/eyesis
# Jeff Vogt / https://github.com/jvogt
# Dave Stern / https://github.com/davestern
# Josef / https://github.com/J0s3f
# buckelij / https://github.com/buckelij

#confirms that executables required for succesful script execution are available
prerequisite_check() {
  for prerequisite in basename cut date aws; do
    #use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
    hash $prerequisite &> /dev/null
    if [[ $? == 1 ]]; then #has exits with exit status of 70, executable was not found
      echo "In order to use $app_name, the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
    fi
  done
}

#get_EBS_List gets a list of available EBS instances depending upon the selection_method of EBS selection that is provided by user input
get_EBS_List() {
  case $selection_method in
    volumeid)
      if [[ -z $volumeid ]]; then
        echo "The selection method \"volumeid\" (which is $app_name's default selection_method of operation or requested by using the -s volumeid parameter) requires a volumeid (-v volumeid) for operation. Correct usage is as follows: \"-v vol-6d6a0527\",\"-s volumeid -v vol-6d6a0527\" or \"-v \"vol-6d6a0527 vol-636a0112\"\" if multiple volumes are to be selected." 1>&2 ; exit 64
      fi
      ebs_selection_string="--volume-ids $volumeid"
      ;;
    tag)
      if [[ -z $tag ]]; then
        echo "The selected selection_method \"tag\" (-s tag) requires a valid tag (-t Backup,Values=true) for operation. Correct usage is as follows: \"-s tag -t Backup,Values=true.\"" 1>&2 ; exit 64
      fi
      ebs_selection_string="--filters Name=tag:$tag"
      ;;
    *) echo "If you specify a selection_method (-s selection_method) for selecting EBS volumes you must select either \"volumeid\" (-s volumeid) or \"tag\" (-s tag)." 1>&2 ; exit 64 ;;
  esac
  #creates a list of all ebs volumes that match the selection string from above
  ebs_backup_list=$(aws ec2 describe-volumes --region $region $ebs_selection_string --output text --query 'Volumes[*].VolumeId')
  #takes the output of the previous command 
  ebs_backup_list_result=$(echo $?)
  if [[ $ebs_backup_list_result -gt 0 ]]; then
    echo -e "An error occurred when running ec2-describe-volumes. The error returned is below:\n$ebs_backup_list_complete" 1>&2 ; exit 70
  fi
}

create_EBS_Snapshot_Tags() {
  #snapshot tags holds all tags that need to be applied to a given snapshot - by aggregating tags we ensure that ec2-create-tags is called only onece
  snapshot_tags=""
  #if $name_tag_create is true then append ec2ab_${ebs_selected}_$current_date to the variable $snapshot_tags
  if $name_tag_create; then
    snapshot_tags="$snapshot_tags Key=Name,Value=ec2ab_${ebs_selected}_$current_date"
  fi
  #if $hostname_tag_create is true then append --tag InitiatingHost=$(hostname -f) to the variable $snapshot_tags
  if $hostname_tag_create; then
    snapshot_tags="$snapshot_tags Key=InitiatingHost,Value='$(hostname -f)'"
  fi
  #if $purge_after_date_fe is true, then append $purge_after_date_fe to the variable $snapshot_tags
  if [[ -n $purge_after_date_fe ]]; then
    snapshot_tags="$snapshot_tags Key=PurgeAfterFE,Value=$purge_after_date_fe Key=PurgeAllow,Value=true"
  fi
  #if $user_tags is true, then append Volume=$ebs_selected and Created=$current_date to the variable $snapshot_tags
  if $user_tags; then
    snapshot_tags="$snapshot_tags Key=Volume,Value=${ebs_selected} Key=Created,Value=$current_date"
  fi
  #if $snapshot_tags is not zero length then set the tag on the snapshot using aws ec2 create-tags
  if [[ -n $snapshot_tags ]]; then
    echo "Tagging Snapshot $ec2_snapshot_resource_id with the following Tags: $snapshot_tags"
    tags_argument="--tags $snapshot_tags"
    aws_ec2_create_tag_result=$(aws ec2 create-tags --resources $ec2_snapshot_resource_id --region $region $tags_argument --output text 2>&1)
  fi
}

get_date_binary() {
  #$(uname -o) (operating system) would be ideal, but OS X / Darwin does not support to -o option
  #$(uname) on OS X defaults to $(uname -s) and $(uname) on GNU/Linux defaults to $(uname -s)
  uname_result=$(uname)
  case $uname_result in
    Darwin) date_binary="posix" ;;
    FreeBSD) date_binary="posix" ;;
    Linux) date_binary="linux-gnu" ;;
    *) date_binary="unknown" ;;
  esac
}

get_purge_after_date_fe() {
case $purge_after_input in
  #any number of numbers followed by a letter "d" or "days" multiplied by 86400 (number of seconds in a day)
  [0-9]*d) purge_after_value_seconds=$(( ${purge_after_input%?} * 86400 )) ;;
  #any number of numbers followed by a letter "h" or "hours" multiplied by 3600 (number of seconds in an hour)
  [0-9]*h) purge_after_value_seconds=$(( ${purge_after_input%?} * 3600 )) ;;
  #any number of numbers followed by a letter "m" or "minutes" multiplied by 60 (number of seconds in a minute)
  [0-9]*m) purge_after_value_seconds=$(( ${purge_after_input%?} * 60 ));;
  #no trailing digits default is days - multiply by 86400 (number of minutes in a day)
  *) purge_after_value_seconds=$(( $purge_after_input * 86400 ));;
esac
#based on the date_binary variable, the case statement below will determine the method to use to determine "purge_after_days" in the future
case $date_binary in
  linux-gnu) echo $(date -d +${purge_after_value_seconds}sec -u +%s) ;;
  posix) echo $(date -v +${purge_after_value_seconds}S -u +%s) ;;
  *) echo $(date -d +${purge_after_value_seconds}sec -u +%s) ;;
esac
}

purge_EBS_Snapshots() {
  # snapshot_purge_allowed is a string containing the SnapshotIDs of snapshots
  # that contain a tag with the key value/pair PurgeAllow=true
  snapshot_purge_allowed=$(aws ec2 describe-snapshots --region $region --filters Name=tag:PurgeAllow,Values=true --output text --query 'Snapshots[*].SnapshotId')
  
  for snapshot_id_evaluated in $snapshot_purge_allowed; do
    #gets the "PurgeAfterFE" date which is in UTC with UNIX Time format (or xxxxxxxxxx / %s)
    purge_after_fe=$(aws ec2 describe-snapshots --region $region --snapshot-ids $snapshot_id_evaluated --output text | grep ^TAGS.*PurgeAfterFE | cut -f 3)
    #if purge_after_date is not set then we have a problem. Need to alert user.
    if [[ -z $purge_after_fe ]]; then
      #Alerts user to the fact that a Snapshot was found with PurgeAllow=true but with no PurgeAfterFE date.
      echo "Snapshot with the Snapshot ID \"$snapshot_id_evaluated\" has the tag \"PurgeAllow=true\" but does not have a \"PurgeAfterFE=xxxxxxxxxx\" key/value pair. $app_name is unable to determine if $snapshot_id_evaluated should be purged." 1>&2
    else
      # if $purge_after_fe is less than $current_date then
      # PurgeAfterFE is earlier than the current date
      # and the snapshot can be safely purged
      if [[ $purge_after_fe < $current_date ]]; then
        echo "Snapshot \"$snapshot_id_evaluated\" with the PurgeAfterFE date of \"$purge_after_fe\" will be deleted."
        aws_ec2_delete_snapshot_result=$(aws ec2 delete-snapshot --region $region --snapshot-id $snapshot_id_evaluated --output text 2>&1)
      fi
    fi
  done
}

app_name=$(basename $0)
#sets defaults
selection_method="volumeid"
#date_binary allows a user to set the "date" binary that is installed on their system and, therefore, the options that will be given to the date binary to perform date calculations
date_binary=""
#sets the "Name" tag set for a snapshot to false - using "Name" requires that ec2-create-tags be called in addition to ec2-create-snapshot
name_tag_create=false
#sets the "InitiatingHost" tag set for a snapshot to false
hostname_tag_create=false
#sets the user_tags feature to false - user_tag creates tags on snapshots - by default each snapshot is tagged with volume_id and current_date timestamp
user_tags=false
#sets the Purge Snapshot feature to false - if purge_snapshots=true then snapshots will be purged
purge_snapshots=false
#handles options processing

while getopts :s:c:r:v:t:k:pnhu opt; do
  case $opt in
    s) selection_method="$OPTARG" ;;
    c) cron_primer="$OPTARG" ;;
    r) region="$OPTARG" ;;
    v) volumeid="$OPTARG" ;;
    t) tag="$OPTARG" ;;
    k) purge_after_input="$OPTARG" ;;
    n) name_tag_create=true ;;
    h) hostname_tag_create=true ;;
    p) purge_snapshots=true ;;
    u) user_tags=true ;;
    *) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64 ;;
  esac
done

#sources "cron_primer" file for running under cron or other restricted environments - this file should contain the variables and environment configuration required for ec2-automate-backup to run correctly
if [[ -n $cron_primer ]]; then
  if [[ -f $cron_primer ]]; then
    source $cron_primer
  else
    echo "Cron Primer File \"$cron_primer\" Could Not Be Found." 1>&2 ; exit 70
  fi
fi

#if region is not set then:
if [[ -z $region ]]; then
  #if the environment variable $EC2_REGION is not set set to us-east-1
  if [[ -z $EC2_REGION ]]; then
    region="us-east-1"
  else
    region=$EC2_REGION
  fi
fi

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisite_check

#sets date variable
current_date=$(date -u +%s)

#sets the PurgeAfterFE tag to the number of seconds that a snapshot should be retained
if [[ -n $purge_after_input ]]; then
  #if the date_binary is not set, call the get_date_binary function
  if [[ -z $date_binary ]]; then
    get_date_binary
  fi
  purge_after_date_fe=$(get_purge_after_date_fe)
  echo "Snapshots taken by $app_name will be eligible for purging after the following date (the purge after date given in seconds from epoch): $purge_after_date_fe."
fi

#get_EBS_List gets a list of EBS instances for which a snapshot is desired. The list of EBS instances depends upon the selection_method that is provided by user input
get_EBS_List

#the loop below is called once for each volume in $ebs_backup_list - the currently selected EBS volume is passed in as "ebs_selected"
for ebs_selected in $ebs_backup_list; do
  ec2_snapshot_description="ec2ab_${ebs_selected}_$current_date"
  ec2_snapshot_resource_id=$(aws ec2 create-snapshot --region $region --description $ec2_snapshot_description --volume-id $ebs_selected --output text --query SnapshotId 2>&1)
  if [[ $? != 0 ]]; then
    echo -e "An error occurred when running ec2-create-snapshot. The error returned is below:\n$ec2_create_snapshot_result" 1>&2 ; exit 70
  fi  
  create_EBS_Snapshot_Tags
done

#if purge_snapshots is true, then run purge_EBS_Snapshots function
if $purge_snapshots; then
  echo "Snapshot Purging is Starting Now."
  purge_EBS_Snapshots
fi
