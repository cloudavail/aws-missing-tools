#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2013-07-07
# Version 0.1
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3

#confirms that executables required for succesful script execution are available
prerequisite_check()
{
	for prerequisite in basename cut grep iam-userlistbypath iam-usergetattributes
	do
		#use of "hash" chosen as it is a shell builtin and will add programs to hash table, possibly speeding execution. Use of type also considered - open to suggestions.
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]] #has exits with exit status of 70, executable was not found
			then echo "In order to use $(basename $0), the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
		fi
	done
}

return_all_keys()
{
	for user in $users
	do
		access_key=$(iam-usergetattributes -u $user | grep -v "^arn")
		echo "$user,$access_key"
	done
}

return_found_key()
{
	key_found=false
	users_examined=0
	user_containing_key=""
	for user in $users
	do
		access_key=$(iam-usergetattributes -u $user | grep -v "^arn")
		if [[ "$find_access_key" == "$access_key" ]]
			then key_found=true
			user_containing_key=$user
			break
		else
			users_examined=$((users_examined + 1))
		fi
	done
	if $key_found
		then echo "The Access Key \"$find_access_key\" belongs to the IAM user named \"$user_containing_key.\""
	else
		echo "The Access Key \"$find_access_key\" does not belong to any IAM users. $app_name examined a total of $users_examined users."
	fi
}

#calls prerequisitecheck function to ensure that all executables required for script execution are available
prerequisite_check

app_name=$(basename $0)
mode="all_keys"

while getopts :f: opt
	do
		case $opt in
			f) find_access_key="$OPTARG" ; mode="find_key";;
			*) echo "Error with Options Input. Cause of failure is most likely that an unsupported parameter was passed or a parameter was passed without a corresponding option." 1>&2 ; exit 64;;
		esac
	done

#gets a list of all users for the current account
#grep "arn:aws:iam" removes return values that aren't actually IAM users. An example would be the last value returned from iam-userlistbypath which is "IsTruncated: false"
users=$(iam-userlistbypath -i 1000 | grep "arn:aws:iam" | cut -f2 -d "/")

if [[ $mode == "find_key" ]]
	then return_found_key
elif [[ $mode == "all_keys" ]]
	then return_all_keys
else
	echo "An error occured when running $app_name. $app_name will now exit." 1>&2 ; exit 70
fi