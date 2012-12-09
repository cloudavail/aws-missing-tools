# Introduction:
aws-ha-release allows the high-availability / no downtime replacement of all EC2 Instances in an Auto Scaling Group that is behind an Elastic Load Balancer.
#
# Potential Use:
Some potential uses aws-ha-release are listed below:
1. Delivery of new code - if your deployment scheme utilizes the termination of EC2 instances in order to release new code aws-ha-release provides an automated way to do this without incurring any downtime. 
2. Return of all EC2 instances to "pristine" or "vanilla" state - all older EC2 instances can be replaced with newer EC2 instances.

# Directions For Use:
## Example of Use:
    aws-ha-release.sh -a my-scaling-group
the above example would terminate and replace each EC2 Instance in the Auto Scaling group "my-scaling-group" with a new EC2 Instance.
## Required Options:
aws-ha-release.sh requires the following option:
`-a <auto-scaling-group-name>` - the name of the Auto Scaling Group for which you wish to perform a no downtime 
## Optional Parameters:
`-r <region>` - allows you specify the region in which your Auto Scaling Group is in. By default aws-ha-release assumes the "us-east-1" region.
`-t <elb_timeout>` - time, in seconds, in which an EC2 instance should be given to complete request processing prior to being terminated. Set this value high enough so that any requests sent through an ELB would have time to be completed by an EC2 instance. For example: if the ELB allows connections to stay open for 120 seconds then setting this value to 120 seconds allows an instance behind an ELB 120 seconds to complete all processing before being terminated. By default both an AWS ELB and aws-ha-release.sh utilize 60 seconds timeout period.
`-i <inservice_time_allowed>` - allows you to specify the number of seconds an EC2 instance is provided to come into service. By default EC2 instances are given 300 seconds to come into service - if aws-ha-release.sh notices that an instance has not come into service in 300 seconds it will exit and return an exit status of 79. If an EC2 instance and application combination requires more than 300 seconds to come "InService" from the perspective of an ELB then this value should be set to a greater number.
# Additional Information:
Author: Colin Johnson / colin@cloudavail.com
Date: 2012-12-09
Version 0.1
License Type: GNU GENERAL PUBLIC LICENSE, Version 3
