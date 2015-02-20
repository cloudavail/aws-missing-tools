# Introduction:
ec2-cost-calculate.rb was created to easily sum the total of instances running in one or all regions. The typical use would be to run the ec2-cost-calculate.rb script and then import into a spreadsheet application for further analysis. Another use would be to run the ec2-cost-calculate.rb script with cron, producing a weekly output file (an example of this: `echo "0 0 * * 0 ec2-user /home/ec2-user/ec2-cost-calculate.rb --period day --region all --output file --file /home/ec2-user/ec2-cost-report`date +"%Y%m%d"`.txt" > /etc/cron.d/ec2-cost-calculate`).
# Directions For Use:
## Example of Use:
    ec2-cost-calculate.rb --period day
the above example would provide a list of all instances in all regions along with the daily cost of running each instance.
## Required Parameters:
ec2-cost-calculate.rb has no parameter requirements. ec2-cost-calculate.rb defaults to all regions and hourly cost if no parameters are provided.
## Optional Parameters:
optional parameters are available by running `ec2-cost-calculate.rb --help`.
## Running with IAM Credentials
the file "ec2cc - IAM User Required Permissions.json" contains the permissions required to run ec2-cost-calculate.rb in with the "Least Permissions" required as of 2012-11-11.
# Additional Information:

- Author: Colin Johnson / colin@cloudavail.com
- Date: 2012-12-09
- Version 0.2
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
