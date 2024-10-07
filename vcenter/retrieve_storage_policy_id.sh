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
storage_policy=$4
json_output_file=$5
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Retrieve storage policy
#
vcenter_api 6 10 "GET" $token '' $api_host "api/vcenter/storage/policies"
storage_policy_id=$(echo $response_body | jq -r --arg policy "${storage_policy}" '.[] | select(.name == $policy) | .policy')
#echo $storage_policy_id
echo "   +++ testing if variable storage_policy_id is not empty" ; if [ -z "$storage_policy_id" ] ; then exit 255 ; fi
echo '{"storage_policy_id":"'${storage_policy_id}'"}' | tee ${json_output_file}