#!/bin/bash -
# export PATH=/bin is required for cut, date, grep
# export PATH=/usr/bin is required for AWS Command Line Interface tools
export PATH=/bin:/usr/bin

# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY needed for AWS CLI tools
export AWS_ACCESS_KEY_ID=<your_access_key>
export AWS_SECRET_ACCESS_KEY=<your_secret_key>

# AWS_CONFIG_FILE required for AWS Command Line Interface tools (f.e. ".aws")
export AWS_CONFIG_FILE=<aws_config_filename>
