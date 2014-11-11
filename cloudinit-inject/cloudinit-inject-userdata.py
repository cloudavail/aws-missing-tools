#!/usr/bin/env python
import argparse
import json
import logging


def get_ec2_userdata(ec2_resourse_name, userdata_dir):
    # Load the cloudinit_filename
    userdate_filename = str("{!s}/{!s}_userdata.sh".format(userdata_dir, ec2_resourse_name))
    try:
        userdata_file = open(userdate_filename)
        logging.debug('located userdata at {!s}'.format(userdate_filename))
    except IOError as error:
        logging.critical('failed to locate userdata at {!s}'.format(userdate_filename))
        logging.critical('error: {!s}'.format(error))
        exit(66)
    #userdata_value is a list containing two items: the fn::join value and the value of the data to be added
    userdata_script = userdata_file.readlines()
    userdata = {unicode("Fn::Base64"): {unicode("Fn::Join"): userdata_script}}
    return userdata


parser = argparse.ArgumentParser()
parser.add_argument("--input", help="path to CloudFormation Input File.",
                    default="./stack.json", dest='cf_input')
parser.add_argument("--output",
                    help="path where CloudFormation Ouput File should be written.",
                    default="./stack_output.json", dest='cf_output')
parser.add_argument("--user-data-dir",
                    help="search path for userdata Files.", default=".",
                    dest='userdata_dir')
parser.add_argument("--log-level",
                    help="log-level which program should be run at",
                    default="info", dest='log_level')
args = parser.parse_args()

log_format = '%(message)s'
log_level = str.upper(args.log_level)
logging.basicConfig(level=log_level, format=log_format)

try:
    cloudformation_input_file = open(args.cf_input)
except IOError as error:
    logging.critical('error: {!s}'.format(error))
    exit(66)

cloudformation_dict = json.load(cloudformation_input_file)

for resource in cloudformation_dict["Resources"]:
    if (cloudformation_dict["Resources"][resource]["Type"] == "AWS::EC2::Instance" or
        cloudformation_dict["Resources"][resource]["Type"] == "AWS::AutoScaling::LaunchConfiguration"):
        logging.debug('found EC2 resource name: {!s}'.format(resource))
        ec2_userdata = get_ec2_userdata(resource, args.userdata_dir)
        cloudformation_dict["Resources"][resource]["Properties"]["UserData"] = ec2_userdata

cloudformation_target_file = open(args.cf_output, 'w')

json.dump(cloudformation_dict, cloudformation_target_file, indent=2, sort_keys=False)
