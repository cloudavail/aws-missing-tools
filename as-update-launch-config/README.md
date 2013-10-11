# Introduction:
as-update-launch-config was created to modify an Auto Scaling Group's Launch Configuration. The most typical use case is to change the size of instance used by an Auto Scaling Group, although as-update-launch-config can also be used to update the storage type, user-data or AMI used by a Launch Config (and hence, an Auto Scaling Group).
# Directions For Use:
## Example of Use:
    as-update-launch-config -a my-scaling-group -i m1.small -u /home/cjohnson/web-server-user-data.txt
the above example would modify the Auto Scaling Group "my-scaling-group" to use an m1.small EC2 Instance Type with the user-data available at /home/cjohnson/web-server-user-data.txt - note that this would also use an Amazon Linux AMI by default. The three parameters -a -i and -u are required for operation, as explained in the section "Required Parameters."
## Required Parameters:
as-update-launch-config requires the following three arguments:

`-a <auto-scaling-group-name>` - the name of the Auto Scaling Group that you wish to modify.

`-i <instance-type>` - the EC Instance Type you wish to switch use - for example -i m1.small would mean all future instances are launched as m1.small EC2 Instances.

`-u <user-data>` - path to the user-data file that the Auto Scaling Group's Launch Configuration should use.
## Optional Parameters:
`-b <bits>` if you specify a t1.micro, m1.small, m1.medium or c1.medium EC2 Instance Type you must specify either a 32-bit or 64-bit platform. This parameter is valid only for the t1.micro, m1.small, m1.medium and c1.medium instance types.

`-r <region>` - allows you specify the region in which your Auto Scaling Group and Launch Configuration are in.

`-p <preview>` - set to "true" if you wish to preview output rather than execute. Useful for testing.

`-s <storage>` - set to ebs if you wish to use an EBS backed AMI or s3 if you wish to use an s3 backed AMI. With no input, ebs is selected by default.

`-m <AMI>` - allows you specify the AMI that you desire your Auto Scaling Group's Launch Configuration to use.
# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2012-09-12
- Version 0.5
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
