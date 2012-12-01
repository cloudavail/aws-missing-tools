#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2012-02-28
# Version 0.5
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
#as-alarm-apply start
#confirms that executables required for succesful script execution are available
prerequisitecheck()
{
	for prerequisite in basename cut grep as-describe-auto-scaling-groups mon-put-metric-alarm
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use `basename $0` the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisitecheck

#sets defaults of as-apply-alarms
region="us-east-1"

#handles options processing
while getopts :g:r:t:p:e:a opt
	do
		case $opt in
			g) asgname="$OPTARG";;
			r) region="$OPTARG";;
			t) topicname="$OPTARG";;
			e) evaluationperiod="$OPTARG";;
			p) previewmode="$OPTARG";;
			a) allasg="true";;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#sets previewmode - will echo commands rather than performing work
case $previewmode in
	true|True) previewmode="echo"; echo "Preview Mode is set to \"True.\"" ;;
	""|false|False) previewmode="";;
	*) echo "You specified \"$previewmode\" for Preview Mode. If specifying a Preview Mode you must specificy either \"true\" or \"false.\"" 1>&2 ; exit 64;;
esac

# evaluationperiod validator - must be a number between 1 and 99
case $evaluationperiod in
	"") evaluationperiod=1;;
	[1-99]) ;;
	*) echo "You specified \"$evaluationperiod\" for your evaluation period. If specifying an evaluation period you must specify a period between 1 and 99." 1>&2 ; exit 64;;
esac

# region validator
case $region in
	us-east-1|us-west-2|us-west-1|eu-west-1|ap-southeast-1|ap-northeast-1|sa-east-1|ap-southeast-2) ;;
	*) echo "The \"$region\" region does not exist. You must specify a valid region (example: -r us-east-1 or -r us-west-2)." 1>&2 ; exit 64;;
esac

# single asg validator - runs if applying to only one asg
if [[ $allasg != "true" ]]
	then
	if [[ $asgname == "" ]]
		then echo "You did not specify an Auto Scaling Group. You must select an Auto Scaling Group to apply alarms to (example: as-apply-alarms.sh -g <autoscalinggroupname>) or you must select all Auto Scaling Groups (example: as-apply-alarms.sh -a)." 1>&2 ; exit 64
	fi
	if [[ `as-describe-auto-scaling-groups $asgname --region $region --max-records 1000 2> /dev/null` =~ .*AUTO-SCALING-GROUP.*$asgname ]]
		then echo "Auto Scaling Group $asgname has been found."
		else echo "The Auto Scaling Group \"$asgname\" does not exist. You must specify a valid Auto Scaling Group." 1>&2 ; exit 64
	fi
fi

# multiple asg validator - runs if applying to all asgs
if [[ $allasg == "true" ]]
	then
	if [[ $asgname != "" ]]
		then
		echo "You specified both \"All\" Auto Scaling Groups and the Auto Scaling Group \"$asgname\" to apply alarms to. You must specify either one particular Auto Scaling Group (-g <autoscalinggroup>) or all Auto Scaling Groups (-a) but not both." 1>&2 ; exit 64
	else
		echo "Alarms will be applied to all Auto Scaling Groups."
	fi
fi

asglist=`as-describe-auto-scaling-groups $asgname --show-long --region $region --max-records 1000 | grep -i "AUTO-SCALING-GROUP" | cut -d ',' -f2`

#the below works - should confirm it is an array
for asgin in $asglist
	do
		echo "Applying Alarms to the Auto Scaling Group named $asgin."

		#to be used if any alarms are dependent on instance size
		# asglaunchconfig=`as-describe-auto-scaling-groups $asgname --show-long | cut -d ',' -f3`
		# asginstancetype=`as-describe-launch-configs $asglaunchconfig --show-long | cut -d ',' -f4`
		
		$previewmode mon-put-metric-alarm --alarm-name $asgin-ASG-CPUUtilization-Critical --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 300 --threshold 90 --comparison-operator GreaterThanThreshold  --dimensions AutoScalingGroupName=$asgin --evaluation-periods $evaluationperiod --unit Percent --alarm-actions $topicname --region $region

done
