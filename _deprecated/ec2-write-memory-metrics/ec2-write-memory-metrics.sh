#!/bin/bash -
#get instance id - used for putting metric
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
INSTANCE_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/`
INSTANCE_REGION=${INSTANCE_AZ%?}

#could be done using "free" or "vmstat" - use of less and grep is believed to provide widest compatibility - CJ 2011-11-24
memfree=`cat /proc/meminfo | grep -i MemFree | grep -o [0-9]*`
swaptotal=`cat /proc/meminfo | grep -i SwapTotal | grep -o [0-9]*`
swapfree=`cat /proc/meminfo | grep -i SwapFree | grep -o [0-9]*`
swapused=$(($swaptotal-$swapfree))

#mon-put-data to put metrics
mon-put-data --region $INSTANCE_REGION --metric-name MemoryFree --namespace EC2/Memory --value $memfree --unit Kilobytes --dimensions "InstanceId=$INSTANCE_ID"
mon-put-data --region $INSTANCE_REGION --metric-name SwapUsed --namespace EC2/Memory --value $swapused --unit Kilobytes --dimensions "InstanceId=$INSTANCE_ID"

#to run in cron every 5 minutes - note that you must first provide credentials for mon-put-data
#echo "*/5 * * * * ec2-user /usr/local/bin/ec2-write-memory-metrics.sh" > /etc/cron.d/ec2-write-memory-metrics
