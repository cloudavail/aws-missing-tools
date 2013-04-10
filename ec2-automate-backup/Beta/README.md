# Introduction:
ec2-automate-backup was created to provide easy backup/snapshot functionality for EC2 EBS volumes. Common uses would include the following:
* run ec2-automate-backup with a list of volumes for which a snapshot is desired (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112"`)
* run ec2-automate-backup with a list of volumes for which a snapshot is desired and allow the created snapshots to be deleted after 31 days (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 31`)
* run ec2-automate-backup with a list of volumes for which a snapshot is desired and allow the created snapshots to be deleted after 60 minutes (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 60m`)
* run ec2-automate-backup with a list of volumes for which a snapshot is desired and allow the created snapshots to be deleted after 1 hour (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 1h`)
* run ec2-automate-backup using cron to produce a daily backup (example: `"0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log"`)
* run ec2-automate-backup to snapshot all EBS volumes that contain the tag "Backup=true" (example: `"0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup=true" > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log"`)

# Beta Version:
* ec2-automate-backup beta allows the use days, hours or minutes when directing ec2-automate-backup to purge snapshots. Example of the -k option as follows:
`-k 7d` - purge snapshots after 7 days.
`-k 12h` - purge snapshots after 12 hours.
`-k 30m` - purge snapshots after 30 minutes.

# Directions For Use:
## Example of Use:
`ec2-automate-backup -v vol-6d6a0527`

the above example would provide a single backup of the EBS volumeid vol-6d6a0527. The snapshot would be created with the description "vol-6d6a0527_2012-09-07".
## Required Parameters:
ec2-automate-backup requires one of the following two parameters be provided:

`-v <volumeid>` - the "volumeid" parameter is required to select EBS volumes for snapshot if ec2-automate-backup is run using the "volumeid" selection method - the "volumeid" selection method is the default selection method.

`-t <tag>` - the "tag" parameter is required if the "method" of selecting EBS volumes for snapshot is by tag (-s tag). The format for tag is key=value (example: Backup=true) and the correct method for running ec2-automate-backup in this manner is ec2-automate-backup -s tag -t Backup=true.

`-d <destination region(s)>` - the "destination region" parameter is required if the "method" of selecting EBS snapshots for copy to another region is by region (-s regioncopy). The format for `-d` is space-delimited region names such as ec2-automate-backup.sh -s regioncopy -d "us-west-1 us-west-2". This selection method only operates on snapshots.
## Optional Parameters:
`-r <region>` - the region that contains the EBS volumes for which you wish to have a snapshot created.

`-s <selection_method>` - the selection method by which EBS volumes will be selected. Currently supported selection methods are "volumeid", "tag" and "regioncopy." The selection method "volumeid" identifies EBS volumes for which a snapshot should be taken by volume id whereas the selection method "tag" identifies EBS volumes for which a snapshot should be taken by a key=value format tag. The selection method "regioncopy" identifies regions as destinations for EBS volumes that have been scheduled for copy to that region.

`-c <cron_primer_file>` - running with the -c option and a providing a file will cause ec2-automate-backup to source a file for environmental configuration - ideal for running ec2-automate-backup under cron. An example cron primer file is located in the "Resources" directory and is called cron-primer.sh.

`-n` - tag snapshots "Name" tag as well as description

`-k <purge_after_period>` - the period after which a snapshot can be purged. For example, running "ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 31" would allow snapshots to be removed after 31 days. purge_after_period creates two tags for each volume that was backed up - a PurgeAllow tag which is set to PurgeAllow=true and a PurgeAfterFE tag which is set to the number of minutes from epoch after which a snapshot can be purged. Values can also be entered as -k 60m (this would purge snapshots after 60 minutes or -k 2h (this would purge snapshots after 2 hours) or -k 7d (this would purge snapshots after 7 days). With no trailing characters the purge after period defaults to days.

`-p` - the -p flag will purge (meaning delete) all snapshots that where the current date is passed the volumes "PurgeAfterFE" tag. ec2-automate-backup looks at two tags to determine which snapshots should be deleted - the PurgeAllow and PurgeAfterFE tags. The tags must be set as follows: PurgeAllow=true and PurgeAfterFE=xxxxxxxxxx where xxxxxxxxxx is a UNIX time that is before the current date.

`-g <scheduled destination regions>` - Space-delimited destination regions for the volumes selected. This is added when the `-v` or `-t` selection method is used. Note that this only adds a tag that schedules the snapshot to be copied to the destinations. On subsequent calls, the `-d` parameter will intiate copies to the specified regions.
# Potential Uses and Methods of Use:
* To backup multiple EBS volumes use ec2-automate-backup as follows: `ec2-automate-backup -v "vol-6d6a0527 vol-636a0112"`
* To backup multiple EBS volumes and schedule them for copy to two other regions: `ec2-automate-backup -v "vol-6d6a0527 vol-636a0112" -g "us-west-1 us-west-2"`
* To backup a selected group of EBS volumes on a daily schedule tag each volume you wish to backup with the tag "Backup=true" and run ec2-automate-backup using cron as follows: `0 0 * * 0 ec2-automate-backup -s tag -t "Backup=true"`
* To backup a selected group of EBS volumes on a daily and/or monthly schedule tag each volume you wish to backup with the tag "Backup-Daily=true" and/or "Backup-Monthly=true" and run ec2-automate-backup using cron as follows:
 - `0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Daily=true"`
 - `0 0 1 * * ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Monthly=true"`
* To perform daily backup using cron and to load environment configuration with a "cron-primer" file:
 - `0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -c /home/ec2-user/cron-primer.sh -s tag -t "Backup=True"`
* To initiate the copy of scheduled snapshots to their destination regions: `ec2-automate-backup.sh -s regioncopy -d "us-west-1 us-west-2"`

`-u` - the -u flag will tag snapshots with additional data so that snapshots can be more easily located. Currently the two user tags created are Volume="ebs_volume" and Created="date." These can be easily modified in code.

# Additional Information:
the file "ec2ab - IAM User Required Permissions.json" contains the IAM permissions required to run ec2-automate-backup.sh in with the least permissions required as of 2012-11-21.

- Author: Colin Johnson / colin@cloudavail.com
- Date: 2013-02-17
- Version 0.9 Beta
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
