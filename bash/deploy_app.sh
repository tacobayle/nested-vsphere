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
# App VM creations // vsphere-avi use case)
#
if [[ ${ip_apps} != "null" ]]; then
  for index in $(seq 1 $(echo ${ip_apps} | jq -c -r '. | length'))
  do
    ip_app="${cidr_app_three_octets}.$(echo ${ip_apps} | jq -c -r .[$(expr ${index} - 1)])"
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
    sed -e "s#\${public_key}#$(awk '{printf "%s\\n", $0}' /home/ubuntu/.ssh/id_rsa.pub | awk '{length=$0; print substr($0, 1, length-2)}')#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_app}@" \
        -e "s/\${vm_name}/${app_basename}${index}/" /home/ubuntu/templates/options-app.json.template | tee "/home/ubuntu/templates/options-app-${index}.json"
    #
    govc import.ova --options="/home/ubuntu/templates/options-app-${index}.json" -folder "${app_folder}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc vm.change -vm "${app_folder}/${app_basename}${index}" -c ${app_cpu} -m ${app_memory}
    govc vm.power -on=true "${app_folder}/${app_basename}${index}"
  done
fi