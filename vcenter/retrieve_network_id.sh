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
network_name=$4
json_output_file=$5
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Retrieve Network details and dvportgroup(s)
#
vcenter_api 6 10 "GET" $token '' $api_host "api/vcenter/network"
network_id=$(echo $response_body | jq -r --arg pg "${network_name}" '.[] | select(.name == $pg) | .network')
#echo $tanzu_supervisor_dvportgroup
echo "   +++ testing if variable network_id is not empty" ; if [ -z "$network_id" ] ; then exit 255 ; fi
echo '{"network_id":"'${network_id}'"}' | tee ${json_output_file}