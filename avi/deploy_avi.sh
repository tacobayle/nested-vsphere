#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
#
# Avi download
#
download_file_from_url_to_location "${avi_ova_url}" "/home/ubuntu/bin/$(basename ${avi_ova_url})" "AVI OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
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
echo "Creation of a folder for the Avi ctrl"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_avi}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_avi}: it already exists"
else
  govc folder.create /${dc}/vm/${folder_avi}
  echo "Ending timestamp: $(date)"
fi
#
# avi ctrl creation
#
list_vm=$(govc find -json vm -name "${avi_ctrl_name}")
if [[ ${list_vm} != "null" ]] ; then
  echo "ERROR: unable to create VM ${avi_ctrl_name}: it already exists"
else
  #
  # Avi options
  #
  avi_options=$(jq -c -r '.' /home/ubuntu/json/avi_spec.json)
  avi_options=$(echo ${avi_options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
  avi_options=$(echo ${avi_options} | jq '.PropertyMapping[0] += {"Value": "'${ip_avi}'"}')
  avi_options=$(echo ${avi_options} | jq '.PropertyMapping[1] += {"Value": "'${netmask_avi}'"}')
  avi_options=$(echo ${avi_options} | jq '.PropertyMapping[2] += {"Value": "'${ip_gw_mgmt}'"}')
  avi_options=$(echo ${avi_options} | jq '.PropertyMapping[11] += {"Value": "'${avi_ctrl_name}'"}')
  avi_options=$(echo ${avi_options} | jq '.NetworkMapping[0] += {"Network": "'${network_avi}'"}')
  avi_options=$(echo ${avi_options} | jq '. += {"Name": "'${avi_ctrl_name}'"}')
  echo ${avi_options} | jq -c -r '.' | tee /home/ubuntu/json/options-${avi_ctrl_name}.json
  #
  # Avi Creation
  #
  govc import.ova --options="/home/ubuntu/json/options-${avi_ctrl_name}.json" -folder "${folder_avi}" "/home/ubuntu/bin/$(basename ${avi_ova_url})" > /dev/null
  govc vm.power -on=true "${avi_ctrl_name}" > /dev/null
  echo "Avi ctrl deployed"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl deployed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
fi
exit