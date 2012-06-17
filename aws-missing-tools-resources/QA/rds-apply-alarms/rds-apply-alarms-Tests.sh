#!/bin/bash
#sets path = to /dev/null
AWS_MISSING_TOOLS_PATH="/Temp/aws-missing-tools/rds-apply-alarms/"
echo
echo " -Test: Prerequisite Checking"
echo " -Test: Prerequisite Fail"
PATH_BAK=$PATH #backup of current path
export PATH=/dev/null
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Prerequisite Success"
PATH=$PATH_BAK
export PATH
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh
echo "Exit Code: $?"

##### Region Test
echo
echo " -Test: Region Testing"
echo " -Test: Calling without region."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -a
echo "Exit Code: $?"
echo " -Test: Calling without a region option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -r -a
echo "Exit Code: $?"
echo " -Test: Calling with an invalid region option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -r california
echo "Exit Code: $?"
echo " -Test: Calling with a valid region option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -r us-west-2
echo "Exit Code: $?"

##### Evaluation Period Test
echo
echo " -Test: Evaluation Period Testing"
echo " -Test: Calling without an Evaluation Period."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Calling without an Evaludation Period option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -e
echo "Exit Code: $?"
echo " -Test: Calling with an invalid (low) Evaluation Period option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -e 0
echo "Exit Code: $?"
echo " -Test: Calling with an invalid (high) Evaluation Period option."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -e 100
echo "Exit Code: $?"
echo " -Test: Calling with a valid Evaluation Period option"
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -e 1
echo "Exit Code: $?"

##### RDS Instance Tests
echo
echo " -Test: RDS Instance Testing"
echo " -Test: Calling without an RDS Instance."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh
echo "Exit Code: $?"
echo " -Test: Calling with no RDS Instance option defined."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -d
echo "Exit Code: $?"
echo " -Test: Calling with an invalid RDS Instance Group."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -d california
echo "Exit Code: $?"
rds-create-db-instance amt-test-01 --allocated-storage 5 --db-instance-class db.m1.small --engine mysql --master-user-password mj21s77 --master-username amttest01
sleep 300
echo " -Test: Calling with an invalid RDS Instance and all RDS Instances."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -d california -a
echo "Exit Code: $?"
echo " -Test: Calling with a valid RDS Instance and all RDS Instances."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -d amt-test-1 -a
echo "Exit Code: $?"
echo " -Test: Calling with a valid RDS Instance."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -d amt-test-01
echo "Exit Code: $?"
echo " -Test: Calling with all RDS Instances."
${AWS_MISSING_TOOLS_PATH}rds-apply-alarms.sh -a
echo "Exit Code: $?"
rds-delete-db-instance amt-test-01 -f --skip-final-snapshot