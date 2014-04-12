#!/usr/bin/env python
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-11-17
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3

import argparse
import logging
import os
import time

from boto import ec2
from boto import exception

app_name = os.path.basename(__file__)
unix_time_current = time.time()
# datetime_format_standard is ISO 8601 combined date and time with timezone
datetime_format_standard = '%Y-%m-%dT%H:%M:%S%z'
datetime_current = time.strftime(datetime_format_standard,
                                 time.gmtime(unix_time_current))


def attach_volume(instance_object, volume_object, device):
    ''' given a ec2.instance.Instance object, an ec2.volume.Volume object and
 a device, attach the volume object and wait for the volume to show as
 in-use '''
    logging.debug('attach_volume called.')
    attach_result = volume_object.attach(instance_object.id, device)
    logging.info('attach result was: {!s}'.format(attach_result))
    wait_aws_event(object_in=volume_object, object_type='volume',
                   wait_for_string='in-use')


def create_snapshot(volume_object, snapshot_description=None):
    ''' given a volume object, take a snapshot and return a snapshot object '''
    logging.debug('create_snapshot called.')
    snapshot_object = volume_object.create_snapshot(snapshot_description)
    wait_aws_event(object_in=snapshot_object, object_type='snapshot',
                   wait_for_string='completed')
    return snapshot_object


def create_volume(snapshot_object, size, availability_zone, iops=None,
                  volume_type=None):
    ''' given a boto.ec2.snapshot.Snapshot, size and availability zone, returns
 a volume object '''
    logging.debug('create_volume called.')
    logging.info('snapshot_id: {!s}, size: {!s}, availability_zone: {!s}, iops: {!s}, volume_type: {!s}'
                  .format(snapshot_object, size, availability_zone, iops, volume_type))
    volume_object = snapshot_object.create_volume(availability_zone, size=size,
                                                  iops=iops,
                                                  volume_type=volume_type)
    wait_aws_event(object_in=volume_object, object_type='volume',
                   wait_for_string='available')
    logging.info('new volume id is: {!s}'.format(volume_object.id))
    return volume_object


def detach_volume(volume_object):
    ''' given a boto.ec2.volume.Volume object, detaches it and waits for the
 volume to show as available'''
    logging.debug('detach_volume called.')
    try:
        detach_result = volume_object.detach()
    except exception.EC2ResponseError:
        logging.critical('An error occured when attempting to detach volume {!s}.'.format(volume_object.id))
        exit (1)
    logging.info('detach result was: {!s}'.format(detach_result))
    wait_aws_event(object_in=volume_object, object_type='volume',
                   wait_for_string='available')


def get_block_device_type(block_device_name, block_device_mapping):
    ''' given a block device name and a block device mapping, returns a
 boto.ec2.blockdevicemapping.BlockDeviceType object'''
    block_device_type = None
    logging.debug('get_block_device_type called.')
    logging.info('device is {!s}.'.format(block_device_name))
    if block_device_name in block_device_mapping:
        logging.info('block device {!s} found'.format(block_device_name))
        block_device_type = block_device_mapping[block_device_name]
    else:
        logging.critical('block device {!s} not found.'
                         .format(block_device_name))
        exit(1)
    logging.info('block_device_name\'s volume_id is: {!s}.'
                 .format(block_device_type.volume_id))
    return block_device_type


def get_block_device_volume(ec2_connection, volume_id):
    ''' given an ec2_connection object and a volume_id, returns a volume
 object'''
    logging.debug('get_block_device_volume called.')
    volume_object = None
    get_all_volumes_result = ec2_connection.get_all_volumes(volume_ids=[volume_id])
    volume_object = get_all_volumes_result[0]
    return volume_object


def get_selected_instances(instance_id):
    ''' given an instance_id returns an instance object '''
    logging.debug('get_selected_instances called.')
    try:
        instances = ec2_connection.get_only_instances([instance_id])
    except exception.EC2ResponseError:
        logging.critical('Unable to get selected instance due to an EC2ResponseError.')
        exit(1)
    if len(instances) == 0:
        exit(1)
    instance = instances[0]
    logging.info('instance_id found: {!s}'.format(instance.id))
    return instance


def return_desired_volume_size(aws_limits, args, volume_object):
    # determine volume_attributes['size']
    desired_volume_size = None
    if args.volume_size is not None:
        if args.volume_size > aws_limits['max_volume_size']:
            logging.critical('--volume-size can not be greater than {!s}. You requested --volume-size {!s}.'
                             .format(aws_limits['max_volume_size'],
                                     args.volume_size))
            exit(1)
        else:
            desired_volume_size = args.volume_size
    else:
        desired_volume_size = volume_object.size
    # validate volume_attributes['size']
    # the desired_volume_size must be greater than the previous_volume.size
    if volume_object.size > desired_volume_size:
        logging.critical('--volume-size must be greater than the existing volume size. You requested --volume-size {!s} and volume {!s} has a size of {!s}.'
                         .format(desired_volume_size, volume_object.id,
                                 volume_object.size))
        exit(1)
    logging.info('desired volume size will be: {!s}'
                 .format(desired_volume_size))
    return desired_volume_size


