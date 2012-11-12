#!/bin/bash
#EC2_HOME required for EC2 API Tools
export EC2_HOME=/opt/aws/apitools/ec2
#JAVA_HOME required for EC2 API Tools
export JAVA_HOME=/usr/lib/jvm/jre
#export PATH=/bin is required for cut, date, grep
#export PATH=/opt/aws/bin/ is required for EC2 API Tools
#typical system path PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:/home/ec2-user/bin
export PATH=/bin:/opt/aws/bin/
export AWS_ACCESS_KEY=<your_access_key>
export AWS_SECRET_KEY=<your_secret_key>
