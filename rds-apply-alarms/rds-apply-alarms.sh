#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2011-10-30
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
#rds-alarm-apply start

#confirms that executables required for succesful script execution are available
prerequisitecheck()
{
	for prerequisite in basename cut grep mon-put-metric-alarm rds-describe-db-instances
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use `basename $0`, the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisitecheck

region="us-east-1"

#handles options processing
while getopts :d:r:t:p:e:a opt
	do
		case $opt in
			d) dbname="$OPTARG";;
			r) region="$OPTARG";;
			t) topicname="$OPTARG";;
			e) evaluationperiod="$OPTARG";;
			p) previewmode="$OPTARG";;
			a) allrds="true";;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#sets previewmode - will echo commands rather than performing work
case $previewmode in
	true|True) previewmode="echo"; echo "Preview Mode is set to \"True.\"" 1>&2 ;;
	""|false|False) previewmode="";;
	*) echo "You specified \"$previewmode\" for Preview Mode. If specifying a Preview Mode you must specificy either \"true\" or \"false.\"" 1>&2 ; exit 64;;
esac

# evaluationperiod validator - must be a number between 1 and 99
case $evaluationperiod in
	"") evaluationperiod=1;;
	[1-99]) ;;
	*) echo "You specified \"$evaluationperiod\" for your evaluation period. If specifying an evalaution period you must specify a period between 1 and 99." 1>&2 ; exit 64;;
esac

# region validator
case $region in
	us-east-1|us-west-2|us-west-1|eu-west-1|ap-southeast-1|ap-northeast-1|sa-east-1|ap-southeast-2) ;;
	*) echo "The \"$region\" region does not exist. You must specify a valid region (example: -r us-east-1 or -r us-west-2)." 1>&2 ; exit 64;;
esac

# single RDS instance validator - runs if applying to only one instance
if [[ $allrds != "true" ]]
	then
	if [[ $dbname == "" ]]
		then echo "You did not specify an RDS instance. You must select an RDS instance to apply alarms to." 1>&2 ; exit 64
	fi
	if [[ `rds-describe-db-instances $dbname --region $region 2> /dev/null` =~ .*DBINSTANCE.*$dbame ]]
		then echo "RDS instance $dbname has been found."
		else echo "The RDS instance \"$dbname\" does not exist. You must specify a valid RDS instance." 1>&2 ; exit 64
	fi
fi

# multiple RDS instance validator - runs if applying to all instances
if [[ $allrds == "true" ]]
	then
	if [[ $dbname != "" ]]
		then
		echo "You specified both \"All\" RDS instances and \"$dbname\" to apply alarms to. You must specify either one particular RDS instance (-d <dbname>) or all RDS instances (-a)." 1>&2 ; exit 64
	else
		echo "Alarms will be applied to all RDS instances."
	fi
fi

rdsinstancelist=`rds-describe-db-instances $dbname --region $region --show-long | grep -i DBINSTANCE | cut -d ',' -f2`

for rdsinstancename in $rdsinstancelist
	do
		echo "Applying Alarms to RDS instance $rdsinstancename."

		#start of apply-alarms
		rdsinstancetype=`rds-describe-db-instances $rdsinstancename --region $region --show-long | cut -d ',' -f4`
		rdstorage=`rds-describe-db-instances $rdsinstancename --region $region --show-long | cut -d ',' -f6`

		#given rds instance type, determines what 5% of freeable memory is
		case $rdsinstancetype in
		db.m1.small) lowfreeablememory=0.85E8;; #1.7 GB memory
		db.m1.large) lowfreeablememory=3.75E8;; #7.5 GB memory
		db.m1.xlarge) lowfreeablememory=7.5E8;; #15 GB memory
		db.m2.xlarge) lowfreeablememory=8.55E8;; #17.1 GB memory
		db.m2.2xlarge) lowfreeablememory=17.0E8;; #34 GB memory
		db.m2.4xlarge) lowfreeablememory=34.0E8;; #68 GB memory
		*) echo "An error has occured when attempting to set low memory threshold. Please contact the author of rds-apply-alarms." 1>&2 ; exit 64;;
		esac
		#determines the low storage alert - at less than 10% of rdsstorage
		lowstorage="${rdstorage}.0E8"

		$previewmode mon-put-metric-alarm --alarm-name $rdsinstancename-RDS-CPUUtilization-Critical --metric-name CPUUtilization --namespace AWS/RDS --statistic Average  --period 300 --threshold 90 --comparison-operator GreaterThanThreshold  --dimensions DBInstanceIdentifier=$rdsinstancename --evaluation-periods $evaluationperiod --unit Percent --alarm-actions $topicname --region $region

		$previewmode mon-put-metric-alarm --alarm-name $rdsinstancename-RDS-FreeableMemory-Critical --metric-name FreeableMemory --namespace AWS/RDS --statistic Average  --period 300 --threshold $lowfreeablememory --comparison-operator LessThanThreshold  --dimensions DBInstanceIdentifier=$rdsinstancename --evaluation-periods $evaluationperiod --unit Bytes --alarm-actions $topicname --region $region

		$previewmode mon-put-metric-alarm --alarm-name $rdsinstancename-RDS-SwapUsage-Critical --metric-name SwapUsage --namespace AWS/RDS --statistic Maximum  --period 300 --threshold 1048576 --comparison-operator GreaterThanThreshold  --dimensions DBInstanceIdentifier=$rdsinstancename --evaluation-periods $evaluationperiod --unit Bytes --alarm-actions $topicname --region $region

		$previewmode mon-put-metric-alarm --alarm-name $rdsinstancename-RDS-FreeStorageSpace-Critical --metric-name FreeStorageSpace --namespace AWS/RDS --statistic Minimum  --period 300 --threshold $lowstorage --comparison-operator LessThanThreshold  --dimensions DBInstanceIdentifier=$rdsinstancename --evaluation-periods $evaluationperiod --unit Bytes --alarm-actions $topicname --region $region

done
