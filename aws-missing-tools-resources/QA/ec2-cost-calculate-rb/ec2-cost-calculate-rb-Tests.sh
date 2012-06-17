#!/bin/bash
#set EC2CC_RB_APPLICATION prior to running
EC2CC_RB_APPLICATION=/Temp/aws-missing-tools/ec2-cost-calculate-rb/ec2-cost-calculate.rb
echo
echo " -Test: Credentials File Checking"
echo " -Test: Condition - Prerequisite File Does Not Exist"
AWS_CREDENTIAL_FILE_BAK=$AWS_CREDENTIAL_FILE #backup of credential location
export AWS_CREDENTIAL_FILE=/var/tmp/nofile.txt
$EC2CC_RB_APPLICATION
echo "Exit Code: $?"
echo " -Test Condition: Prerequisite Success"
export AWS_CREDENTIAL_FILE=$AWS_CREDENTIAL_FILE_BAK
$EC2CC_RB_APPLICATION
echo

##### Simple Run Test
echo " -Test: Simple Execution"
$EC2CC_RB_APPLICATION
echo "Exit Code: $?"
##### Invalid Options Provided
$EC2CC_RB_APPLICATION --option
echo "Exit Code: $?"
##### Invalid Options Provided
$EC2CC_RB_APPLICATION --option invalid
echo "Exit Code: $?"
echo
echo " -Test: Status Checking - Status Running"
$EC2CC_RB_APPLICATION --status running
echo "Exit Code: $?"
echo " -Test: Status Checking - Status All"
$EC2CC_RB_APPLICATION --status all
echo "Exit Code: $?"
echo " -Test: Status Checking - Status Invalid"
$EC2CC_RB_APPLICATION --status invalid
echo "Exit Code: $?"
echo
echo " -Test: Region Checking - Region us-east-1"
$EC2CC_RB_APPLICATION --region us-east-1
echo "Exit Code: $?"
echo " -Test: Region Checking - Region all"
$EC2CC_RB_APPLICATION --region all
echo "Exit Code: $?"
echo " -Test: Region Checking - Region invalid"
$EC2CC_RB_APPLICATION --region invalid
echo "Exit Code: $?"
echo
echo " -Test: Output Checking - Output Screen"
$EC2CC_RB_APPLICATION --output screen
echo "Exit Code: $?"
echo " -Test: Output Checking - Output File"
echo " -Test: Output Checking - Output File Exists"
$EC2CC_RB_APPLICATION --output file
echo "Exit Code: $?"
echo " -Test: Output Checking - Output File Doesn't Exist, Custom Location"
$EC2CC_RB_APPLICATION --output file --file ~/ec2cc_ooutput.txt
echo "Exit Code: $?"
echo " -Test: Output Checking - Output File Exists, Custom Location"
$EC2CC_RB_APPLICATION --output file file ~/ec2cc_ooutput.txt
echo "Exit Code: $?"
echo
echo " -Test: Period Checking - Period Day"
$EC2CC_RB_APPLICATION --period day
echo "Exit Code: $?"
echo " -Test: Period Checking - Period Invalid"
$EC2CC_RB_APPLICATION --period invalid
echo "Exit Code: $?"
echo
echo " -Test: Seperator Checking - Seperator ;"
$EC2CC_RB_APPLICATION --seperator \;
echo "Exit Code: $?"