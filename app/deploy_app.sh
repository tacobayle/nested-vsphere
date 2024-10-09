#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# Ubuntu download
#
download_file_from_url_to_location "${ubuntu_ova_url}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})" "Ubuntu OVA"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Ubuntu OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
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
# content library creation
#
govc library.create ubuntu
govc library.import ubuntu "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
#
# folder creation for app
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Apps"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_app}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_app}: it already exists"
else
  govc folder.create /${dc}/vm/${folder_app}
  echo "Ending timestamp: $(date)"
fi
#
# folder creation for client
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Apps"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_client}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_client}: it already exists"
else
  govc folder.create /${dc}/vm/${folder_client}
  echo "Ending timestamp: $(date)"
fi
#
# Client VM creations first group // vsphere-avi use case)
#
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    ip_client="${cidr_vip_three_octets}.$(echo ${ips_clients} | jq -c -r .[$(expr ${index} - 1)])"
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${client_basename}${index}/" \
        -e "s/\${ip_app}/${ip_client}/" \
        -e "s/\${prefix}/${prefix_client}/" \
        -e "s/\${packages}/${app_apt_packages}/" \
        -e "s/\${default_gw}/${gw_client}/" \
        -e "s/\${forwarders_netplan}/${gw_client}/" /home/ubuntu/templates/userdata_client.yaml.template | tee /home/ubuntu/app/userdata_client${index}.yaml
    #
    sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_client${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_client}@" \
        -e "s/\${vm_name}/${client_basename}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-client-${index}.json"
    #
#    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc library.deploy -options "/home/ubuntu/app/options-client-${index}.json" -folder "${folder_client}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
    govc vm.change -vm "${folder_client}/${client_basename}${index}" -c ${client_cpu} -m ${client_memory}
    govc vm.power -on=true "${folder_client}/${client_basename}${index}"
  done
fi
#
# App VM creations first group // vsphere-avi use case)
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    ip_app="${cidr_app_three_octets}.$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${app_basename}${index}/" \
        -e "s/\${ip_app}/${ip_app}/" \
        -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
        -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
        -e "s/\${app_tcp_default}/${app_tcp_default}/" \
        -e "s/\${app_tcp_waf}/${app_tcp_waf}/" \
        -e "s@\${docker_registry_repo_default_app}@${docker_registry_repo_default_app}@" \
        -e "s@\${docker_registry_repo_waf}@${docker_registry_repo_waf}@" \
        -e "s/\${prefix}/${prefix_app}/" \
        -e "s/\${packages}/${app_apt_packages}/" \
        -e "s/\${default_gw}/${gw_app}/" \
        -e "s/\${forwarders_netplan}/${gw_app}/" /home/ubuntu/templates/userdata_app.yaml.template | tee /home/ubuntu/app/userdata_app${index}.yaml
    #
    sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_app}@" \
        -e "s/\${vm_name}/${app_basename}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-${index}.json"
    #
#    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc library.deploy -options "/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
    govc vm.change -vm "${folder_app}/${app_basename}${index}" -c ${app_cpu} -m ${app_memory}
    govc vm.power -on=true "${folder_app}/${app_basename}${index}"
  done
fi
#
# App VM creations second group // vsphere-avi use case)
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    ip_app="${cidr_app_three_octets}.$(echo ${ips_app_second} | jq -c -r .[$(expr ${index} - 1)])"
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${app_basename_second}${index}/" \
        -e "s/\${ip_app}/${ip_app}/" \
        -e "s/\${prefix}/${prefix_app}/" \
        -e "s/\${packages}/${app_apt_packages}/" \
        -e "s/\${default_gw}/${gw_app}/" \
        -e "s/\${forwarders_netplan}/${gw_app}/" /home/ubuntu/templates/userdata_app_second.yaml.template | tee /home/ubuntu/app/userdata_app_second${index}.yaml
    #
    sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app_second${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_app}@" \
        -e "s/\${vm_name}/${app_basename_second}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-second-${index}.json"
    #
#    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc library.deploy -options "/home/ubuntu/app/options-app-second-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
    govc vm.change -vm "${folder_app}/${app_basename_second}${index}" -c ${app_cpu} -m ${app_memory}
    govc vm.power -on=true "${folder_app}/${app_basename}${index}"
  done
fi
#
# VM client connectivity
#
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    ip_client="${cidr_app_three_octets}.$(echo ${ips_clients} | jq -c -r .[$(expr ${index} - 1)])"
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify VM app ${ip_client} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_client}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "VM client ${ip_client} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VM client '${ip_client}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      else
        echo "VM client ${ip_client} is not reachable."
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "VM client ${ip_client} is not reachable after $attempt attempt"
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi
#
# VM app connectivity first group
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    ip_app="${cidr_app_three_octets}.$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify VM app ${ip_app} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "VM app ${ip_app} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VM app '${ip_app}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      else
        echo "VM app ${ip_app} is not reachable."
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "VM app ${ip_app} is not reachable after $attempt attempt"
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi
#
# VM app connectivity second group
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    ip_app="${cidr_app_three_octets}.$(echo ${ips_app_second} | jq -c -r .[$(expr ${index} - 1)])"
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify VM app ${ip_app} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "VM app ${ip_app} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VM app '${ip_app}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      else
        echo "VM app ${ip_app} is not reachable."
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "VM app ${ip_app} is not reachable after $attempt attempt"
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi