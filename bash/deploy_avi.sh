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
api_host="${vcsa_name}.${domain}"
cluster_basename=$(jq -c -r '.cluster_basename' $jsonFile)
folder=$(jq -c -r '.avi_folder' $jsonFile)
load_govc_env_with_cluster "${cluster_basename}1"
#
# folder creation
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Avi ctrl" | tee -a ${log_file}
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder}: it already exists" | tee -a ${log_file}
  exit
else
  govc folder.create /${dc}/vm/${folder} | tee -a ${log_file}
  echo "Ending timestamp: $(date)" | tee -a ${log_file}
fi
#
# Avi ctrl creation
#
ova_url=$(jq -c -r .spec.avi.ova_url $jsonFile)
download_file_from_url_to_location "${ova_url}" "/home/ubuntu/$(basename ${ova_url})" "AVI OVA"
#
avi_spec=$(jq '.' /home/ubuntu/json/avi_spec.json)

sed -e "s#\${public_key}#$(awk '{printf "%s\\n", $0}' /root/.ssh/id_rsa.pub | awk '{length=$0; print substr($0, 1, length-2)}')#" \
    -e "s@\${base64_userdata}@$(base64 /tmp/${gw_name}_userdata.yaml -w 0)@" \
    -e "s/\${EXTERNAL_GW_PASSWORD}/${GENERIC_PASSWORD}/" \
    -e "s@\${network_ref}@${network_ref_gw}@" \
    -e "s/\${gw_name}/${gw_name}/" /nested-vsphere/templates/options-gw.json.template | tee "/tmp/options-${gw_name}.json"
#
govc import.ova --options="/tmp/options-${gw_name}.json" -folder "${folder}" "/root/$(basename ${ova_url})" | tee -a ${log_file}
govc vm.change -vm "${folder}/${gw_name}" -c $(jq -c -r .gw.cpu $jsonFile) -m $(jq -c -r .gw.memory $jsonFile)
govc vm.network.add -vm "${folder}/${gw_name}" -net "${trunk1}" -net.adapter vmxnet3 | tee -a ${log_file}
govc vm.disk.change -vm "${folder}/${gw_name}" -size $(jq -c -r .gw.disk $jsonFile)
govc vm.power -on=true "${gw_name}" | tee -a ${log_file}



