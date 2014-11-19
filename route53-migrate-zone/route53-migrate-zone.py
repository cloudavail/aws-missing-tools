#!/usr/bin/env python
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-10-12
# Version 0.2
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3

import argparse  # used to gather user input
import ConfigParser  # import ConfigParser - used for getting configuration
import logging  # used to write out log events - events that are neither required output nor error
import os  # used to get app_name
import re  # import re used to find/replace zone

import boto.route53  # import boto.route53 (not just boto) - need to import correct module

def commit_record_changeset(destination_zone_record_changeset):
    '''commit_record_changeset commits records to AWS'''
    try:
        destination_zone_record_changeset.commit()
    except boto.route53.exception.DNSServerError, error:
        logging.critical('An error occured when attempting to commit records to the zone "{destination_zone_name!s}."'
            .format (destination_zone_name=destination_zone_name))
        logging.critical('The error message given was: {error!s}.'.format (error=error.error_message))
        exit(69)


def diff_record(record_a, record_a_object, record_b, record_b_object):
    '''diff_record compares two different resource records'''
    compare_values = ['type', 'ttl', 'resource_records', 'alias_hosted_zone_id', 'alias_dns_name', 'identifier', 'weight', 'region']
    diff_record_result = False

    for value in compare_values:
        if getattr(record, value) != getattr(destination_zone_existing_resource_record_dict[record.name], value):
            diff_record_result = True
    return diff_record_result


app_name = os.path.basename(__file__)

parser = argparse.ArgumentParser()
parser.add_argument('--log-level', dest='loglevel', help=str('set the log level when running {app_name!s}.'.format (app_name=app_name)),
    default='WARNING', choices=['DEBUG','INFO','WARNING','ERROR','CRITICAL'])
parser.add_argument('--config', help=str('choose the configuration file to be used when running {app_name!s}'.format(app_name=app_name)),
    default='config.ini')
args = parser.parse_args()

config_file_path = args.config
config = ConfigParser.ConfigParser()
config.read(config_file_path)

# configure logging
log_format = '%(message)s'
log_level = str.upper(args.loglevel)
logging.basicConfig(level=log_level, format=log_format)

# functions: currently supports newzone - the functions are set automatically by the route53-migrate-zone script
functions = []

# the source_zone user credentials should be read-only
source_zone_access_key = config.get('source_zone_values', 'source_zone_access_key')
source_zone_secret_key = config.get('source_zone_values', 'source_zone_secret_key')
source_zone_name = config.get('source_zone_values', 'source_zone_name')

destination_zone_access_key = config.get('destination_zone_values', 'destination_zone_access_key')
destination_zone_secret_key = config.get('destination_zone_values', 'destination_zone_secret_key')
destination_zone_name = config.get('destination_zone_values', 'destination_zone_name')
# best would be to retreive the destination_zone_id using destination_zone_name
destination_zone_id = config.get('destination_zone_values', 'destination_zone_id')

record_types_to_migrate = ['A', 'CNAME', 'MX', 'TXT']

if source_zone_name != destination_zone_name:
    logging.info('{app_name!s} will rewrite domain names ending in {source_zone_name!s} to domain names ending in {destination_zone_name!s}'.format
                (app_name=app_name, source_zone_name=source_zone_name, destination_zone_name=destination_zone_name))
    functions.append('newzone')

# creates Route53Connection Object
source_connection = boto.route53.Route53Connection(aws_access_key_id=source_zone_access_key, aws_secret_access_key=source_zone_secret_key)
destination_connection = boto.route53.Route53Connection(aws_access_key_id=destination_zone_access_key, aws_secret_access_key=destination_zone_secret_key)

# create connection to source_zone
try:
    source_zone = source_connection.get_zone(source_zone_name)
except boto.route53.exception.DNSServerError, error:
    logging.critical('An error occured when attempting to create a connection to AWS.')
    logging.critical('The error message given was: {error!s}.'.format (error=error.error_message))
    exit(69)

# create connection to destination_zone
try:
    destination_zone = destination_connection.get_zone(destination_zone_name)
except boto.route53.exception.DNSServerError, error:
    logging.critical('An error occured when attempting to create a connection to AWS.')
    logging.critical('The error message given was: {error!s}.'.format (error=error.error_message))
    exit(69)

# creates ResourceRecordSets object named source_zone_records
# (ResourceRecordSets = a collection of resource records)
source_zone_records = source_zone.get_records()
# creates ResourceRecordSets object named destination_zone_records
# (ResourceRecordSets = a collection of resource records)
destination_zone_records = destination_zone.get_records()

# resource_record_dict will be used to store all resource records that
# should be transferred
resource_record_dict = {}
# destination_zone_existing_resource_record_dict will be used to store all
# resource records that exist in destination zone
destination_zone_existing_resource_record_dict = {}

# creates a set of changes to be delivered to Route53
destination_zone_record_changeset = boto.route53.record.ResourceRecordSets(destination_connection, destination_zone_id)

