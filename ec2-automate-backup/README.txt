# Introduction:
ec2-automate-backup was created to provide easy backup/snapshot functionality for EC2 EBS volumes. The typical use would be to run ec2-automate-backup with a list of volumes for which a snapshot is desired. Another common use would be to run ec2-automate-backup with cron (example: "0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -v vol-6d6a0527 > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log") or to snapshot all EBS volumes that contain the tag "Backup=true" (example: "0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup=true" > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log")
# Directions For Use:
#
## Example of Use:
#
ec2-automate-backup -v vol-6d6a0527
----
the above example would provide a single backup of the EBS volumeid vol-6d6a0527. The snapshot would be created with the description "vol-6d6a0527_2012-09-07".
## Required Parameters:
#
ec2-automate-backup requires one of the following two parameters be provided:
-v <volumeid> - the "volumeid" parameter is required to select EBS volumes for snapshot if ec2-automate-backup is run using the "volumeid" selection method - the "volumeid" selection method is the default selection method.
-t <tag> - the "tag" parameter is required if the "method" of selecting EBS volumes for snapshot is by tag (-s tag). The format for tag is key=value (example: Backup=true) and the correct method for running ec2-automate-backup in this manner is ec2-automate-backup -s tag -t Backkup=true.
#
## Optional Parameters:
#
-r <region> - the region that contains the EBS volumes that you wish to have a snapshot created for.
-s <selection_method> - the selection method for which EBS volumes will be selected. Currently supported selection methods are "volumeid" and "tag." The selection method "volumeid" identifies EBS volumes for which a snapshot should be taken by volumeid whereas the selection method "tag" identifies EBS volumes for which a snapshot should be taken by a user provided "tag".
#
# Potential Uses and Methods of Use:
#
* Backup multiple EBS volumes using as follows: ec2-automate-backup -v "vol-6d6a0527 vol-636a0112"
* Backup a selected group of EBS volumes on a schedule tag each volume you wish to backup with the tag "backup=true" and run ec2-automate-backup using cron as follows: ec2-automate-backup -s tag -t "backup=true"
* Backup a selected group of EBS volumes on a schedule tag each volume you wish to backup with the tag "Backup-Daily=true" and/or "Backup-Monthly=true" and run ec2-automate-backup using cron as follows:
 - 0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Daily=true"
 - 0 0 1 * * ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Monthly=true"
#
# Additional Information:
#
Author: Colin Johnson / colin@cloudavail.com
Date: 2012-09-07
Version 0.1
License Type: GNU GENERAL PUBLIC LICENSE, Version 3
