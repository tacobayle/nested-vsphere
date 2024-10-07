#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
api_host="${1}"
vsphere_nested_username=administrator
vcenter_domain="${2}"
vsphere_nested_password="${3}"
vm_classes="${4}"
storage_policy_id="${5}"
ns_name="${6}"
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
# Create Namespace
#
json_data='
{
  "cluster": "'${cluster_id}'",
  "access_list": [
    {
      "role": "OWNER",
      "subject_type": "USER",
      "subject": "Administrator",
      "domain": "'${vcenter_domain}'"
    }
  ],
  "vm_service_spec": {
    "vm_classes": '${vm_classes}',
    "content_libraries": []
  },
  "storage_specs": [
    {
      "policy": "'${storage_policy_id}'"
    }
  ],
  "namespace": "'${ns_name}'"
}'
echo $json_data | jq .
vcenter_api 6 10 "POST" $token "${json_data}" $api_host "api/vcenter/namespaces/instances"