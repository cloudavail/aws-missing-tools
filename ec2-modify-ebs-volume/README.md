# Introduction:
ec2-modify-ebs-volume.py was created to modify an EBS volumes attached to a running instance. The typical use case would be to increase the size of the EBS device or to change the volume type from standard to provisioned iops. The script follows the procedure detailed in http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-expand-volume.html. The script does not change the file system on the volume itself - this is left up to the user although some operating systems may automatically grow the file system to the size of a given volume.
# Directions For Use:
## Examples of Use:

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --volume-size 60
the above example would modify the root device of i-6702f11d to be 60 GB in size.

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --device /dev/sdf --volume-size 60
the above example would modify the /dev/sdf device to be 60 GB in size.

    ./ec2-modify-ebs-volume.py --instance-id i-6702f11d --volume-type io1 --iops 527
the above example would modify the root device of i-6702f11d to a provisioned iops volume with 527 iops performance.
## Required Parameters:
ec2-modify-ebs-volume.py requires the `--instance-id` parameter.
## Optional Parameters:
optional parameters are available by running `ec2-modify-ebs-volume.py --help`.
# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2013-11-18
- Version 0.1
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
