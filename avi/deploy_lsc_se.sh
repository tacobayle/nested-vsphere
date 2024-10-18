#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
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
# Ubuntu download
#
download_file_from_url_to_location "${lsc_ova_url}" "/home/ubuntu/bin/$(basename ${lsc_ova_url})" "Ubuntu OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Ubuntu LSC SE OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# folder creation for app
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Apps"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${avi_lsc_se_folder}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${avi_lsc_se_folder}: it already exists"
else
  govc folder.create /${dc}/vm/${avi_lsc_se_folder}
  echo "Ending timestamp: $(date)"
fi
#
# SEs LSC VM creation
#
if [[ ${lsc_ips_mgmt} != "null" ]]; then
  for index in $(seq 1 $(echo ${lsc_ips_mgmt} | jq -c -r '. | length'))
  do
    ip_lsc_se_mgmt=$(echo ${lsc_ips_mgmt} | jq -c -r .[$(expr ${index} - 1)])
    ip_lsc_backend=$(echo ${lsc_ips_backend} | jq -c -r .[$(expr ${index} - 1)])
    ip_lsc_vip=$(echo ${lsc_ips_vip} | jq -c -r .[$(expr ${index} - 1)])
    sed -e "s#\${pubkey}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s#\${ip_mgmt}#${ip_lsc_se_mgmt}#" \
        -e "s#\${netmask_mgmt}#255.255.255.0#" \
        -e "s#\${gw_mgmt}#${gw_avi_se}#" \
        -e "s#\${dns}#${ip_gw}#" \
        -e "s#\${ip_backend}#${ip_lsc_backend}#" \
        -e "s#\${netmask_backend}#255.255.255.0#" \
        -e "s#\${ip_vip}#${ip_lsc_vip}#" \
        -e "s#\${netmask_vip}#255.255.255.0#" \
        -e "s/\${kernelVersion}/${avi_lsc_kernel_version}${index}/" /home/ubuntu/templates/userdata_lsc_se.yaml.template | tee /home/ubuntu/avi/userdata_lsc_se_${index}.yaml
    #
    sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/avi/userdata_lsc_se_${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@avi-se-mgmt@" \
        -e "s/\${vm_name}/${avi_lsc_se_basename}${index}/" /nested-vsphere/templates/options-ubuntu.json.template > "/home/ubuntu/avi/options-${avi_lsc_se_basename}${index}.json"
    #
    govc import.ova --options="/home/ubuntu/avi/options-${avi_lsc_se_basename}${index}.json" -folder "${avi_lsc_se_folder}" "/home/ubuntu/bin/$(basename ${lsc_ova_url})" > /dev/null 2>&1
    govc vm.change -vm "${avi_lsc_se_folder}/${avi_lsc_se_basename}${index}" -c ${avi_lsc_se_cpu} -m ${avi_lsc_se_memory}
    govc vm.network.add -vm "${avi_lsc_se_folder}/${avi_lsc_se_basename}${index}" -net "avi-app-backend" -net.adapter vmxnet3 > /dev/null 2>&1
    govc vm.network.add -vm "${avi_lsc_se_folder}/${avi_lsc_se_basename}${index}" -net "avi-vip" -net.adapter vmxnet3 > /dev/null 2>&1
    govc vm.disk.change -vm "${avi_lsc_se_folder}/${avi_lsc_se_basename}${index}" -size ${avi_lsc_se_disk}
  done
fi
#
# SEs LSC check
#
if [[ ${lsc_ips_mgmt} != "null" ]]; then
  for index in $(seq 1 $(echo ${lsc_ips_mgmt} | jq -c -r '. | length'))
  do
    ip_lsc_se_mgmt=$(echo ${lsc_ips_mgmt} | jq -c -r .[$(expr ${index} - 1)])
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify SE LSC ${ip_lsc_se_mgmt} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_lsc_se_mgmt}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "SE LSC ${ip_lsc_se_mgmt} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': SE LSC '${ip_lsc_se_mgmt}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      else
        echo "SE LSC ${ip_lsc_se_mgmt} is not reachable."
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "SE LSC ${ip_lsc_se_mgmt} is not reachable after $attempt attempt"
        break
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi

