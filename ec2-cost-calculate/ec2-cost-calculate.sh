#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2011-03-07
# Version 0.5
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
# Add Features:
#multi-region, all-region
#handle as-ag with min, mix and "desired cost"
#randomize ec2-list temp file, keep from clobbering 
#####
#ec2-cost-calculate start
#confirms that executables required for succesful script execution are available
prerequisitecheck()
{
	for prerequisite in basename awk ec2-describe-instances
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

#handles options processing
while getopts :r:p:o: opt
	do
		case $opt in
			p) period="$OPTARG";;
			r) region="$OPTARG";;
			o) output="$OPTARG";; #as of 2011-11-27 not implemented
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

# period validator and cost multiplier
case $period in
	"") multiple=1; period=hour ;;
	hour|Hour) multiple=1; ;;
	day|Day) multiple=24;;
	week|Week) multiple=168;;
	month|Month) multiple=720;;
	year|Year) multiple=8760;;
	*) echo "The \"$period\" period does not exist. You must specify a valid period for which to calculate AWS cost (example: -p hour or -p day)." 1>&2 ; exit 64;;
esac

# cost matrix

# region validator
case $region in
	us-east-1|"") regionselected=(us-east-1);;
	us-west-1) regionselected=(us-west-1);;
	us-west-2) regionselected=(us-west-2);;
	eu-west-1) regionselected=(eu-west-1);;
	ap-southeast-1) regionselected=(ap-southeast-1);;
	ap-northeast-1) regionselected=(ap-northeast-1);;
	sa-east-1) regionselected=(sa-east-1);;
	all) regionselected=(us-east-1 us-west-1 us-west-2 eu-west-1 ap-southeast-1 ap-northeast-1 sa-east-1);;
	*) echo "The \"$region\" region does not exist. You must specify a valid region for which to calculate AWS cost (example: -r us-east-1 or -r us-west-1)." 1>&2 ; exit 64;;
esac
#ensures that headers are only printed on the first run
runnumber=0
# loops through a single region or all regions
for currentregion in ${regionselected[@]}
do
ec2-describe-instances --region $currentregion --show-empty-fields --filter instance-state-name=running | awk -v currentregion=$currentregion -v period=$period -v multiple=$multiple -v runnumber=$runnumber '
BEGIN {
instancecount=0
#sets cost for region us-east-1
if ( currentregion == "us-east-1" ) {
 cost["m1.small"]="0.08" ; cost["m1.medium"]="0.16" ; cost["m1.large"]="0.32" ; cost["m1.xlarge"]="0.64" ; cost["t1.micro"]="0.02" ; cost["m2.xlarge"]="0.45" ; cost["m2.2xlarge"]="0.9" ; cost["m2.4xlarge"]="1.8" ; cost["c1.medium"]="0.165" ; cost["c1.xlarge"]="0.66" ; cost["cc1.4xlarge"]="1.3" ; cost["cc2.8xlarge"]="2.4" ; cost["cg1.4xlarge"]="2.1" ; cost["hi1.4xlarge"]="3.1" }
#sets cost for region us-west-2
if ( currentregion == "us-west-2" ) {
 cost["m1.small"]="0.08" ; cost["m1.medium"]="0.16" ; cost["m1.large"]="0.32" ; cost["m1.xlarge"]="0.64" ; cost["t1.micro"]="0.02" ; cost["m2.xlarge"]="0.45" ; cost["m2.2xlarge"]="0.9" ; cost["m2.4xlarge"]="1.8" ; cost["c1.medium"]="0.165" ; cost["c1.xlarge"]="0.66" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]="" }
#sets cost for region us-west-1
if ( currentregion == "us-west-1" ) {
 cost["m1.small"]="0.09" ; cost["m1.medium"]="0.18" ; cost["m1.large"]="0.36" ; cost["m1.xlarge"]="0.72" ; cost["t1.micro"]="0.025" ; cost["m2.xlarge"]="0.506" ; cost["m2.2xlarge"]="1.012" ; cost["m2.4xlarge"]="2.024" ; cost["c1.medium"]="0.186" ; cost["c1.xlarge"]="0.744" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]="" }
#sets cost for region eu-east-1
if ( currentregion == "eu-west-1" ) {
 cost["m1.small"]="0.85" ; cost["m1.medium"]="0.17" ; cost["m1.large"]="0.34" ; cost["m1.xlarge"]="0.68" ; cost["t1.micro"]="0.02" ; cost["m2.xlarge"]="0.506" ; cost["m2.2xlarge"]="1.012" ; cost["m2.4xlarge"]="2.024" ; cost["c1.medium"]="0.186" ; cost["c1.xlarge"]="0.744" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="2.7" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]="" }
#sets cost for region ap-southeast-1
if ( currentregion == "ap-southeast-1" ) {
 cost["m1.small"]="0.85" ; cost["m1.medium"]="0.17" ; cost["m1.large"]="0.34" ; cost["m1.xlarge"]="0.68" ; cost["t1.micro"]="0.02" ; cost["m2.xlarge"]="0.506" ; cost["m2.2xlarge"]="1.012" ; cost["m2.4xlarge"]="2.024" ; cost["c1.medium"]="0.186" ; cost["c1.xlarge"]="0.744" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]="" }
#sets cost for region ap-northeast-1
if ( currentregion == "ap-northeast-1" ) {
 cost["m1.small"]="0.092" ; cost["m1.medium"]="0.184" ; cost["m1.large"]="0.368" ; cost["m1.xlarge"]="0.736" ; cost["t1.micro"]="0.027" ; cost["m2.xlarge"]="0.518" ; cost["m2.2xlarge"]="1.036" ; cost["m2.4xlarge"]="2.072" ; cost["c1.medium"]="0.19" ; cost["c1.xlarge"]="0.76" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]="" }
#sets cost for region sa-east-1
if ( currentregion == "sa-east-1" ) {
 cost["m1.small"]="0.115" ; cost["m1.large"]="0.23" ; cost["m1.large"]="0.46" ; cost["m1.xlarge"]="0.92" ; cost["t1.micro"]="0.027" ; cost["m2.xlarge"]="0.68" ; cost["m2.2xlarge"]="1.36" ; cost["m2.4xlarge"]="2.72" ; cost["c1.medium"]="0.23" ; cost["c1.xlarge"]="0.92" ; cost["cc1.4xlarge"]="" ; cost["cc2.8xlarge"]="" ; cost["cg1.4xlarge"]="" ; cost["hi1.4xlarge"]=""  }

if ( runnumber == 0 ) {
 printf ("%s %s %s %s %s %s %s %s\n", "InstanceID", "InstanceSize", "InstanceIP", "InstanceStatus", "InstanceName", "AutoScalingGroup", "Region", "InstanceCost" )
 }
}

/^INSTANCE/ {
 if ( instancecount >= 1 ) {
  printf ("%s %s %s %s %s %s %s %s\n", instanceid, instancesize, instanceip, instancestatus, tag[0], tag[1], currentregion, cost[instancesize]*multiple )
 }
 instancecount++
 instanceid=$2 ; instancesize=$10 ; instanceip=$4 ; instancestatus=$6; tag[0]="Null" ; tag[1]="Null"
 }
/^TAG/ {
 if ( $4 == "Name" ) tag[0]=$5
 if ( $4 == "aws:autoscaling:groupName" ) tag[1]=$5
 }
#prints out last instance
END { if ( instanceid != "" ) printf ("%s %s %s %s %s %s %s %s\n" , instanceid, instancesize, instanceip, instancestatus, tag[0] , tag[1], currentregion, cost[instancesize]*multiple ) }
'
runnumber=$((runnumber+1))
done