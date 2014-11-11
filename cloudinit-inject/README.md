# Introduction:
cloudinit-inject was created to provide a method of injecting user-data scripts into CloudFormation files. An example use case would be a CloudFormation file that contains either an EC2 or LaunchConfig type resource that contains a user-data property. Rather than painstakingly copy and paste the userdata script (oftentimes a shell script) into the userdata property, cloudinit-inject can do this instead.

# Directions For Use:
## Preparation for Use:
For each EC2 or LaunchConfig resource in a CloudFormation file create a shell script named `$resourcename_userdata.sh` where $resourcename is the name of a given resource. When running `cloudinit-inject-userdata.py` these userdata files will be associated with the similarly named resource and injected into the given resource's "userdata" property. For example, if an EC2 resource named `my_ec2_instance` is found in a CloudFormation file, `cloudinit-inject-userdata.py` will attempt to locate a file named `my_ec2_instance_userdata.sh` and inject this into the given CloudFormation file.
## Example of Use:
Execute `cloudinit-inject-userdata.py` as follows `cloudinit-inject-userdata.py --input my_CloudFormation_file.json --input my_CloudFormation_file_output.json`

## Optional Parameters:
parameters are available by running `cloudinit-inject-userdata.py --help`.

# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2014-11-11
- Version 0.1
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
