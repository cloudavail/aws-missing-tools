#!/bin/bash -
#get instance id - used for putting metric
INSTANCE_ID=`GET http://169.254.169.254/latest/meta-data/instance-id`
INSTANCE_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/`
INSTANCE_REGION=${INSTANCE_AZ%?}

#belowshould be changed to grep - get only everything after % space slash
filesystemlist=`df -l | grep -i \/ | cut -c57-100` #add -l to restrict to local file systems

for filesystemmountpoint in $filesystemlist
	do
	storageused=`df | grep %\ *$filesystemmountpoint$ | grep -o [0-9]*% | tr -d %` #need to error check and possibly remove leading white space
	mon-put-data --region $INSTANCE_REGION --metric-name StorageUsed --namespace EC2/Storage --value $storageused --unit Percent --dimensions FileSystem=$filesystemmountpoint,InstanceId=$INSTANCE_ID
done

#to run in cron every 5 minutes - note that you must first provide credentials for mon-put-data
#echo "*/5 * * * * ec2-user /usr/local/bin/ec2-write-storage-used.sh" > /etc/cron.d/ec2-write-storage-used
