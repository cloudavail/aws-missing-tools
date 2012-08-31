#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2012-08-11
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
#####
#confirms that executables required for succesful script execution are available
prerequisitecheck()
{
	for prerequisite in basename grep cut as-describe-auto-scaling-groups as-update-auto-scaling-group elb-deregister-instances-from-lb as-terminate-instance-in-auto-scaling-group elb-describe-instance-health
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use $app_name, the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

return_as_initial_maxsize()
{
	if [[ $max_size_change -eq 1 ]]
		then echo "$asg_group_name had its max-size increased temporarily by 1 to a max-size of $asg_temporary_max_size. $app_name will now return the max-size of $asg_group_name to its original max-size of $asg_initial_max_size."
		#decrease max-size by 1
		as-update-auto-scaling-group $asg_group_name --region $region --max-size=$asg_initial_max_size
	fi
}

return_as_initial_desiredcapacity()
{
	echo "$asg_group_name had its desired-capacity increased temporarily by 1 to a desired-capacity of $asg_temporary_desired_capacity. $app_name will now return the desired-capacity of $asg_group_name to its original desired-capacity of $asg_initial_desired_capacity."
	as-update-auto-scaling-group $asg_group_name --region $region --desired-capacity=$asg_initial_desired_capacity
}

#set application defaults
app_name=`basename $0`
elb_timeout=60
region="us-east-1"
#max_size_change is used as a "flag" to determine if the max-size of an Auto Scaling Group was changed
max_size_change="0"
inservice_time_allowed=300
inservice_polling_time=10
delimiter="%"

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisitecheck

#handles options processing
while getopts :a:t:r:i: opt
	do
		case $opt in
			a) asg_group_name="$OPTARG";;
			t) elb_timeout="$OPTARG";;
			r) region="$OPTARG";;
			i) inservice_time_allowed="$OPTARG";;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64 ;;
		esac
	done

#validate elb_timeout is number
##code to be written

if [[ -z $asg_group_name ]]
	then echo "You did not specify an Auto Scaling Group name. In order to use $app_name you must specify an Auto Scaling Group name using -a <autoscalingroupname>." 1>&2 ; exit 64
fi

#region validator
case $region in
	us-east-1|us-west-2|us-west-1|eu-west-1|ap-southeast-1|ap-northeast-1|sa-east-1) ;;
	*) echo "The \"$region\" region does not exist. You must specify a valid region (example: -r us-east-1 or -r us-west-2)." 1>&2 ; exit 64;;
esac

#creates variable containing Auto Scaling Group
asg_result=`as-describe-auto-scaling-groups $asg_group_name --show-long --max-records 1000 --region $region --delimiter $delimiter`
#validate Auto Scaling Group Exists
#user response for Auto Scaling Group lookup - alerts user if Auto Scaling Group was not found.
if [[ $asg_result = "No AutoScalingGroups found" ]]
	then echo "The Auto Scaling Group named \"$asg_group_name\" does not exist. You must specify an Auto Scaling Group that exists." 1>&2 ; exit 64
fi
#validate - the pipeline of echo -e "$aasg_result" | grep -c "AUTO-SCALING-GROUP"  must only return one group found - in the case below - more than one group has been found
if [[ `echo -e "$asg_result" | grep -c "^AUTO-SCALING-GROUP"` > 1  ]]
	then echo "More than one Auto Scaling Group found. As more than one Auto Scaling Group has been found, $app_name does not know which Auto Scaling Group should have Instances terminated." 1>&2 ; exit 64
fi
#validate - the pipeline of echo -e "$asg_result" | grep -c "AUTO-SCALING-GROUP"  must only return one group found
if [[ `echo -e "$asg_result" | grep -c "^AUTO-SCALING-GROUP"` < 1 ]]
	then echo "No Auto Scaling Group was found. Because no Auto Scaling Group has been found, $app_name does not know which Auto Scaling Group should have Instances terminated." 1>&2 ; exit 64
fi

