#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
#
api_host="${1}"
vsphere_nested_username=administrator
vcenter_domain="${2}"
vsphere_nested_password="${3}"
json_output_file="${4}"
#
# vCenter API session creation
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# retrieve cluster id
#
vcenter_api 3 5 "GET" $token '' "${api_host}" "api/vcenter/namespace-management/clusters"
cluster_id=$(echo $response_body | jq -c -r .[0].cluster)
#
# Retrieve API server cluster endpoint
#
vcenter_api 6 10 "GET" $token '' $api_host "api/vcenter/namespace-management/clusters/${cluster_id}"
api_server_cluster_endpoint=$(echo $response_body | jq -c -r .api_server_cluster_endpoint)
echo "   +++ testing if variable api_server_cluster_endpoint is not empty" ; if [ -z "${api_server_cluster_endpoint}" ] ; then exit 255 ; fi
echo '{"api_server_cluster_endpoint": "'${api_server_cluster_endpoint}'"}' | tee ${json_output_file}