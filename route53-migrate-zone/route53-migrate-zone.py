#!/usr/bin/python
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-06-08
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#

import boto.route53  # import boto.route53 (not just boto) - need to import correct module
import ConfigParser  # import ConfigParser - used for getting configuration
import re  # import re used to find/replace zone
import sys  # used to exit python program with exit code
import os  # used to get app_name
import logging  # used to write out log events - events that are neither required output nor error
import argparse  # used to gather user input


def commit_record_changeset(destination_zone_record_changeset):
    try:
        destination_zone_record_changeset.commit()
    except boto.route53.exception.DNSServerError, error:
        sys.stdout.write("An error occured when attempting to commit records to the zone \"" + destination_zone_name + "\"\n")
        sys.stdout.write("The error message given was: " + error.error_message + ".\n")
        exit(69)


def diff_record(record_a, record_a_object, record_b, record_b_object):
    compare_values = ["type", "ttl", "resource_records", "alias_hosted_zone_id", "alias_dns_name", "identifier", "weight", "region"]
    diff_record_result = False

    for value in compare_values:
        if getattr(record, value) != getattr(destination_zone_existing_resource_record_dict[record.name], value):
            diff_record_result = True
    return diff_record_result

app_name = os.path.basename(__file__)

parser = argparse.ArgumentParser()
parser.add_argument("--loglevel", help="set the log level when running route53-migrate-zone.")
parser.add_argument("--config", help="choose the configuration file to be used when running route53-migrate-zone.", default='config.ini')
args = parser.parse_args()

if args.loglevel is not None:
    log_level = str.upper(args.loglevel)
    logging.basicConfig(level=log_level)

config_file_path = args.config
config = ConfigParser.ConfigParser()
config.read(config_file_path)

#functions: currently supports newzone - the functions are set automatically by the route53-migrate-zone script
functions = []

#the source_zone user credentials should be read-only
source_zone_access_key = config.get("source_zone_values", "source_zone_access_key")
source_zone_secret_key = config.get("source_zone_values", "source_zone_secret_key")
source_zone_name = config.get("source_zone_values", "source_zone_name")
#
destination_zone_access_key = config.get("destination_zone_values", "destination_zone_access_key")
destination_zone_secret_key = config.get("destination_zone_values", "destination_zone_secret_key")
destination_zone_name = config.get("destination_zone_values", "destination_zone_name")
#best would be to retreive the destination_zone_id using destination_zone_name
destination_zone_id = config.get("destination_zone_values", "destination_zone_id")

record_types_to_migrate = ["A", "CNAME", "MX", "TXT"]

if source_zone_name != destination_zone_name:
    print app_name + " will rewrite domain names ending in \"" + source_zone_name + "\" to domain names ending in \"" + destination_zone_name + "\""
    functions.append("newzone")

#creates Route53Connection Object
source_connection = boto.route53.Route53Connection(aws_access_key_id=source_zone_access_key, aws_secret_access_key=source_zone_secret_key)
destination_connection = boto.route53.Route53Connection(aws_access_key_id=destination_zone_access_key, aws_secret_access_key=destination_zone_secret_key)

#create connection to source_zone
try:
    source_zone = source_connection.get_zone(source_zone_name)
except boto.route53.exception.DNSServerError, error:
    sys.stderr.write("An error occured when attempting to create a connection to AWS.\n")
    sys.stderr.write("The error message given was: " + error.error_message + ".\n")
    exit(69)

#create connection to destination_zone
try:
    destination_zone = destination_connection.get_zone(destination_zone_name)
except boto.route53.exception.DNSServerError, error:
    sys.stderr.write("An error occured when attempting to create a connection to AWS.\n")
    sys.stderr.write("The error message given was: " + error.error_message + ".\n")
    exit(69)

#creates ResourceRecordSets object named source_zone_records (ResourceRecordSets = a collection of resource records)
source_zone_records = source_zone.get_records()
#creates ResourceRecordSets object named destination_zone_records (ResourceRecordSets = a collection of resource records)
destination_zone_records = destination_zone.get_records()

#resource_record_dict will be used to store all resource records that should be transferred
resource_record_dict = {}
#destination_zone_existing_resource_record_dict will be used to store all resource records that exist in destination zone
destination_zone_existing_resource_record_dict = {}

