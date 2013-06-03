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

app_name = os.path.basename(__file__)
config = ConfigParser.ConfigParser()
config.read('config.ini')
#functions: newzone, new account, newzone and newaccount
functions = ["newzone", "newaccount"]

#these user credentials should be read-only
from_access_key = config.get("from_zone_values", "from_access_key")
from_secret_key = config.get("from_zone_values", "from_secret_key")
from_zone_name = config.get("from_zone_values", "from_zone_name")
#
to_access_key = config.get("to_zone_values", "to_access_key")
to_secret_key = config.get("to_zone_values", "to_secret_key")
to_zone_name = config.get("to_zone_values", "to_zone_name")
#best would be to retreive the to_zone_id using to_zone_name
to_zone_id = config.get("to_zone_values", "to_zone_id")

#creates Route53Connection Object
from_connection = boto.route53.Route53Connection(aws_access_key_id=from_access_key, aws_secret_access_key=from_secret_key)
to_connection = boto.route53.Route53Connection(aws_access_key_id=to_access_key, aws_secret_access_key=to_secret_key)
#creates a set of changes to be delivered to Route53
to_zone_record_changeset = boto.route53.record.ResourceRecordSets(to_connection, to_zone_id)

record_types_to_migrate = ["A", "CNAME", "MX", "TXT"]

#print out all records
try:
    from_zone = from_connection.get_zone(from_zone_name)
except boto.route53.exception.DNSServerError, error:
    sys.stdout.write("An error occured when attempting to create a connection to AWS.\n")
    sys.stdout.write("The error message given was: " + error.error_message + ".\n")
    exit(1)

from_zone_records = from_zone.get_records()
#resource_record_dict will be used to store all resource records
resource_record_dict = {}

#get records from from_zone
for record in from_zone_records:
    if record.type in record_types_to_migrate:
        if "newzone" in functions:
            #print "Existing Record Name: " + record.name
            record.name = re.sub(from_zone_name, to_zone_name, record.name)
            #print "Modified Record Name: " + record.name
        resource_record_dict[record.name] = boto.route53.record.Record(name=record.name, type=record.type, ttl=record.ttl, resource_records=record.resource_records, alias_hosted_zone_id=record.alias_hosted_zone_id, alias_dns_name=record.alias_dns_name, identifier=record.identifier, weight=record.weight, region=record.region)

#commit records to to_zone
uncommitted_change_elements = 0
examined_record_count = 0
migrated_record_count = 0

for record in resource_record_dict:
    examined_record_count += 1
    #if record is an alias record we are not supporting yet
    if resource_record_dict[record].alias_dns_name is not None:
        sys.stdout.write("Record \"" + resource_record_dict[record].name + "\" is an alias record set and will not be migrated. " + app_name + " does not currently support alias record sets.\n")
    else:
        uncommitted_change_elements += 1
        to_zone_record_changeset.add_change_record("CREATE", resource_record_dict[record])
    #DEBUG: print "Uncommitted Record Count:" + str(uncommitted_change_elements)
    #if there are 99 uncomitted change elements than they must be committed - Amazon only accepts up to 99 change elements at a given time
    #if the number of examined records is equal to the number of records then we can commit as well - we are now done examing records
    if uncommitted_change_elements >= 99 or examined_record_count == len(resource_record_dict):
        #DEBUG: print "Flushing Records:" + str(uncommitted_change_elements)
        commit_record_changeset(to_zone_record_changeset)
        migrated_record_count += uncommitted_change_elements
        uncommitted_change_elements = 0
        to_zone_record_changeset = None
        to_zone_record_changeset = boto.route53.record.ResourceRecordSets(to_connection, to_zone_id)

print "Summary:"
print "Records Migrated from zone: \"" + from_zone_name + "\" to zone: \"" + from_zone_name + "\"."
print "Types of Records Selected for Migration: " + str(record_types_to_migrate) + "."
print "Records Migrated: " + str(migrated_record_count) + "."
print "Records Examined: " + str(examined_record_count) + "."
