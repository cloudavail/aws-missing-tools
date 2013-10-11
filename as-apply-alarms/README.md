# Introduction:
as-apply-alarms was created to easily apply alarms to one or more Auto Scaling Groups. The tool applies alarms for CPU Utilization. as-apply-alarms will run "out of the box" however the intent is rather to provide a template (and the logic) for managing multiple Auto Scaling Group's alarms.
# Directions For Use:
## Example of Use:
    as-apply-alarms -d auto-scaling-group-name -t name-of-sns-topic
the above example would apply alarms to the Auto Scaling Group named <auto-scaling-group-name> and if any of these Alarms enter state "Alarm" would send a message to "name-of-topic."
## Required Parameters:
as-apply-alarms requires the following two arguments:

`-g <auto-scaling-group-name>` - the name of the Auto Scaling Group for which you wish to apply alarms.

`-t <name-of-topic>` - the name of the sns-topic where Alarms should be sent.
#
## Optional Parameters:
`-a` - pass the -a parameter to apply alarms to all Auto Scaling Groups.

`-r <region>` - region that contains the Auto Scaling Group(s) where alarms should be applied

`-e <evaluation period>` - set to the number of evaluation periods before an SNS topic is notified.

`-p <previewmode>` - set to "true" to preview what alarms would be applied.
# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2012-12-09
- Version 0.5
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
