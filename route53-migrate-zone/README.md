# Introduction:
route53-migrate-zone was created to provide an easy method of migrating Route53 zones to new zones or to new AWS accounts. There are three use cases, detailed below:
* Migrate one domain (olddomain.com) to a new domain (newdomain.com)
* Migrate one domain (domain.com) to the same domain in a new account (domain.com)
* Migrate one domain (olddomain) to a new domain in a new account (newdomain.com)

# Directions For Use:
## Example of Use:
Open the file config.ini and modify the entries within this file as desired. Then execute route53-migrate-zone as follows:
`route53-migrate-zone.py`

A config.ini file configured as follows will migrate olddomain.com to newdomain.com in the account given by the variables to_secret_key and to_zone_name.
* from_zone_name = olddomain.com.
* to_zone_name = newdomain.com.
* to_zone_id = Z1U8DOWB9FJWOU

# Additional Information:
- Author: Colin Johnson / colin@cloudavail.com
- Date: 2013-06-03
- Version 0.1
- License Type: GNU GENERAL PUBLIC LICENSE, Version 3
