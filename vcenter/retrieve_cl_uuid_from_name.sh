#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
#
# vCenter API session creation
#
api_host=$1
vsphere_nested_username=administrator
vcenter_domain=$2
vsphere_nested_password=$3
cl_name=$4
json_output_file=$5
key=$6
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Retrieve storage policy
#
vcenter_api 6 10 "GET" $token '' $api_host "api/content/library"
list_uuid=${response_body}
echo ${list_uuid} | jq -c -r .[] | while read item
do
  vcenter_api 6 10 "GET" $token '' $api_host "api/content/library/${item}"
  if [[ $(echo ${response_body} | jq -c -r '.name') == ${cl_name} ]]; then
    echo '{"'${key}'":"'${item}'"}' | tee ${json_output_file}
    break
  fi
done