# Introduction:
ec2-automate-backup was created to provide easy backup/snapshot functionality for multiple EC2 EBS volumes. Common uses would include the following:
* run ec2-automate-backup with a list of volumes for which a snapshot is desired (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112"`)
* run ec2-automate-backup with a list of volumes for which a snapshot is desired and allow the created snapshots to be deleted after 31 days (example: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 31`)
* run ec2-automate-backup using cron to produce a daily backup (example: ``"0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log"``)
* run ec2-automate-backup to snapshot all EBS volumes that contain the tag "Backup=true" (example: ``"0 0 * * 0 ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup=true" > /home/ec2-user/ec2-automate-backup_`date +"%Y%m%d"`.log"``)

# Installation Instructions:
ec2-automate-backup requires the AWS Command Line Interface tool be installed and properly configured. Instructions for installing the AWS Command Line Interface tool is available at https://aws.amazon.com/cli/.
## Policy ( optional )
You can omit environmental configuration by giving the policy to entire EC2 instance where you run the script with the following policy:
`
{
    "Statement": [
        {
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:CreateSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:DeleteSnapshot",
                "ec2:CreateTags",
                "ec2:CopySnapshot",
                "ec2:DescribeTags"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
`

# Directions For Use:
## Example of Use:
`./ec2-automate-backup.sh -r us-west-2 -s tag -t "Backup,Values=true" -k 44 -p -u -n -a`

the above example would provide a backup of all EBS volumes from 'Oregon' with tag 'Backup' set to 'true' with additional copy to 'Ireland'.
## Required Parameters:
ec2-automate-backup requires one of the following two parameters be provided:

`-v <volumeid>` - the "volumeid" parameter is required to select EBS volumes for snapshot if ec2-automate-backup is run using the "volumeid" selection method - the "volumeid" selection method is the default selection method.
    
`-t <tag>` - the "tag" parameter is required if the "method" of selecting EBS volumes for snapshot is by tag (-s tag). The format for tag is key,Values=$desired_values (example: Backup,Values=true) and the correct method for running ec2-automate-backup in this manner is ec2-automate-backup -s tag -t Backup,Values=true".
## Optional Parameters:
`-r <region>` - the region that contains the EBS volumes for which you wish to have a snapshot created.

`-s <selection_method>` - the selection method by which EBS volumes will be selected. Currently supported selection methods are "volumeid" and "tag." The selection method "volumeid" identifies EBS volumes for which a snapshot should be taken whereas the selection method "tag" identifies EBS volumes for which a snapshot should be taken by a filter that utilizes a Key and Value pair.

`-c <cron_primer_file>` - running with the -c option and a providing a file will cause ec2-automate-backup to source a file for environmental configuration - ideal for running ec2-automate-backup under cron. An example cron primer file is located in the "Resources" directory and is called cron-primer.sh.

`-n` - tag snapshots "Name" tag as well as description

`-h` - tag snapshots "InitiatingHost" tag to specify which host ran the script

`-k <purge_after_days>` - the period after which a snapshot can be purged. For example, running "ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112" -k 31" would allow snapshots to be removed after 31 days. purge_after_days creates two tags for each volume that was backed up - a PurgeAllow tag which is set to PurgeAllow=true and a PurgeAfter tag which is set to the present day (in UTC) + the value provided by -k.

`-p` - the -p flag will purge (meaning delete) all snapshots that were created more than "purge after days" ago. ec2-automate-backup looks at two tags to determine which snapshots should be deleted - the PurgeAllow and PurgeAfter tags. The tags must be set as follows: PurgeAllow=true and PurgeAfter=YYYY-MM-DD where YYYY-MM-DD must be before the present date.

`-u` - the -u flag will tag snapshots with additional data so that snapshots can be more easily located. Currently the two user tags created are Volume="ebs_volume" and Created="date." These can be easily modified in code.

`-a` - the -a flag will make additional copy of the snapshot to alternate AWS region ( defaults to eu-west-1 )

`-g <AWS_region>` - the AWS region for additional copy of the snapshot

# Potential Uses and Methods of Use:
* To backup multiple EBS volumes use ec2-automate-backup as follows: `ec2-automate-backup.sh -v "vol-6d6a0527 vol-636a0112"`
* To backup a selected group of EBS volumes on a daily schedule tag each volume you wish to backup with the tag "Backup=true" and run ec2-automate-backup using cron as follows: `0 0 * * * ec2-automate-backup.sh -s tag -t "Backup,Values=true"`
* To backup a selected group of EBS volumes on a daily and/or monthly schedule tag each volume you wish to backup with the tag "Backup-Daily=true" and/or "Backup-Monthly=true" and run ec2-automate-backup using cron as follows:
 - `0 0 * * * ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Daily,Values=true"`
 - `0 0 1 * * ec2-user /home/ec2-user/ec2-automate-backup.sh -s tag -t "Backup-Monthly,Values=true"`
* To perform daily backup using cron and to load environment configuration with a "cron-primer" file:
 - `0 0 * * * ec2-user /home/ec2-user/ec2-automate-backup.sh -c /home/ec2-user/cron-primer.sh -s tag -t "Backup,Values=true"`

- Author: Colin Johnson / colin@cloudavail.com
- Date: 2015-10-26
- Version 0.10
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
