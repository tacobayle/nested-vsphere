#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# NSX download
#
download_file_from_url_to_location "${nsx_ova_url}" "/home/ubuntu/$(basename ${nsx_ova_url})" "NSX OVA"
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
# NSX options
#
list_vm=$(govc find -json vm -name "${nsx_manager_name}")
if [[ ${list_vm} != "null" ]] ; then
  echo "ERROR: unable to create VM ${nsx_manager_name}: it already exists"
else
  nsx_options=$(jq -c -r '.' /home/ubuntu/json/nsx_spec.json)
  nsx_options=$(echo ${nsx_options} | jq '. += {"Deployment": "small"}')
  nsx_options=$(echo ${nsx_options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[0] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[2] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[3] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[4] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[5] += {"Value": "'${GENERIC_PASSWORD}'"}')
  nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[5] += {"Value": "'${GENERIC_PASSWORD}'"}')
fi