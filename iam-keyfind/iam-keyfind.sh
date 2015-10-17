#!/bin/bash -
# Author: Colin Johnson / colin@cloudavail.com
# Date: 2015-10-17
# Version 0.2
# License Type: GNU GENERAL PUBLIC LICENSE, Version 3

# confirms that executables required for succesful script execution are
# available
prerequisite_check() {
  for prerequisite in basename aws ; do
    # use of "hash" chosen as it is a shell builtin and will add programs to 
    # hash table, possibly speeding execution. Use of type also considered - open to suggestions.
    hash $prerequisite &> /dev/null
    if [[ $? == 1 ]] ; then
      echo "In order to use $(basename $0), the executable \"$prerequisite\" must be installed." 1>&2 ; exit 70
    fi
  done
}

get_all_keys() {
  for user in $users ; do
    access_keys=$(aws iam list-access-keys --user-name $user --query AccessKeyMetadata[*].AccessKeyId --output text)
    for access_key in $access_keys ; do
      echo "$user,$access_key"
    done
  done
}

find_key() {
  key_found=false
  users_examined=0
  user_containing_key=""
  for user in $users ; do
    access_keys=$(aws iam list-access-keys --user-name $user --query AccessKeyMetadata[*].AccessKeyId --output text)
    for access_key in $access_keys ; do
      if [[ "$find_access_key" == "$access_key" ]] ; then 
        key_found=true
        user_containing_key=$user
        break
      else
        users_examined=$((users_examined + 1))
      fi
    done
  done
  if $key_found ; then
    echo "The Access Key \"$find_access_key\" belongs to the IAM user named \"$user_containing_key.\""
  else
    echo "The Access Key \"$find_access_key\" does not belong to any IAM users. $app_name examined a total of $users_examined users."
  fi
}

# calls prerequisitecheck function to ensure that all executables required for
# script execution are available
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

# gets a list of all users for the current account
users=$(aws iam list-users --query Users[*].UserName --output text)

if [[ $mode == "find_key" ]]
  then find_key
elif [[ $mode == "all_keys" ]]
  then get_all_keys
else
  echo "An error occured when running $app_name. $app_name will now exit." 1>&2 ; exit 70
fi
