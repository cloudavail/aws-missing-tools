# Introduction:
rds-apply-alarms was created to easily apply alarms to one or more Amazon RDS instances. The tool applies alarms for CPU Utilization, Feeable Memory, Swap Usage and Free Storage Space. rds-apply-alarms will run "out of the box", however the intent is rather to provide a template (and the logic) for managing multiple RDS instance's alarms.
# Directions For Use:
## Example of Use:
    rds-apply-alarms -d rds-instance-name -t name-of-sns-topic
the above example would apply alarms to "rds-instance-name" and, if any of these Alarms enter state "Alarm" would send a message to "name-of-topic."
## Required Parameters:
rds-apply-alarms requires the following two arguments:

`-d <rds-instance-name>` - the name of the Database Instance for which you wish to apply alarms.

`-t <name-of-topic>` - the name of the sns-topic where Alarms should be sent.
## Optional Parameters:
`-a` - pass the -a parameter to apply alarms to ALL RDS instances in a given region.

`-r <region>` - region that contains the RDS instances(s) where alarms should be applied

`-e <evaluation period>` - set to the number of evaluation periods before an SNS topic is notified.

`-p <previewmode>` - set to "true" to preview what alarms would be applied.
# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2012-12-09
- Version 0.5
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
