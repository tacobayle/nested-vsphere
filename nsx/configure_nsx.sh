#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# check NSX Manager
#
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:${GENERIC_PASSWORD} -k -s -o /dev/null -w ''%{http_code}'' https://$${ip_nsx}/api/v1/cluster/status)" != "200" ]]; do
  echo "waiting for NSX Manager API to be ready"
  sleep ${pause}
  ((attempt++))
  if [ ${attempt} -eq ${retry} ]; then
    echo "FAILED to get NSX Manager API to be ready after ${retry}"
    exit
  fi
done
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:${GENERIC_PASSWORD} -k -s  https://$${ip_nsx}/api/v1/cluster/status | jq -r .detailed_cluster_status.overall_status)" != "STABLE" ]]; do
  echo "waiting for NSX Manager API to be STABLE"
  sleep ${pause}
  ((attempt++))
  if [ ${attempt} -eq ${retry} ]; then
    echo "FAILED to get NSX Manager API to be STABLE after ${retry}"
    exit
  fi
done
echo "NSX Manager ready at https://${ip_nsx}"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX Manager ready at https://'${ip_nsx}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# https://docs.vmware.com/en/VMware-NSX/4.1/administration/GUID-4ABD4548-4442-405D-AF04-6991C2022137.html
#
