# Introduction:
route53-migrate-zone was created to provide a method of migrating a Route53 zone to a new zone or to a new AWS account. There are three use cases, detailed below:
* Migrate one domain (source.com) to a new domain (destintion.com)
* Migrate one domain (domain.com) to the same domain in a new account (domain.com)
* Migrate one domain (source.com) to a new domain in a new account (destination.com)

# Directions For Use:
## Example of Use:
Open the file config.ini and modify the entries within this file as desired. Then execute route53-migrate-zone as follows:
`route53-migrate-zone.py`

A config.ini file configured as follows will migrate olddomain.com to newdomain.com in the account given by the variables to_secret_key and to_zone_name.
* from_zone_name = source.com.
* to_zone_name = destination.com.
* to_zone_id = Z1U8DOWB9FJWOU

## Additional Command Line Options
* `route53-migrate-zone.py --log=INFO` - to see informational events
* `route53-migrate-zone.py --config ./myconfig.ini` - to use the file myconfig.ini instead of the default config.ini file

# Explanation of Summary Output:
* Records Migrated from source zone: a count of the records that were migrated from source zone to destination zone
* Record types selected for migration: a list of the record types selected for migration. An example: ['A', 'CNAME', 'MX', 'TXT']
* Records not migrated because they exist in destination zone: these records exist in both the source zone and the destination zone. These records were not migrated.
* Records that exist in source zone and destination zone and are identical: these records exist in both the source zone and the destination zone and are identical. Because they are identical there is no reason to move them.
* Records that exist in source zone and destination zone and are different: these records exist in both the source zone and the destination zone and are different. These records should probably be examined manually.

# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2013-06-08
- Version 0.1
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
