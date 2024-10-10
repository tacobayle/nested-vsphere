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
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Wait for supervisor cluster to be running
#
retry_tanzu_supervisor=121
pause_tanzu_supervisor=60
attempt_tanzu_supervisor=1
while true ; do
  echo "attempt ${attempt_tanzu_supervisor} to get supervisor cluster config_status RUNNING and kubernetes_status READY"
  vcenter_api 6 10 "GET" $token '' $api_host "api/vcenter/namespace-management/clusters"
  if [[ $(echo $response_body | jq -c -r .[0].config_status) == "RUNNING" && $(echo $response_body | jq -c -r .[0].kubernetes_status) == "READY" ]]; then
    echo "supervisor config_status is $(echo $response_body | jq -c -r .[0].config_status) and kubernetes_status is $(echo $response_body | jq -c -r .[0].kubernetes_status) after ${attempt_tanzu_supervisor} attempts of ${pause_tanzu_supervisor} seconds"
    break 2
  fi
  ((attempt_tanzu_supervisor++))
  if [ ${attempt_tanzu_supervisor} -eq ${retry_tanzu_supervisor} ]; then
    echo "Unable to get supervisor cluster config_status RUNNING and kubernetes_status READY after ${attempt_tanzu_supervisor} attempts of ${pause_tanzu_supervisor} seconds"
    exit
  fi
  sleep ${pause_tanzu_supervisor}
done