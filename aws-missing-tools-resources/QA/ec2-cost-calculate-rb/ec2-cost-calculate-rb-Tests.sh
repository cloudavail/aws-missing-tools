#!/bin/bash
#set EC2CC_RB_APPLICATION prior to running
EC2CC_RB_APPLICATION=/Temp/ec2-cost-calculate.rb
echo
echo " -Test: Credentials File Checking"
echo " -Test: Condition - Credential File Does Not Exist"
AWS_CREDENTIAL_FILE_BAK=$AWS_CREDENTIAL_FILE #backup of credential location
export AWS_CREDENTIAL_FILE=/var/tmp/nofile.txt
$EC2CC_RB_APPLICATION
echo "Exit Code: $?"
echo " -Test Condition: Credential File Success"
export AWS_CREDENTIAL_FILE=$AWS_CREDENTIAL_FILE_BAK
$EC2CC_RB_APPLICATION
echo
echo " -Test Condition: Credential File Custom Location Selected, File Does Not Exist"
$EC2CC_RB_APPLICATION --awscredentialfile /var/tmp/nofile.txt
echo "Exit Code: $?"
echo " -Test Condition: Credential File Custom Location Selected, File Exists, Incorrent Format"
tmpfile_bad_format=`mktemp /tmp/ec2cc.XXXXXX` || exit 1
echo "No Contents" >> $tmpfile_bad_format
$EC2CC_RB_APPLICATION --awscredentialfile $tmpfile_bad_format
rm -f $tmpfile
echo "Exit Code: $?"
echo " -Test Condition: Credential File From Custom Location Selected, File Exists, Correct Format"
tmpfile_good_format=`mktemp /tmp/ec2cc.XXXXXX` || exit 1
cp $AWS_CREDENTIAL_FILE $tmpfile_good_format
$EC2CC_RB_APPLICATION --awscredentialfile $tmpfile_good_format
rm -f $tmpfile_good_format
echo "Exit Code: $?"
##### Simple Run Test
echo " -Test: Simple Execution"
$EC2CC_RB_APPLICATION
echo "Exit Code: $?"
##### Invalid Options Provided
echo " -Test: Invalid Option Provided"
$EC2CC_RB_APPLICATION --option
echo "Exit Code: $?"
##### Invalid Options Provided
echo " -Test: Invalid Option Provided"
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