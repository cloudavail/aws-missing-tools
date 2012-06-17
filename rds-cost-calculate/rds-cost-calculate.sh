#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2011-03-07
# Version 0.5
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#
# Add Features:
#####
#rds-cost-calculate start
#confirms that executables required for succesful script execution are available
prerequisitecheck()
{
	for prerequisite in basename awk rds-describe-db-instances
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
			o) output="$OPTARG";; #as of 2011-12-30 not implemented
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
rds-describe-db-instances --region $currentregion --show-long --max-records 100 | awk -v currentregion=$currentregion -v period=$period -v multiple=$multiple -v runnumber=$runnumber '
BEGIN {
FS = ","
dbinstancecount=0
#sets cost for regions us-east-1 and us-west-2
if ( currentregion == "us-east-1" || currentregion == "us-west-2" ) {
 cost["db.t1.micro"]="0.025" ; cost["db.m1.small"]="0.105" ; cost["db.m1.large"]="0.415" ; cost["db.m1.xlarge"]="0.83" ; cost["db.m2.xlarge"]="0.585" ; cost["db.m2.2xlarge"]="1.17" ; cost["db.m2.4xlarge"]="2.34" }
#sets cost for regions eu-east-1, ap-southeast-1 and us-west-1
if ( currentregion == "eu-west-1" || currentregion == "ap-southeast-1" || currentregion == "us-west-1" ) {
 cost["db.t1.micro"]="0.035" ; cost["db.m1.small"]="0.115" ; cost["db.m1.large"]="0.455" ; cost["db.m1.xlarge"]="0.92" ; cost["db.m2.xlarge"]="0.655" ; cost["db.m2.2xlarge"]="1.315" ; cost["db.m2.4xlarge"]="2.63" }
#sets cost for region ap-northeast-1
if ( currentregion == "ap-northeast-1" ) {
 cost["db.t1.micro"]="0.035" ; cost["db.m1.small"]="0.12" ; cost["db.m1.large"]="0.48" ; cost["db.m1.xlarge"]="0.955" ; cost["db.m2.xlarge"]="0.675" ; cost["db.m2.2xlarge"]="1.35" ; cost["db.m2.4xlarge"]="2.695" }
#sets cost for region sa-east-1
if ( currentregion == "sa-east-1" ) {
 cost["db.t1.micro"]="0.035" ; cost["db.m1.small"]="0.15" ; cost["db.m1.large"]="0.6" ; cost["db.m1.xlarge"]="1.2" ; cost["db.m2.xlarge"]="0.88" ; cost["db.m2.2xlarge"]="1.76" ; cost["db.m2.4xlarge"]="3.52" }

if ( runnumber == 0 ) {
 printf ("%s %s %s %s %s %s %s %s %s\n", "DBInstanceId", "Class", "Storage", "Status", "SecurityGroup" , "EndpointAddress", "MultiAZ", "Region", "InstanceCost" )
 }
}

/^DBINSTANCE/ {
 if ( dbinstancecount >= 1 ) {
  if ( multiaz == "y" ) {
  multiazmultiple=2
  } else {
  multiazmultiple=1 ;
  }
  #prints previous instance
  printf ("%s %s %s %s %s %s %s %s %s\n", dbinstanceid, class, storage, status, secgroup, endpointaddress, multiaz, currentregion, cost[class]*multiple*multiazmultiple )
 }
 dbinstancecount++
 #loads current instance
 dbinstanceid=$2 ; class=$4 ; storage=$6 ; status=$8 ; secgroup="Null" ; endpointaddress=$9 ; multiaz=$23
 }
 #gets security group of instance
/^SECGROUP/ {
 if ( $1 == "SECGROUP" ) secgroup=$2
 }
#prints out last instance
END { if ( dbinstanceid != "" ) {
  if ( multiaz == "y" ) {
  multiazmultiple=2;
  } else {
  multiazmultiple=1;
  }
  printf ("%s %s %s %s %s %s %s %s %s\n", dbinstanceid, class, storage, status, secgroup, endpointaddress, multiaz, currentregion, cost[class]*multiple*multiazmultiple ) }
}
'
runnumber=$((runnumber+1))
done