for record in destination_zone_records:
    destination_zone_existing_resource_record_dict[record.name] = record

# counts of records - should be replaced by dictionary
examined_record_count = 0
migrated_record_count = 0
existing_records_in_destination_zone_count = 0
identical_records_in_destination_zone_count = 0
different_records_in_destination_zone_count = 0
uncommitted_change_elements = 0

# get records from source_zone
for record in source_zone_records:
    if record.type in record_types_to_migrate:
        if 'newzone' in functions:
            destination_record = re.sub(source_zone_name, destination_zone_name, record.name)
            logging.debug('Record "{record_name!s}" will be rewritten as "{destination_record!s}".'
                .format(record_name=record.name, destination_record=destination_record))
            record.name = destination_record

        # test if record exists in destination_zone and has same type
        if (record.name in destination_zone_existing_resource_record_dict and
           record.type == destination_zone_existing_resource_record_dict[record.name].type):

            existing_records_in_destination_zone_count += 1
            # compare records in source_domain and destination_domain, store result as diff_result
            diff_result = diff_record(record.name, record, record.name, destination_zone_existing_resource_record_dict)
            if diff_result is True:
                different_records_in_destination_zone_count += 1
                logging.info('Record {record_name!s} exists in source zone {source_zone_name!s} and destination zone {destination_zone_name!s} and is different.'
                    .format(record_name=record.name, source_zone_name=source_zone_name, destination_zone_name=destination_zone_name))
            elif diff_result is False:
                identical_records_in_destination_zone_count += 1
                logging.info('Record {record_name!s} exists in source zone {source_zone_name!s} and destination zone {destination_zone_name!s} and is identical.'
                    .format(record_name=record.name, source_zone_name=source_zone_name, destination_zone_name=destination_zone_name))
            else:
                logging.critical('Diff of record {record_name!s} failed.'
                    .format(record_name=record.name))
                exit(70)
        else:
            resource_record_dict[record.name] = boto.route53.record.Record(name=record.name, type=record.type, ttl=record.ttl, resource_records=record.resource_records, alias_hosted_zone_id=record.alias_hosted_zone_id, alias_dns_name=record.alias_dns_name, identifier=record.identifier, weight=record.weight, region=record.region, alias_evaluate_target_health=record.alias_evaluate_target_health)

for record in resource_record_dict:
    examined_record_count += 1
    uncommitted_change_elements += 1
    destination_zone_record_changeset.add_change_record("CREATE", resource_record_dict[record])
    logging.info('Uncommitted Record Count: {uncommitted_change_elements!s}'
        .format (uncommitted_change_elements=uncommitted_change_elements))
    # if there are 99 uncomitted change elements than they must be committed - Amazon only accepts up to 99 change elements at a given time
    # if the number of examined records is equal to the number of records then we can commit as well - we are now done examing records
    if uncommitted_change_elements >= 99 or examined_record_count == len(resource_record_dict):
        logging.info('Flushing this Number of Uncommitted Records: {uncommitted_change_elements!s}'
            .format (uncommitted_change_elements=uncommitted_change_elements))

        # Commit changes
        commit_record_changeset(destination_zone_record_changeset)

        migrated_record_count += uncommitted_change_elements
        uncommitted_change_elements = 0
        destination_zone_record_changeset = None

        destination_zone_record_changeset = boto.route53.record.ResourceRecordSets(destination_connection, destination_zone_id)

logging.info('Summary:')
logging.info('Records migrated from source zone: {source_zone_name!s} to destination zone: {destination_zone_name!s}.'
    .format(source_zone_name=source_zone_name, destination_zone_name=destination_zone_name))
logging.info('Record types selected for migration: {record_types_to_migrate!s}).'
    .format(record_types_to_migrate=record_types_to_migrate))
logging.info('Records examined: {examined_record_count!s}).'
    .format (examined_record_count=examined_record_count))
logging.info('Records migrated: {migrated_record_count!s}).'
    .format (migrated_record_count=migrated_record_count))
logging.info('Records not migrated because they exist in destination zone {destination_zone_name!s}: {existing_records_in_destination_zone_count!s}.'
    .format (destination_zone_name=destination_zone_name, existing_records_in_destination_zone_count=existing_records_in_destination_zone_count))
logging.info('Records that exist in source zone {source_zone_name!s} and destination zone {destination_zone_name!s} and are identical: {identical_records_in_destination_zone_count!s}'
    .format (source_zone_name=source_zone_name, destination_zone_name=destination_zone_name, identical_records_in_destination_zone_count=identical_records_in_destination_zone_count))
logging.info('Records that exist in source zone {source_zone_name!s} and destination zone {destination_zone_name!s} and are different: {different_records_in_destination_zone_count!s}'
    .format (source_zone_name=source_zone_name, destination_zone_name=destination_zone_name, different_records_in_destination_zone_count=different_records_in_destination_zone_count))
