# AWS HA Release, bash

## Introduction:
aws-ha-release.sh is a bash script that allows the high-availability / no downtime replacement of all EC2 Instances in an Auto Scaling Group that is behind an Elastic Load Balancer. AWS HA Release also exists as a Ruby script and is recommended if use is possible.

## Potential Use:
Some potential uses for aws-ha-release are listed below:

1. Delivery of new code - if your deployment scheme utilizes the termination of EC2 instances in order to release new code aws-ha-release provides an automated way to do this without incurring any downtime.

2. Return of all EC2 instances to "pristine" or "vanilla" state - all older EC2 instances can be replaced with newer EC2 instances.

## Directions For Use:
### Example of Use:

```
aws-ha-release.sh -a my-scaling-group
```

the above example would terminate and replace each EC2 Instance in the Auto Scaling group "my-scaling-group" with a new EC2 Instance.

### Required Options:
aws-ha-release.sh requires the following option:

`-a, --as-group-name GROUP_NAME` - the name of the Auto Scaling Group for which you wish to perform a high availability release.

### Optional Parameters:
`-r, --region REGION` - allows you specify the region in which your Auto Scaling Group is in. By default aws-ha-release assumes the "us-east-1" region.

`-t, --elb-timeout TIME` - time, in seconds, in which an EC2 instance should be given to complete request processing prior to being terminated. Set this value high enough so that any requests sent through an ELB would have time to be completed by an EC2 instance. For example: if the ELB allows connections to stay open for 120 seconds then setting this value to 120 seconds allows an instance behind an ELB 120 seconds to complete all processing before being terminated. By default both an AWS ELB and aws-ha-release.sh utilize 60 seconds timeout period.

`-i, --inservice-time-allowed TIME` - allows you to specify the number of seconds an EC2 instance is provided to come into service. By default EC2 instances are given 300 seconds to come into service - if aws-ha-release.sh notices that an instance has not come into service in 300 seconds it will exit and return an exit status of 79. If an EC2 instance and application combination requires more than 300 seconds to come "InService" from the perspective of an ELB then this value should be set to a greater number.

`-m, --min-inservice-time TIME` - Minimum time an instance must be in service before it is considered healthy (seconds). Default is 30 seconds. See [issue 32](https://github.com/colinbjohnson/aws-missing-tools/issues/32).

`-o, --aws_access_key AWS_ACCESS_KEY` - your AWS Access Key. If not specified, must be available as an environment variable called AWS_ACCESS_KEY. If you specify the secret key, you must also specify the access key.

`-s, --aws_secret_key AWS_SECRET_KEY` - your AWS Secret Key. If not specified, must be available as an environment variable called AWS_SECRET_KEY. If you specify the access key, you must also specify the secret key.

# Additional Information:
- Authors: Colin Johnson / colin@cloudavail.com, Anuj Biyani / abiyani@lytro.com
- Date: 2013-10-11
- Version 0.0.1
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
