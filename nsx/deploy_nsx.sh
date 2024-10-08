#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# NSX download
#
download_file_from_url_to_location "${nsx_ova_url}" "/home/ubuntu/bin/$(basename ${nsx_ova_url})" "NSX OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "ERROR: unable to connect to vCenter"
  exit
fi
#
# folder creation
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the NSX Manager"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_nsx}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_nsx}: it already exists"
else
  govc folder.create /${dc}/vm/${folder_nsx}
  echo "Ending timestamp: $(date)"
fi
#
#
#
list_vm=$(govc find -json vm -name "${nsx_manager_name}")
if [[ ${list_vm} != "null" ]] ; then
  echo "ERROR: unable to create VM ${nsx_manager_name}: it already exists"
else
  #
  # NSX options
  #
  nsx_options=$(jq -c -r '.' /home/ubuntu/json/nsx_spec.json)
  nsx_options=$(echo ${nsx_options} | jq '. += {"Deployment": "medium"}')
  nsx_options=$(echo ${nsx_options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[0] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[2] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[3] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[4] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[8] += {"Value": "'${nsx_manager_name}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[9] += {"Value": "NSX Manager"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[10] += {"Value": "'${ip_nsx}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[11] += {"Value": "255.255.255.0"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[12] += {"Value": "'${gw_avi}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[16] += {"Value": "'${ip_gw}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[17] += {"Value": "'${domain}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[18] += {"Value": "'${ip_gw}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[19] += {"Value": "True"}')
  nsx_options=$(echo ${nsx_options} | jq '.NetworkMapping[0] += {"Network": "'${network_avi}'"}')
  nsx_options=$(echo ${nsx_options} | jq '. += {"Name": "'${nsx_manager_name}'"}')
  echo ${nsx_options} | jq -c -r '.' | tee /home/ubuntu/json/options-${nsx_manager_name}.json
  #
  # NSX creation
  #
  govc import.ova --options="/home/ubuntu/json/options-${nsx_manager_name}.json" -folder "${folder_nsx}" "/home/ubuntu/bin/$(basename ${nsx_ova_url})" > /dev/null
  govc vm.power -on=true "${nsx_manager_name}" > /dev/null
  echo "NSX Manager deployed"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX Manager deployed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  echo "  +++ pausing for 180 seconds"
  sleep 180
  #
  # NSX HTTPS check
  #
  count=1
  until $(curl --output /dev/null --silent --head -k https://${ip_nsx})
  do
    echo "Attempt $count: Waiting for NSX Manager to be reachable..."
    sleep 30
    count=$((count+1))
    if [ ${count} = 60 ]; then
      echo "ERROR: Unable to connect to NSX Manager"
      exit
    fi
  done
  echo "NSX Manager reachable at https://${ip_nsx}"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX Manager reachable at https://'${ip_nsx}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
fi
exit