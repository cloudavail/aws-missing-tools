#!/bin/bash
#sets path = to /dev/null
AWS_MISSING_TOOLS_PATH=/Temp/aws-missing-tools/as-update-launch-config/
echo
echo " -Test: Prerequisite Checking"
echo " -Test: Prerequisite Fail"
PATH_BAK=$PATH #backup of current path
export PATH=/dev/null
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh
echo "Exit Code: $?"
echo " -Test: Prerequisite Success"
PATH=$PATH_BAK
export PATH
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh
echo

##### Instance Type Test
echo " -Test: Instance Type Testing"
echo " -Test: Calling without an Instance Type"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh
echo "Exit Code: $?"
echo " -Test: Calling without an Instance Type"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i
echo "Exit Code: $?"
echo " -Test: Calling without an Invalid Instance Type"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.micro
echo "Exit Code: $?"
echo " -Test: Calling with a Valid Instance Type:"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small
echo "Exit Code: $?"

##### User-Data Test
echo
echo " -Test: User-Data Testing"
echo " -Test: Calling without user-data"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small
echo "Exit Code: $?"
echo " -Test: Calling without user-data option"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -u
echo "Exit Code: $?"
echo " -Test: Calling with a valid user-data option"
touch /Temp/touch.txt
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -u /Temp/touch.txt
echo "Exit Code: $?"

##### t1.micro test
echo
echo " -Test: t1.micro Bit Depth Testing"
echo " -Test: Calling with a t1.micro instance type and no bit depth"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i t1.micro
echo "Exit Code: $?"
echo
echo " -Test: t1.micro Bit Depth Testing"
echo " -Test: Calling with a t1.micro instance type and an empty bit depth"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i t1.micro -b
echo "Exit Code: $?"
echo
echo " -Test: t1.micro Bit Depth Testing"
echo " -Test: Calling with a t1.micro instance type and 32 bit depth"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i t1.micro -b 32
echo "Exit Code: $?"
echo
echo " -Test: t1.micro Bit Depth Testing"
echo " -Test: Calling with a t1.micro instance type and 64 bit depth"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i t1.micro -b 64
echo "Exit Code: $?"
echo
echo " -Test: t1.micro Bit Depth Testing"
echo " -Test: Calling with a t1.micro instance type and 33 bit depth"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i t1.micro -b 33
echo "Exit Code: $?"


##### Auto Scaling Group Test
echo
echo " -Test: Auto Scaling Group Testing"
echo " -Test: Calling without an Auto Scaling Group"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -b 32 -u /Temp/touch.txt
echo "Exit Code: $?"
echo " -Test: Calling without an Auto Scaling Group option."
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -b 32 -u /Temp/touch.txt -a
echo "Exit Code: $?"
echo " -Test: Calling with an invalid Auto Scaling Group"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -b 32 -u /Temp/touch.txt -a doesntexist
echo "Exit Code: $?"
echo " -Test: Calling with a valid Auto Scaling Group"
as-create-launch-config amt-test-01 --image-id ami-31814f58 --instance-type t1.micro --key amt-test-01 --group amt-test-01
as-create-auto-scaling-group amt-test-01 --min-size 0 --max-size 0 --desired-capacity 0 --launch-configuration amt-test-01 --availability-zones us-east-1a
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -b 32 -u /Temp/touch.txt -a amt-test-01
echo "Exit Code: $?"
echo " -Test: Calling with a valid Auto Scaling Group and a Launch-Config amt-test-1 Already Created"
${AWS_MISSING_TOOLS_PATH}as-update-launch-config.sh -i m1.small -b 32 -u /Temp/touch.txt -a amt-test-01
echo "Exit Code: $?"
as-delete-auto-scaling-group amt-test-01 -f
as-delete-launch-config amt-test-01 -f