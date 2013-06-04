#!/usr/bin/python
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-06-03
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3
#

import boto.route53  # import boto.route53 (not just boto) - need to import correct module
import ConfigParser  # import ConfigParser - used for getting configuration
import re  # import re used to find/replace zone
import sys  # used to exit python program with exit code
import os  # used to get app_name


def commit_record_changeset(to_zone_record_changeset):
    try:
        to_zone_record_changeset.commit()
    except boto.route53.exception.DNSServerError, error:
        sys.stdout.write("An error occured when attempting to commit records to the zone \"" + to_zone_name + "\"\n")
        sys.stdout.write("The error message given was: " + error.error_message + ".\n")
        exit(69)


def diff_record(record_a, record_a_object, record_b, record_b_object):
    compare_values = ["type", "ttl", "resource_records", "alias_hosted_zone_id", "alias_dns_name", "identifier", "weight", "region"]
    diff_record_result = False

    for value in compare_values:
        if getattr(record, value) != getattr(to_zone_existing_resource_record_dict[record.name], value):
            diff_record_result = True
    return diff_record_result

app_name = os.path.basename(__file__)
config = ConfigParser.ConfigParser()
config.read('config.ini')
#functions: currently supports newzone - the functions are set automatically by the route53-migrate-zone script
functions = []

#the from_zone user credentials should be read-only
from_access_key = config.get("from_zone_values", "from_access_key")
from_secret_key = config.get("from_zone_values", "from_secret_key")
from_zone_name = config.get("from_zone_values", "from_zone_name")
#
to_access_key = config.get("to_zone_values", "to_access_key")
to_secret_key = config.get("to_zone_values", "to_secret_key")
to_zone_name = config.get("to_zone_values", "to_zone_name")
#best would be to retreive the to_zone_id using to_zone_name
to_zone_id = config.get("to_zone_values", "to_zone_id")

record_types_to_migrate = ["A", "CNAME", "MX", "TXT"]

if from_zone_name != to_zone_name:
    print app_name + " will rewrite domain names ending in \"" + from_zone_name + "\" to domain names ending in \"" + to_zone_name + "\""
    functions.append("newzone")

#creates Route53Connection Object
from_connection = boto.route53.Route53Connection(aws_access_key_id=from_access_key, aws_secret_access_key=from_secret_key)
to_connection = boto.route53.Route53Connection(aws_access_key_id=to_access_key, aws_secret_access_key=to_secret_key)

#create connection to from_zone
try:
    from_zone = from_connection.get_zone(from_zone_name)
except boto.route53.exception.DNSServerError, error:
    sys.stdout.write("An error occured when attempting to create a connection to AWS.\n")
    sys.stdout.write("The error message given was: " + error.error_message + ".\n")
    exit(1)

#create connection to to_zone
try:
    to_zone = to_connection.get_zone(to_zone_name)
except boto.route53.exception.DNSServerError, error:
    sys.stdout.write("An error occured when attempting to create a connection to AWS.\n")
    sys.stdout.write("The error message given was: " + error.error_message + ".\n")
    exit(1)

#creates ResourceRecordSets object named from_zone_records (ResourceRecordSets = a collection of resource records)
from_zone_records = from_zone.get_records()
#creates ResourceRecordSets object named to_zone_records (ResourceRecordSets = a collection of resource records)
to_zone_records = to_zone.get_records()

#resource_record_dict will be used to store all resource records that should be transferred
resource_record_dict = {}
#to_zone_existing_resource_record_dict will be used to store all resource records that should be transferred
to_zone_existing_resource_record_dict = {}

#creates a set of changes to be delivered to Route53
to_zone_record_changeset = boto.route53.record.ResourceRecordSets(to_connection, to_zone_id)

for record in to_zone_records:
    to_zone_existing_resource_record_dict[record.name] = record

#counts of records - should be replaced by dictionary
uncommitted_change_elements = 0
processed_record_count = 0
migrated_record_count = 0
existing_records_in_to_zone_count = 0
identical_records_in_to_zone_count = 0
different_records_in_to_zone_count = 0

#get records from from_zone
for record in from_zone_records:
    if record.type in record_types_to_migrate:
        if "newzone" in functions:
            #print "Existing Record Name: " + record.name
            record.name = re.sub(from_zone_name, to_zone_name, record.name)
            #print "Modified Record Name: " + record.name
        #test if record exists in to_zone
        if record.name in to_zone_existing_resource_record_dict:
            existing_records_in_to_zone_count += 1
            #compare records in from_domain and to_domain, store result as diff_result
            diff_result = diff_record(record.name, record, record.name, to_zone_existing_resource_record_dict)
            if diff_result is True:
                different_records_in_to_zone_count += 1
                sys.stdout.write("Record \"" + record.name + "\" exists in both \"" + from_zone_name + "\" and \"" + to_zone_name + "\" and is different.\n")
            elif diff_result is False:
                identical_records_in_to_zone_count += 1
                sys.stdout.write("Record \"" + record.name + "\" exists in both \"" + from_zone_name + "\" and \"" + to_zone_name + "\" and is identical.\n")
            else:
                sys.stdout.write("Diff of record " + record.name + " failed.\n")
                exit(1)
        else:
            resource_record_dict[record.name] = boto.route53.record.Record(name=record.name, type=record.type, ttl=record.ttl, resource_records=record.resource_records, alias_hosted_zone_id=record.alias_hosted_zone_id, alias_dns_name=record.alias_dns_name, identifier=record.identifier, weight=record.weight, region=record.region)

for record in resource_record_dict:
    processed_record_count += 1
    #if record is an alias record we are not supporting yet
    if resource_record_dict[record].alias_dns_name is not None:
        sys.stdout.write("Record \"" + resource_record_dict[record].name + "\" is an alias record set and will not be migrated. " + app_name + " does not currently support alias record sets.\n")
    else:
        uncommitted_change_elements += 1
        to_zone_record_changeset.add_change_record("CREATE", resource_record_dict[record])
    #DEBUG: print "Uncommitted Record Count:" + str(uncommitted_change_elements)
    #if there are 99 uncomitted change elements than they must be committed - Amazon only accepts up to 99 change elements at a given time
    #if the number of examined records is equal to the number of records then we can commit as well - we are now done examing records
    if uncommitted_change_elements >= 99 or processed_record_count == len(resource_record_dict):
        #DEBUG: print "Flushing Records:" + str(uncommitted_change_elements)
        commit_record_changeset(to_zone_record_changeset)
        migrated_record_count += uncommitted_change_elements
        uncommitted_change_elements = 0
        to_zone_record_changeset = None
        to_zone_record_changeset = boto.route53.record.ResourceRecordSets(to_connection, to_zone_id)

print "Summary:"
print "Records Migrated from zone: \"" + from_zone_name + "\" to zone: \"" + from_zone_name + "\"."
print "Types of Records Selected for Migration: " + str(record_types_to_migrate) + "."
print "Records processed (records such as Alias records may be processed but not migrated): " + str(processed_record_count)
print "Records migrated: " + str(migrated_record_count) + "."
print "Records not migrated because they already exist in zone \"" + to_zone_name + "\": " + str(existing_records_in_to_zone_count)
print "Records that exist in both \"" + from_zone_name + "\" and \"" + to_zone_name + "\" and are identical: " + str(identical_records_in_to_zone_count)
print "Records that exist in both \"" + from_zone_name + "\" and \"" + to_zone_name + "\" and are different: " + str(different_records_in_to_zone_count)
