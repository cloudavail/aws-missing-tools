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
	for prerequisite in basename grep cut aws
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
		aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_group_name --region $region --max-size=$asg_initial_max_size
	fi
}

return_as_initial_desiredcapacity()
{
	echo "$asg_group_name had its desired-capacity increased temporarily by 1 to a desired-capacity of $asg_temporary_desired_capacity. $app_name will now return the desired-capacity of $asg_group_name to its original desired-capacity of $asg_initial_desired_capacity."
	aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_group_name --region $region --desired-capacity=$asg_initial_desired_capacity
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
	us-east-1|us-west-2|us-west-1|eu-west-1|ap-southeast-1|ap-northeast-1|sa-east-1|ap-southeast-2) ;;
	*) echo "The \"$region\" region does not exist. You must specify a valid region (example: -r us-east-1 or -r us-west-2)." 1>&2 ; exit 64;;
esac

#creates variable containing Auto Scaling Group
asg_result=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $asg_group_name --region $region`
#validate Auto Scaling Group Exists
#validate - the pipeline of echo -e "$asg_result" | grep -c "AutoScalingGroupARN"  must only return one group found - in the case below - more than one group has been found
if [[ `echo -e "$asg_result" | grep -c "AutoScalingGroupARN"` > 1  ]]
	then echo "More than one Auto Scaling Group found. As more than one Auto Scaling Group has been found, $app_name does not know which Auto Scaling Group should have Instances terminated." 1>&2 ; exit 64
fi
#validate - the pipeline of echo -e "$asg_result" | grep -c "AutoScalingGroupARN"  must only return one group found
if [[ `echo -e "$asg_result" | grep -c "AutoScalingGroupARN"` < 1 ]]
	then echo "No Auto Scaling Group was found. Because no Auto Scaling Group has been found, $app_name does not know which Auto Scaling Group should have Instances terminated." 1>&2 ; exit 64
fi
#confirms that certain Auto Scaling processes are not suspended. For certain processes, the "Suspending Processing" state prevents the termination of Auto Scaling Group instances and thus prevents aws-ha-release from running properly.
necessary_processes=(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer)
for process in "${necessary_processes[@]}"
do
	if [[ `echo -e "$asg_result" | grep -c "SuspensionReason"` > 0 ]]
		then echo "Scaling Process $process for the Auto Scaling Group $asg_group_name is currently suspended. $app_name will now exit as Scaling Processes ${necessary_processes[@]} are required for $app_name to run properly." 1>&2 ; exit 77
	fi
done

#gets Auto Scaling Group max-size
asg_initial_max_size=`echo $asg_result | awk '/MaxSize/{ print $2 }' RS=,`
asg_temporary_max_size=$(($asg_initial_max_size+1))
#gets Auto Scaling Group desired-capacity
asg_initial_desired_capacity=`echo $asg_result | awk '/DesiredCapacity/{ print $2 }' RS=,`
asg_temporary_desired_capacity=$((asg_initial_desired_capacity+1))
#gets list of Auto Scaling Group Instances - these Instances will be terminated
asg_instance_list=`echo "$asg_result" | grep InstanceId | sed 's/.*i-/i-/' | sed 's/",//'`

#builds an array of load balancers
asg_elbs=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $asg_group_name --region $region --output text | grep LOADBALANCERNAMES | sed "s/LOADBALANCERNAMES[[:space:]]//"`

#if the max-size of the Auto Scaling Group is zero there is no reason to run
if [[ $asg_initial_max_size -eq 0 ]]
	then echo "$asg_group_name has a max-size of 0. As the Auto Scaling Group \"$asg_group_name\" has no active Instances there is no reason to run." ; exit 79
fi
#echo a list of Instances that are slated for termination
echo -e "The list of Instances in Auto Scaling Group $asg_group_name that will be terminated is below:\n$asg_instance_list"

as_processes_to_suspend="ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance"
aws autoscaling suspend-processes --auto-scaling-group-name $asg_group_name --scaling-processes $as_processes_to_suspend --region $region

