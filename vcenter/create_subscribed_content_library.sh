#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
#
# vCenter API session creation
#
api_host="${1}"
vsphere_nested_username=administrator
vcenter_domain="${2}"
vsphere_nested_password="${3}"
subscription_url="${4}"
content_library_type="${5}"
content_library_automatic_sync_enabled="${6}"
content_library_on_demand="${7}"
content_library_name="${8}"
datastore="${9}"
json_output_file="${10}"

#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Create Content Library for tanzu
#
vcenter_api 6 10 "GET" $token '' $api_host "rest/vcenter/datastore"
#datastore_id=$(echo $response_body | jq -c -r .value[0].datastore)
datastore_id=$(echo $response_body | jq -c -r --arg arg ${datastore} '.value[] | select(.name == $arg) | .datastore')
ValidCmThumbPrint=$(openssl s_client -connect $(echo $subscription_url  | cut -d"/" -f3):443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -in /dev/stdin | awk -F'Fingerprint=' '{print $2}')
json_data='
{
  "storage_backings":
  [
    {
      "datastore_id":"'${datastore_id}'",
      "type":"DATASTORE"
    }
  ],
  "type": "'${content_library_type}'",
  "version":"2",
  "subscription_info":
    {
      "authentication_method":"NONE",
      "ssl_thumbprint":"'${ValidCmThumbPrint}'",
      "automatic_sync_enabled": "'${content_library_automatic_sync_enabled}'",
      "subscription_url": "'${subscription_url}'",
      "on_demand": "'${content_library_on_demand}'"
    },
  "name": "'${content_library_name}'"
}'
vcenter_api 6 10 "POST" $token "${json_data}" $api_host "api/content/subscribed-library"
content_library_id=$(echo $response_body | tr -d '"')
echo "   +++ testing if variable content_library_id is not empty" ; if [ -z "$content_library_id" ] ; then exit 255 ; fi
echo '{"content_library_id":"'${content_library_id}'"}' | tee ${json_output_file}