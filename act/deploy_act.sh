#!/bin/bash
#
echo "Starting timestamp: $(date)"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
netmask_act=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
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
echo "Creation of a folder for act"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${act_folder}'")' >/dev/null ) ; then
  echo "$(date): ERROR: unable to create folder ${act_folder}: it already exists"
else
  govc folder.create /${dc}/vm/${act_folder}
  echo "$(date): Folder created"
fi
#
# act creation
#
list_vm=$(govc find -json -type m -name "${act_name}")
if [[ ${list_vm} != "null" ]] ; then
  echo "$(date): ERROR: unable to create VM ${act_name}: it already exists"
  echo "Ending timestamp: $(date)"
  exit
else
  #
  # act options
  #
  options=$(jq -c -r '.' /home/ubuntu/templates/act/act_spec.json)
  options=$(echo ${options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
  options=$(echo ${options} | jq '.PropertyMapping[0] += {"Value": "'${act_name}'.'${domain}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[4] += {"Value": "'${GENERIC_PASSWORD}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[5] += {"Value": "True"}')
  options=$(echo ${options} | jq '.PropertyMapping[6] += {"Value": "'${ip_act}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[7] += {"Value": "'${netmask_act}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[8] += {"Value": "'${ip_gw_mgmt}'"}')
  options=$(echo ${options} | jq '.PropertyMapping[9] += {"Value": "'${ip_gw}'"}')
  options=$(echo ${options} | jq '.NetworkMapping[0] += {"Network": "'${network_avi}'"}')
  options=$(echo ${options} | jq '. += {"Name": "'${act_name}'"}')
  echo ${options} | jq -c -r '.' | tee /home/ubuntu/json/options-${act_name}.json
  #
  # act Creation
  #
  govc import.ova --options="/home/ubuntu/json/options-${act_name}.json" -folder "${act_folder}" "/home/ubuntu/bin/$(basename ${act_ova_url})" > /dev/null
  govc vm.power -on=true "${act_name}" > /dev/null
  echo "$(date): act deployed"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': act deployed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
fi
echo "Ending timestamp: $(date)"
exit