def return_desired_iops(aws_limits, args, volume_object, volume_size):
    desired_iops = None
    # handle the condition where the user has input --volume-type io1 and
    # not input an --iops value
    if args.iops is None:
        if args.volume_type is not None:
            logging.critical('if a --volume-type except standard is specified --iops <int> must be specified as well.')
            exit(1)
        else:
            desired_iops = volume_object.iops
    else:
        desired_iops = args.iops
        
    if desired_iops < aws_limits['min_iops']:
        logging.critical('--iops must be greater than {!s}.'.format(aws_limits['min_iops']))
        exit(1)
    elif desired_iops > aws_limits['max_iops']:
        logging.critical('--iops must be less than {!s}.'.format(aws_limits['max_iops']))
        exit(1)

    # validate volume_attributes['iops'] settings with volume_attributes['size']
    # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html#EBSVolumeTypes_piops
    max_allowed_iops = (aws_limits['max_iops_size_multiplier'] * volume_size)
    if desired_iops > max_allowed_iops:
        logging.critical('--iops may not be greater than {!s} times volume size. Maximum allowable iops is {!s}.'
                         .format(aws_limits['max_iops_size_multiplier'], max_allowed_iops))
        exit(1)
    
    logging.info('desired volume iops will be: {!s}'.format(desired_iops))
    return desired_iops


def validate_standard_volume_attrs(args, volume_object, aws_limits):
    if args.iops is not None:
        logging.critical('--iops can only be used if --volume-type io1.')
        exit(1)
    if volume_object.type is not 'standard':
        logging.warning('You requested standard and current volume type is {!s}.'
                        .format(volume_object.type))


def return_desired_volume_attrs(args, volume_object):
    ''' given an arguments object and a volume object returns sensible volume
 attributes for a new volume. Rule is to always use argument if provided, else
 to fall back to existing attributes else to use defaults.'''
    logging.debug('return_desired_volume_attrs called.')

    volume_attributes = {'size': None, 'volume_type': None, 'iops': None}
    # max_iops_size_multiplier is used to determine the allowable number of iops
    # given a volume size. iops can be no greater than 30 x volume size as of
    # 2013-11-17
    aws_limits = {'max_volume_size': 1024, 'min_iops': 100, 'max_iops': 4000,
                  'max_iops_size_multiplier': 30}

    volume_attributes['size'] = return_desired_volume_size(aws_limits=aws_limits,
                                                           args=args,
                                                           volume_object=volume_object)
    # determine volume_attributes['type']
    if args.volume_type is not None:
        volume_attributes['type'] = args.volume_type
    else:
        volume_attributes['type'] = volume_object.type
    logging.info('desired volume type will be: {!s}'
                 .format(volume_attributes['type']))

    if volume_attributes['type'] == 'standard':
        validate_standard_volume_attrs(aws_limits=aws_limits, args=args, volume_object=volume_object)
    elif volume_attributes['type'] == 'io1':
        volume_attributes['iops'] = return_desired_iops(aws_limits=aws_limits,
                                                        args=args,
                                                        volume_object=volume_object,
                                                        volume_size=volume_attributes['size'])
    else:
        logging.critical('Supported --volume-types are \'io1\' and \'standard\'.')
        exit(1)
    return volume_attributes


def start_instance(instance_object):
    logging.debug('start_instance called.')
    instance_object.start()
    wait_aws_event(object_in=instance_object, object_type='instance',
                   wait_for_string='running')


def stop_instance(instance_object):
    logging.debug('stop_instance called.')
    instance_object.stop()
    wait_aws_event(object_in=instance_object, object_type='instance',
                   wait_for_string='stopped')


def wait_aws_event(object_in, object_type, wait_for_string):
    ''' given an object, a string describing the type of object and a string
 that will be return when the resource represented by the object is available,
 wait_aws_event will poll the object to determine if the resource is represents
 is available for service. wait_aws_event returns when '''
    logging.debug('wait_aws_event called.')
    # allowed_wait_time reflects the number of seconds a that wait_aws_event
    # will wait for a status or state change
    allowed_wait_time = 900

    # determines the correct attribute to poll to determine the state/status
    # of an object. Instance resources/objects use 'state' while other
    # resources/objects use status.
    if object_type == 'instance':
        attribute = 'state'
    else:
        attribute = 'status'

    total_time_waiting = 0
    time_between_polling = 5
    object_id = getattr(object_in, 'id')
    object_status = getattr(object_in, attribute)
    logging.info('wait_aws_event will wait for {!s} seconds {!s} {!s} to return to {!s} {!s}.'
                 .format(allowed_wait_time, object_type, object_id, attribute,
                         wait_for_string))

    while object_status != unicode(wait_for_string) and total_time_waiting < allowed_wait_time:
        object_in.update()
        object_status = getattr(object_in, attribute)
        logging.info('{!s} {!s}\'s {!s} is {!s}. Time elapsed is {!s} seconds.'
                     .format(object_type, object_id, attribute, object_status,
                             total_time_waiting))
        time.sleep(time_between_polling)
        total_time_waiting += time_between_polling

    logging.info('total time waiting for {!s} {!s} to return to {!s} {!s}: {!s} seconds.'
                 .format(object_type, object_id, attribute, wait_for_string,
                         total_time_waiting))

    if object_status == unicode(wait_for_string):
        pass
    else:
        logging.critical('{!s} {!s} did not return to {!s} {!s} in {!s} seconds.'
                         .format(object_type, object_id, attribute,
                                 wait_for_string, allowed_wait_time))
        exit(1)
    return object_status


