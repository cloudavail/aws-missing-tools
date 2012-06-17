#!/bin/bash
#sets path = to /dev/null
AWS_MISSING_TOOLS_PATH="/Temp/aws-missing-tools/as-apply-alarms/"
echo
echo " -Test: Prerequisite Checking"
echo " -Test: Prerequisite Fail"
PATH_BAK=$PATH #backup of current path
export PATH=/dev/null
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Prerequisite Success"
PATH=$PATH_BAK
export PATH
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh
echo "Exit Code: $?"

##### Region Test
echo
echo " -Test: Region Testing"
echo " -Test: Calling without region."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -a
echo "Exit Code: $?"
echo " -Test: Calling without a region option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -r -a
echo "Exit Code: $?"
echo " -Test: Calling with an invalid region option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -r california
echo "Exit Code: $?"
echo " -Test: Calling with a valid region option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -r us-west-2
echo "Exit Code: $?"

##### Evaluation Period Test
echo
echo " -Test: Evaluation Period Testing"
echo " -Test: Calling without an Evaluation Period."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Calling without an Evaluation Period option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -e
echo "Exit Code: $?"
echo " -Test: Calling with an invalid (low) Evaluation Period option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -e 0
echo "Exit Code: $?"
echo " -Test: Calling with an invalid (high) Evaluation Period option."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -e 100
echo "Exit Code: $?"
echo " -Test: Calling with a valid Evaluation Period option"
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -e 1
echo "Exit Code: $?"

##### ASG Tests
echo
echo " -Test: Auto Scaling Group Testing"
echo " -Test: Calling without Auto Scaling Group."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Calling with no Auto Scaling Group defined."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -g
echo "Exit Code: $?"
echo " -Test: Calling with an invalid Auto Scaling Group."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -g california
echo "Exit Code: $?"
echo " -Test: Calling with an invalid Auto Scaling Group and all Auto Scaling Groups."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -g california -a
echo "Exit Code: $?"
as-create-launch-config amt-test-01 --image-id ami-31814f58 --instance-type t1.micro --key amt-test-01 --group amt-test-01
as-create-auto-scaling-group amt-test-01 --min-size 0 --max-size 0 --desired-capacity 0 --launch-configuration amt-test-01 --availability-zones us-east-1a
as-create-launch-config amt-test-02 --image-id ami-31814f58 --instance-type t1.micro --key amt-test-01 --group amt-test-01
as-create-auto-scaling-group amt-test-02 --min-size 0 --max-size 0 --desired-capacity 0 --launch-configuration amt-test-02 --availability-zones us-east-1a
echo " -Test: Calling with a valid Auto Scaling Group and all Auto Scaling Groups."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -g amt-test-01 -a
echo "Exit Code: $?"
echo " -Test: Calling with a valid Auto Scaling Group."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -g amt-test-01
echo "Exit Code: $?"
echo " -Test: Calling with all Auto Scaling Groups."
${AWS_MISSING_TOOLS_PATH}as-apply-alarms.sh -a
echo "Exit Code: $?"

as-delete-auto-scaling-group amt-test-01 -f
as-delete-launch-config amt-test-01 -f
as-delete-auto-scaling-group amt-test-02 -f
as-delete-launch-config amt-test-02 -f