#gets Auto Scaling Group max-size
asg_initial_max_size=`echo $asg_result | grep ^AUTO-SCALING-GROUP | cut -d "$delimiter" -f 10`
asg_temporary_max_size=$(($asg_initial_max_size+1))
#gets Auto Scaling Group desired-capacity
asg_initial_desired_capacity=`echo "$asg_result" | grep ^AUTO-SCALING-GROUP | cut -d "$delimiter" -f 10`
asg_temporary_desired_capacity=$((asg_initial_desired_capacity+1))
#gets list of Auto Scaling Group Instances - these Instances will be terminated
asg_instance_list=`echo "$asg_result" | grep ^INSTANCE | cut -d "$delimiter" -f 2`
asg_elb=`echo "$asg_result" | grep ^AUTO-SCALING-GROUP | cut -d "$delimiter" -f 6`
#if the max-size of the Auto Scaling Group is zero there is no reason to run
if [[ $asg_initial_max_size -eq 0 ]]
	then echo "$asg_group_name has a max-size of 0. As the Auto Scaling Group \"$asg_group_name\" has no active Instances there is no reason to run." ; exit 79
fi
#echo a list of Instances that are slated for termination
echo -e "The list of Instances in Auto Scaling Group $asg_group_name that will be terminated is below:\n$asg_instance_list"

#if the desired-capacity of an Auto Scaling Group group is greater than or equal to the max-size of an Auto Scaling Group, the max-size must be increased by 1 to cycle instances while maintaining desired-capacity. This is particularly true of groups of 1 instance (where we'd be removing all instances if we cycled).
if [[ $asg_initial_desired_capacity -ge $asg_initial_max_size ]]
	then echo "$asg_group_name has a max-size of $asg_initial_max_size. In order to recycle instances max-size will be temporarily increased by 1 to max-size $asg_temporary_max_size."
	#increase max-size by 1
	as-update-auto-scaling-group $asg_group_name --region $region --max-size=$asg_temporary_max_size
	#sets the flag that max-size has been changed
	max_size_change="1"
fi

#increase groups desired capacity to allow for instance recycling without decreasing available instances below initial capacity
echo "$asg_group_name is currently at $asg_initial_desired_capacity desired-capacity. $app_name will increase desired-capacity by 1 to desired-capacity $asg_temporary_desired_capacity."
as-update-auto-scaling-group $asg_group_name --region $region --desired-capacity=$asg_temporary_desired_capacity

#and begin recycling instances
for instance_selected in $asg_instance_list
do
	#the while loop below sleeps for the auto scaling group to have an InService capacity that is equal to the desired-capacity + 1
	while [[ $inservice_instance_count -lt $asg_temporary_desired_capacity ]]
	do
		if [[ $inservice_time_taken -gt $inservice_time_allowed ]]
			then echo "During the last $inservice_time_allowed seconds the InService capacity of the $asg_group_name Auto Scaling Group did not meet the Auto Scaling Group's desired capacity of $asg_temporary_desired_capacity." 1>&2
			#return max-size to initial size
			return_as_initial_maxsize
			#return temporary desired-capacity to initial desired-capacity
			return_as_initial_desiredcapacity
			exit 79
		fi
		inservice_instance_list=`elb-describe-instance-health $asg_elb --region $region --show-long | grep InService`
		inservice_instance_count=`echo "$inservice_instance_list" | wc -l`
		#sleeps a particular amount of time 
		sleep $inservice_polling_time
		inservice_time_taken=$(($inservice_time_taken+$inservice_polling_time))
		echo $inservice_instance_count "Instances are InService status. $asg_temporary_desired_capacity Instances are required to terminate the next instance. $inservice_time_taken seconds have elapsed while waiting for an Instance to reach InService status."
	#if any status in $elbinstsancehealth != "InService" repeat
	done
	#if the 
	echo "$asg_group_name has reached a desired-capacity of $asg_temporary_desired_capacity. $app_name can now remove an Instance from service."

	inservice_instance_count=0
	inservice_time_taken=0
	#remove instance from ELB - this ensures no traffic will be directed at an instance that will be terminated
	echo "Instance $instance_selected will now be deregistered from ELB \"$asg_elb.\""
	elb-deregister-instances-from-lb $asg_elb --region $region --instances $instance_selected > /dev/null
	#sleep for "elb_timeout" seconds so that the instance can complete all processing before being terminated
	sleep $elb_timeout
	#terminates a pre-existing instance within the autoscaling group
	echo "Instance $instance_selected will now be terminated. By terminating this Instance, the actual capacity will be decreased to 1 under desired-capacity."
	as-terminate-instance-in-auto-scaling-group --instance $instance_selected --no-decrement-desired-capacity --force > /dev/null
done

#return max-size to initial size
return_as_initial_maxsize
#return temporary desired-capacity to initial desired-capacity
return_as_initial_desiredcapacity
