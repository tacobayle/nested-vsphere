#!/bin/bash
#
jsonFile="${1}"
resultFile="${2}"
rm -f ${resultFile}
source /home/ubuntu/bash/functions.sh
source /home/ubuntu/bash/log_message.sh
source /home/ubuntu/bash/variables.sh
log_message "${deployment_name}:------------------------------------------------------------" "" "" ""
log_message "${deployment_name}: Deployment of ACT  - This should take about 20 minutes" "" "${slack_webhook}" "${google_webhook}"
netmask_act=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  log_message "${deployment_name}: ERROR: unable to connect to vCenter" "" "${slack_webhook}" "${google_webhook}"
  exit
fi
#
# folder creation
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for act"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_act}'")' >/dev/null ) ; then
  log_message "${deployment_name}: ERROR: unable to create folder ${folder_act}: it already exists" "" "" ""
else
  govc folder.create /${dc}/vm/${folder_act}
fi
#
# act creation
#
list_vm=$(govc find -json -type m -name "${act_name}")
if [[ ${list_vm} != "null" ]] ; then
  log_message "${deployment_name}: ERROR: unable to create VM ${act_name}: it already exists "" "" """
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
  govc import.ova --options="/home/ubuntu/json/options-${act_name}.json" -folder "${folder_act}" "/home/ubuntu/bin/$(basename ${act_ova_url})" > /dev/null
  govc vm.power -on=true "${act_name}" > /dev/null
  log_message "${deployment_name}: ACT VM deployed" "" "${slack_webhook}" "${google_webhook}"
fi
touch ${resultFile}
exit