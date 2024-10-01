#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
log_file="/tmp/deploy_avi.log"
source /home/ubuntu/bash/variables.sh
netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
#
# Avi download
#
download_file_from_url_to_location "${avi_ova_url}" "/home/ubuntu/$(basename ${avi_ova_url})" "AVI OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "ERROR: unable to connect to vCenter" | tee -a ${log_file}
  exit
fi
#
# folder creation
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Avi ctrl" | tee -a ${log_file}
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_avi}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_avi}: it already exists" | tee -a ${log_file}
else
  govc folder.create /${dc}/vm/${folder_avi} | tee -a ${log_file}
  echo "Ending timestamp: $(date)" | tee -a ${log_file}
fi
#
# Avi options
#
avi_options=$(jq -c -r '.' /home/ubuntu/json/avi_spec.json)
avi_options=$(echo ${avi_options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
avi_options=$(echo ${avi_options} | jq '.PropertyMapping[0] += {"Value": "'${ip_avi}'"}')
avi_options=$(echo ${avi_options} | jq '.PropertyMapping[1] += {"Value": "'${netmask_avi}'"}')
avi_options=$(echo ${avi_options} | jq '.PropertyMapping[2] += {"Value": "'${gw_avi}'"}')
avi_options=$(echo ${avi_options} | jq '.PropertyMapping[11] += {"Value": "'${avi_ctrl_name}'"}')
avi_options=$(echo ${avi_options} | jq '.NetworkMapping[0] += {"Network": "'${network_avi}'"}')
avi_options=$(echo ${avi_options} | jq '. += {"Name": "'${avi_ctrl_name}'"}')
echo ${avi_options} | jq -c -r '.' | tee /home/ubuntu/json/options-${avi_ctrl_name}.json
#
# Avi Creation
#
govc import.ova --options="/home/ubuntu/json/options-${avi_ctrl_name}.json" -folder "${folder_avi}" "/home/ubuntu/$(basename ${avi_ova_url})" > /dev/null
govc vm.power -on=true "${avi_ctrl_name}" > /dev/null
echo "Avi ctrl deployed" | tee -a ${log_file}
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl deployed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# Avi HTTPS check
#
echo "pausing for 180 seconds" | tee -a ${log_file}
sleep 180
count=1
until $(curl --output /dev/null --silent --head -k https://${ip_avi})
do
  echo "  +++ Attempt ${count}: Waiting for Avi ctrl at https://${ip_avi} to be reachable..." | tee -a ${log_file}
  sleep 10
  count=$((count+1))
    if [[ "${count}" -eq 90 ]]; then
      echo "  +++ ERROR: Unable to connect to Avi ctrl at https://${ip_avi}" | tee -a ${log_file}
      exit
    fi
done
echo "Avi ctrl reachable at https://${ip_avi}" | tee -a ${log_file}
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl reachable at https://'${ip_avi}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
exit