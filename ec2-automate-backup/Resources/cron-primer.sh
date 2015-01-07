#!/bin/bash -
# EC2_HOME required for EC2 API Tools
export EC2_HOME=/opt/aws/apitools/ec2
# JAVA_HOME required for EC2 API Tools
export JAVA_HOME=/usr/lib/jvm/jre
# export PATH=/bin is required for cut, date, grep
# export PATH=/opt/aws/bin/ is required for EC2 API Tools
# export PATH=/usr/bin is required for AWS Command Line Interface tools
# typical system path PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:/home/ec2-user/bin
export PATH=/bin:/usr/bin:/opt/aws/bin/

# AWS_ACCESS_KEY and AWS_SECRET_KEY needed for EC2 CLI tools
export AWS_ACCESS_KEY=<your_access_key>
export AWS_SECRET_KEY=<your_secret_key>

# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY needed for AWS CLI tools
export AWS_ACCESS_KEY_ID=<your_access_key>
export AWS_SECRET_ACCESS_KEY=<your_secret_key>

# AWS_CONFIG_FILE required for AWS Command Line Interface tools (f.e. ".aws")
export AWS_CONFIG_FILE=<aws_config_filename>

# the environment variables below (EC2_PRIVATE_KEY and EC2_CERT) are deprecated
# as of the release of EC2 API Tools 1.6.0.0 - it is recommended that users
# upgrade to a version of the EC2 API Tools equal to or greater than 1.6.0.0
# and use the environment variables AWS_ACCESS_KEY and AWS_SECRET_KEY instead.
# export EC2_PRIVATE_KEY=/path/to/your/private/key.pem
# export EC2_CERT=/path/to/your/cert.pem
