#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
log_file="/tmp/deploy_nsx.log"
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
folder=$(jq -c -r '.nsx_folder' $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .spec.nsx.ip $jsonFile)"
#netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
gw_nsx=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
nsx_manager_name=$(jq -c -r '.nsx_manager_name' $jsonFile)
network_nsx=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
ova_url=$(jq -c -r .spec.nsx.ova_url $jsonFile)
#
# NSX download
#
download_file_from_url_to_location "${ova_url}" "/home/ubuntu/$(basename ${ova_url})" "NSX OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
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
echo "Creation of a folder for the NSX Manager" | tee -a ${log_file}
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder}: it already exists" | tee -a ${log_file}
else
  govc folder.create /${dc}/vm/${folder} | tee -a ${log_file}
  echo "Ending timestamp: $(date)" | tee -a ${log_file}
fi
#
# NSX options
#
nsx_options=$(jq -c -r '.' /home/ubuntu/json/nsx_spec.json)
nsx_options=$(echo ${nsx_options} | jq '. += {"Deployment": "small"}')
nsx_options=$(echo ${nsx_options} | jq '. += {"IPAllocationPolicy": "fixedPolicy"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[0] += {"Value": "'${GENERIC_PASSWORD}'"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[2] += {"Value": "'${GENERIC_PASSWORD}'"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[3] += {"Value": "'${GENERIC_PASSWORD}'"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[4] += {"Value": "'${GENERIC_PASSWORD}'"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[5] += {"Value": "'${GENERIC_PASSWORD}'"}')
nsx_options=$(echo ${nsx_options} | jq '.PropertyMapping[5] += {"Value": "'${GENERIC_PASSWORD}'"}')