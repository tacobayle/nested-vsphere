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
cluster_name=$4
json_output_file=$5
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Retrieve cluster id
#
vcenter_api 6 10 "GET" $token '' $api_host "api/vcenter/cluster"
cluster_id=$(echo $response_body | jq -r --arg cluster "${cluster_name}" '.[] | select(.name == $cluster).cluster')
#echo $cluster_id
echo "   +++ testing if variable cluster_id is not empty" ; if [ -z "$cluster_id" ] ; then exit 255 ; fi
echo '{"cluster_id":"'${cluster_id}'"}' | tee ${json_output_file}