# creates ec2_connection object
try:
    ec2_connection = ec2.connect_to_region('us-east-1')
except:
    logging.critical('An error occured when attempting to connect to the AWS API.')
    exit(1)
# aws_regions contains a list of strings representing AWS regions
aws_regions = [ (str(region.name)) for region in ec2_connection.get_all_regions() ]

parser = argparse.ArgumentParser()
parser.add_argument('--device', default='root',
                    help='select the device to modify by device attachment point. Example, /dev/sda1, /dev/sdf or root to select the root device.')
parser.add_argument('--instance-id', dest='instance_id', required=True,
                    help='set the instance-id of the instance that should have the EBS volume expanded.')
parser.add_argument('--iops', type=int, default=None,
                    help='set the number of iops the EBS volume should provide.')
parser.add_argument('--log-level', dest='log_level', default='INFO',
                    choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                    help='set the log level when running {!s}.'.format(app_name))
parser.add_argument('--region',
                    help='set the region where instances should be located.',
                    default='us-east-1', choices=aws_regions)
parser.add_argument('--volume-size', dest='volume_size', type=int, default=None,
                    help='set the volume size that the EBS volume should be.')
parser.add_argument('--volume-type', dest='volume_type', default=None,
                    choices=['standard', 'io1'],
                    help='set the type of EBS volume.')
args = parser.parse_args()

# configure logging
log_format = '%(message)s'
log_level = str.upper(args.log_level)
logging.basicConfig(level=log_level, format=log_format)

region = args.region
instance_id = args.instance_id
device = args.device

# gets an instance object corresponding to the instance_id
selected_instance = get_selected_instances(instance_id)

# if the given instance_id's shutdown behavior is not stop then exit
# if the instance_id's shutdown behavior is terminate than the EBS volume would
# be deleted
shutdown_behavior = ec2_connection.get_instance_attribute(instance_id, 'instanceInitiatedShutdownBehavior')
if shutdown_behavior[unicode('instanceInitiatedShutdownBehavior')] != unicode('stop'):
    logging.critical('instance_id {!s}\'s shutdown behavior must be "stop."\
 {!s}\'s shutdown behavior is "{!s}."'.format(instance_id, instance_id,
 shutdown_behavior[unicode('instanceInitiatedShutdownBehavior')]))
    exit(1)

instance_az = selected_instance.placement
instance_initial_state = selected_instance.state
logging.info('instance_id {!s}\'s state is {!s}.'
             .format(selected_instance.id, instance_initial_state))
if device == 'root':
    selected_device = selected_instance.root_device_name
else:
    selected_device = device
logging.info('selected device is: {!s}'.format(selected_device))
instance_block_device_mapping = selected_instance.block_device_mapping

# given the device and mapping, get a BlockDeviceType object - this object
# represents the volume to be modified
block_device_type = get_block_device_type(selected_device,
                                          instance_block_device_mapping)
# given a BlockDeviceType object, get the a volume object - this object
# represents the volume resource that will be increased in size
previous_volume = get_block_device_volume(ec2_connection,
                                          block_device_type.volume_id)

desired_volume_attrs = return_desired_volume_attrs(args=args,
                                                   volume_object=previous_volume)

# stops the instance - this may not be required, but is recommended in
# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-expand-volume.html#recognize-expanded-volume-linux
stop_instance(instance_object=selected_instance)
# detach the volume to be resized from the instance - this could be done after
# the snapshot is taken
detach_volume(volume_object=previous_volume)

snapshot_description = '{!s}-{!s}'.format(app_name, datetime_current)
previous_volume_snapshot = create_snapshot(volume_object=previous_volume,
                                           snapshot_description=snapshot_description)

new_volume = create_volume(snapshot_object=previous_volume_snapshot,
                           availability_zone=instance_az,
                           size=desired_volume_attrs['size'],
                           iops=desired_volume_attrs['iops'],
                           volume_type=desired_volume_attrs['type'])
attach_volume(instance_object=selected_instance, volume_object=new_volume,
              device=selected_device)

if instance_initial_state == unicode('running'):
    logging.info('instance_id {!s}\'s state was {!s}. instance_id {!s} will be returned to running state.'
                 .format(selected_instance.id, instance_initial_state,
                         selected_instance.id))
    start_instance(instance_object=selected_instance)
