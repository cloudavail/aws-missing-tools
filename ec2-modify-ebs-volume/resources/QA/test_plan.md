# Environment / AWS Resource Requirements
 - No AWS / Boto credentials provided
 - Invalid AWS / Boto credentials provided
 - Instance Terminate on Shutdown not "Stop"
 - Instance uses Instant Store for device

# Create Instance

# Provide Invalid Inputs
 - --invalid-option provided = exit
    ./ec2-modify-ebs-volume.py --invalid-option

 - --instance-id not valid = exit
    ./ec2-modify-ebs-volume.py --instance-id i-e780879z

 - --region not valid = exit
    ./ec2-modify-ebs-volume.py --region us-cali-01 --instance-id ${instance_id}

 - --log-level not valid = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --log-level none

 - --volume-size greater than 1024 = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 52777

 - --volume-size less than existing volume = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 6
 - --volume-size not a valid number: 10 GB = exit
     ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size really_big_volume

 - --volume-type 'standard' and --iops specified = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-type standard --iops 527

 - --iops is less than aws_limit['min_iops'] = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-type io1 --iops 12
 - --iops is greater than aws_limit['max_iops'] = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-type io1 --iops 94118
 - --iops is greater than aws_limits['max_iops_size_multiplier'] x --volume-size = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 21 --volume-type io1 --iops 1977   
 - --iops is greater than aws_limits['max_iops_size_multiplier'] x existing volume size and --volume-size not set = exit
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-type io1 --iops 1977
 - --volume-type 'standard' and existing volume type is 'io1' = log a warning


# Resize EBS
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 10

# Move to Provisioned IOPS from Standard
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 10 --volume-type io1 = fails
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 10 --volume-type io1 --iops 112

# Move to Standard from Provisioned IOPS
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 10 --volume-type standard

# Move to Larger Volume Size, from Standard to Provisioned IOPS
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 12 --volume-type io1 --iops 112

# Move to Larger Volume Size, from Provisioned IOPS to Standard
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 14 --volume-type standard

# Move to Larger Volume Size, from Standard to Standard
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 16

# Move to Larger Volume Size, from Provisioned IOPS to Provisioned IOPs
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-size 18 --volume-type io1 --iops 112

# Move to increased Provisioned IOPS
    ./ec2-modify-ebs-volume.py --instance-id ${instance_id} --volume-type io1 --iops 127