#creates a set of changes to be delivered to Route53
destination_zone_record_changeset = boto.route53.record.ResourceRecordSets(destination_connection, destination_zone_id)

for record in destination_zone_records:
    destination_zone_existing_resource_record_dict[record.name] = record

#counts of records - should be replaced by dictionary
examined_record_count = 0
migrated_record_count = 0
existing_records_in_destination_zone_count = 0
identical_records_in_destination_zone_count = 0
different_records_in_destination_zone_count = 0
uncommitted_change_elements = 0

#get records from source_zone
for record in source_zone_records:
    if record.type in record_types_to_migrate:
        if "newzone" in functions:
            destination_record = re.sub(source_zone_name, destination_zone_name, record.name)
            logging.info("Record \"" + record.name + "\" will be rewritten as \"" + destination_record + "\".")
            record.name = destination_record
        #test if record exists in destination_zone
        if record.name in destination_zone_existing_resource_record_dict:
            existing_records_in_destination_zone_count += 1
            #compare records in source_domain and destination_domain, store result as diff_result
            diff_result = diff_record(record.name, record, record.name, destination_zone_existing_resource_record_dict)
            if diff_result is True:
                different_records_in_destination_zone_count += 1
                logging.info("Record \"" + record.name + "\" exists in source zone \"" + source_zone_name + "\" and destination zone \"" + destination_zone_name + "\" and is different.")
            elif diff_result is False:
                identical_records_in_destination_zone_count += 1
                logging.info("Record \"" + record.name + "\" exists in source zone \"" + source_zone_name + "\" and destination zone \"" + destination_zone_name + "\" and is identical.")
            else:
                sys.stderr.write("Diff of record " + record.name + " failed.\n")
                exit(70)
        else:
            resource_record_dict[record.name] = boto.route53.record.Record(name=record.name, type=record.type, ttl=record.ttl, resource_records=record.resource_records, alias_hosted_zone_id=record.alias_hosted_zone_id, alias_dns_name=record.alias_dns_name, identifier=record.identifier, weight=record.weight, region=record.region)

for record in resource_record_dict:
    examined_record_count += 1
    #if record is an alias record we are not supporting yet
    if resource_record_dict[record].alias_dns_name is not None:
        logging.info("Record \"" + resource_record_dict[record].name + "\" is an alias record set and will not be migrated. " + app_name + " does not currently support alias record sets.")
    else:
        uncommitted_change_elements += 1
        destination_zone_record_changeset.add_change_record("CREATE", resource_record_dict[record])
    logging.debug("Uncommitted Record Count:" + str(uncommitted_change_elements))
    #if there are 99 uncomitted change elements than they must be committed - Amazon only accepts up to 99 change elements at a given time
    #if the number of examined records is equal to the number of records then we can commit as well - we are now done examing records
    if uncommitted_change_elements >= 99 or examined_record_count == len(resource_record_dict):
        logging.info("Flushing Records:" + str(uncommitted_change_elements))
        commit_record_changeset(destination_zone_record_changeset)
        migrated_record_count += uncommitted_change_elements
        uncommitted_change_elements = 0
        destination_zone_record_changeset = None
        destination_zone_record_changeset = boto.route53.record.ResourceRecordSets(destination_connection, destination_zone_id)

print "Summary:"
print "Records migrated from source zone: \"" + source_zone_name + "\" to destination zone: \"" + destination_zone_name + "\"."
print "Record types selected for migration: " + str(record_types_to_migrate) + "."
print "Records examined: " + str(examined_record_count)
print "Records migrated: " + str(migrated_record_count) + "."
print "Records not migrated because they exist in destination zone \"" + destination_zone_name + "\": " + str(existing_records_in_destination_zone_count)
print "Records that exist in source zone \"" + source_zone_name + "\" and destination zone \"" + destination_zone_name + "\" and are identical: " + str(identical_records_in_destination_zone_count)
print "Records that exist in source zone \"" + source_zone_name + "\" and destination zone \"" + destination_zone_name + "\" and are different: " + str(different_records_in_destination_zone_count)
