# Introduction:
rds-cost-calculate was created to easily sum the total of RDS instances running in one or all regions. The typical use would be to run the rds-cost-calculate script and then import into a spreadsheet application for further analysis. Another use would be to run the rds-cost-calculate script with cron, producing a weekly output file (an example of this: `echo "0 0 * * 0 ec2-user /home/ec2-user/rds-cost-calculate.sh -p day -r all > /home/ec2-user/rds-cost-report`date +"%Y%m%d"`.txt" > /etc/cron.d/rds-cost-calculate.sh`).
# Directions For Use:
## Example of Use:
    rds-cost-calculate.sh -r us-east-1 -p day
the above example would provide a list of all RDS instances in the region "us-east-1" along with the daily cost of running each RDS instance.
## Required Parameters:
rds-cost-calculate has no parameter requirements. rds-cost-calculate does, however, default to the region "us-east-1" and hourly cost if no parameters are provided.
## Optional Parameters:

`-r <region>` - the region you wish to calculate cost for: these arguments include "all" for all regions or us-east-1, us-west-1, us-west-2, eu-west-1, ap-southeast-1, ap-northeast-1 or sa-east-1

`-p <period>` - the period for which you wish to calculate instance cost. Allowable arguments are hour, day, week, month or year.
# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2012-12-09
- Version 0.5
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
