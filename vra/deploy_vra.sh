#!/bin/bash
#
echo "Starting timestamp: $(date)"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
netmask_vra=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
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
echo "Creation of a folder for VRA"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${vra_folder}'")' >/dev/null ) ; then
  echo "$(date): ERROR: unable to create folder ${vra_folder}: it already exists"
else
  govc folder.create /${dc}/vm/${vra_folder}
  echo "$(date): Folder created"
fi
#
# vra creation
#
list_vm=$(govc find -json -type m -name "${vra_name}")
if [[ ${list_vm} != "null" ]] ; then
  echo "$(date): ERROR: unable to create VM ${vra_name}: it already exists"
  echo "Ending timestamp: $(date)"
  exit
else
  #
  # VRA options
  #
  options=$(jq -c -r '.' /home/ubuntu/templates/vra/vra_spec.json)
  options=$(echo ${options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
  options=$(echo ${options} | jq '. += {"Deployment": "'${vra_deployment}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[0] += {"Value": "'${vra_name}'.'${domain}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[1] += {"Value": "'${GENERIC_PASSWORD}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[2] += {"Value": "True"}')
  options=$(echo ${options} | jq '.PropertyMapping[5] += {"Value": "'${ip_gw}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[8] += {"Value": "'${ip_gw_mgmt}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[11] += {"Value": "'${ip_gw}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[12] += {"Value": "'${ip_vra}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[13] += {"Value": "'${netmask_vra}'"}')
  options=$(echo ${options} | jq '.NetworkMapping[0] += {"Network": "'${network_avi}'"}')
  options=$(echo ${options} | jq '. += {"Name": "'${vra_name}'"}')
  echo ${options} | jq -c -r '.' | tee /home/ubuntu/json/options-${vra_name}.json
  #
  # VRA Creation
  #
  govc import.ova --options="/home/ubuntu/json/options-${vra_name}.json" -folder "${vra_folder}" "/home/ubuntu/bin/$(basename ${vra_ova_url})" > /dev/null
  govc vm.power -on=true "${vra_name}" > /dev/null
  echo "$(date): VRA deployed"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VRA deployed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
fi
echo "Ending timestamp: $(date)"
exit