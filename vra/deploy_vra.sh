#!/bin/bash
#
jsonFile="${1}"
resultFile="${2}"
rm -f ${resultFile}
source /home/ubuntu/bash/functions.sh
source /home/ubuntu/bash/log_message.sh
source /home/ubuntu/bash/variables.sh
log_message "${deployment_name}:------------------------------------------------------------" "" "" ""
log_message "${deployment_name}: Deployment of VRA  - This should take about 20 minutes" "" "${slack_webhook}" "${google_webhook}"
netmask_vra=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
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
echo "Creation of a folder for VRA"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_vra}'")' >/dev/null ) ; then
  log_message "${deployment_name}: ERROR: unable to create folder ${folder_vra}: it already exists" "" "" ""
else
  govc folder.create /${dc}/vm/${folder_vra}
fi
#
# vra creation
#
list_vm=$(govc find -json -type m -name "${vra_name}")
if [[ ${list_vm} != "null" ]] ; then
  log_message "${deployment_name}: ERROR: unable to create VM ${vra_name}: it already exists "" "" """
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
  govc import.ova --options="/home/ubuntu/json/options-${vra_name}.json" -folder "${folder_vra}" "/home/ubuntu/bin/$(basename ${vra_ova_url})" > /dev/null
  govc vm.power -on=true "${vra_name}" > /dev/null
  log_message "${deployment_name}: VRA VM deployed" "" "${slack_webhook}" "${google_webhook}"
fi
touch ${resultFile}
exit