#if the desired-capacity of an Auto Scaling Group group is greater than or equal to the max-size of an Auto Scaling Group, the max-size must be increased by 1 to cycle instances while maintaining desired-capacity. This is particularly true of groups of 1 instance (where we'd be removing all instances if we cycled).
if [[ $asg_initial_desired_capacity -ge $asg_initial_max_size ]]
	then echo "$asg_group_name has a max-size of $asg_initial_max_size. In order to recycle instances max-size will be temporarily increased by 1 to max-size $asg_temporary_max_size."
	#increase max-size by 1
	aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_group_name --region $region --max-size=$asg_temporary_max_size
	#sets the flag that max-size has been changed
	max_size_change="1"
fi

#increase groups desired capacity to allow for instance recycling without decreasing available instances below initial capacity
echo "$asg_group_name is currently at $asg_initial_desired_capacity desired-capacity. $app_name will increase desired-capacity by 1 to desired-capacity $asg_temporary_desired_capacity."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_group_name --region $region --desired-capacity=$asg_temporary_desired_capacity

#and begin recycling instances
for instance_selected in $asg_instance_list
do
	all_instances_inservice=0

	#the while loop below sleeps for the auto scaling group to have an InService capacity that is equal to the desired-capacity + 1
	while [[ $all_instances_inservice -eq 0 ]]
	do
		if [[ $inservice_time_taken -gt $inservice_time_allowed ]]
			then echo "During the last $inservice_time_allowed seconds the InService capacity of the $asg_group_name Auto Scaling Group did not meet the Auto Scaling Group's desired capacity of $asg_temporary_desired_capacity." 1>&2
			echo "Because we can't be sure that instances created by this script are healthy, settings that were changed are being left as is. Settings that were changed:"

			if [[ $max_size_change -eq 1 ]]
				then echo "max size was increased by $max_size_change"
			fi

			echo "desired capacity was increased by 1"
			echo "AutoScaling processes \"$as_processes_to_suspend\" were suspended."

			exit 79
		fi

		for index in "${!asg_elbs[@]}"
		do
			inservice_instance_list=`aws elb describe-instance-health --load-balancer-name ${asg_elbs[$index]} --region $region --output text | grep InService`
			inservice_instance_count=`echo "$inservice_instance_list" | wc -l`

			if [ $index -eq 0 ]
				then [ $inservice_instance_count -eq $asg_temporary_desired_capacity ] && all_instances_inservice=1 || all_instances_inservice=0
			else
				[[ ($all_instances_inservice -eq 1) && ($inservice_instance_count -eq $asg_temporary_desired_capacity) ]] && all_instances_inservice=1 || all_instances_inservice=0
			fi
		done

		#sleeps a particular amount of time 
		sleep $inservice_polling_time

		inservice_time_taken=$(($inservice_time_taken+$inservice_polling_time))
		echo $inservice_instance_count "Instances are InService status. $asg_temporary_desired_capacity Instances are required to terminate the next instance. $inservice_time_taken seconds have elapsed while waiting for an Instance to reach InService status."
	#if any status in $elbinstancehealth != "InService" repeat
	done

	#if the 
	echo "$asg_group_name has reached a desired-capacity of $asg_temporary_desired_capacity. $app_name can now remove an Instance from service."

	inservice_instance_count=0
	inservice_time_taken=0
	#remove instance from ELB - this ensures no traffic will be directed at an instance that will be terminated
	echo "Instance $instance_selected will now be deregistered from ELBs \"${asg_elbs[@]}.\""
	for elb in "${asg_elbs[@]}"
	do
		aws elb deregister-instances-from-load-balancer --load-balancer-name $elb --region $region --instances $instance_selected > /dev/null
	done

	#sleep for "elb_timeout" seconds so that the instance can complete all processing before being terminated
	sleep $elb_timeout
	#terminates a pre-existing instance within the autoscaling group
	echo "Instance $instance_selected will now be terminated. By terminating this Instance, the actual capacity will be decreased to 1 under desired-capacity."
	aws autoscaling terminate-instance-in-auto-scaling-group --region $region --instance-id $instance_selected --no-should-decrement-desired-capacity > /dev/null
done

#return max-size to initial size
return_as_initial_maxsize

#return temporary desired-capacity to initial desired-capacity
return_as_initial_desiredcapacity

aws autoscaling resume-processes --auto-scaling-group-name $asg_group_name --region $region
