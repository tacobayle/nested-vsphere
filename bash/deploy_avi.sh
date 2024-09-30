#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
log_file="/tmp/deploy_avi.log"
deployment_name=$(jq -c -r .metadata.name $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .GENERIC_PASSWORD $jsonFile)
ssoDomain=$(jq -r '.spec.vsphere.ssoDomain' $jsonFile)
vsphere_nested_username="administrator"
vsphere_nested_password="${GENERIC_PASSWORD}"
dc=$(jq -c -r '.dc' $jsonFile)
vcsa_name=$(jq -c -r '.vcsa_name' $jsonFile)
domain=$(jq -c -r '.spec.domain' $jsonFile)
api_host="${vcsa_name}.${domain}"
cluster_basename=$(jq -c -r '.cluster_basename' $jsonFile)
folder=$(jq -c -r '.avi_folder' $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .spec.avi.ip $jsonFile)"
netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
gw_avi=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
avi_ctrl_name=$(jq -c -r '.avi_ctrl_name' $jsonFile)
network_avi=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
ova_url=$(jq -c -r .spec.avi.ova_url $jsonFile)
#
# Avi download
#
download_file_from_url_to_location "${ova_url}" "/home/ubuntu/$(basename ${ova_url})" "AVI OVA"
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
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder}: it already exists" | tee -a ${log_file}
else
  govc folder.create /${dc}/vm/${folder} | tee -a ${log_file}
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
govc import.ova --options="/home/ubuntu/json/options-${avi_ctrl_name}.json" -folder "${folder}" "/home/ubuntu/$(basename ${ova_url})" > /dev/null
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