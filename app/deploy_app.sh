#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# k8s templating k8s script config
#
sed -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
    -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
    -e "s/\${docker_registry_email}/${DOCKER_REGISTRY_EMAIL}/" /home/ubuntu/templates/k8s-config.sh.template | tee "/home/ubuntu/k8s/k8s-config.sh"
#
# ako values templating
#
serviceEngineGroupName="Default-Group"
shardVSSize="SMALL"
serviceType="ClusterIP"
disableStaticRouteSync="false" # needs to be true if NodePortLocal is enabled
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version="$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')"
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    if [[ ${cni} == "antrea" ]]; then
      disableStaticRouteSync="true"
      serviceType="NodePortLocal"
    fi
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    if [[ ${kind} == "vsphere-avi" ]]; then
      nsxtT1LR="''"
      avi_cloud_name="Default-Cloud"
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      file_json_output="/home/ubuntu/nsx/tier-1s.json"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/tier-1s" \
                  "${file_json_output}"
      connectivity_path=$(jq -c -r --arg arg1 "$(echo ${segments_overlay} | jq -r -c '.[] | select(.display_name == "segment-vip-1").tier1')" '.results[] | select(.display_name == $arg1).path' ${file_json_output})
      nsxtT1LR="${connectivity_path}"
      avi_cloud_name="${nsx_cloud_name}"
      network_ref_vip=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == true).display_name')
      cidr_vip_full=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == true).cidr')
    fi
    sed -e "s/\${disableStaticRouteSync}/${disableStaticRouteSync}/" \
        -e "s/\${clusterName}/${k8s_basename}${index}/" \
        -e "s/\${cniPlugin}/${cni}/" \
        -e "s@\${nsxtT1LR}@${nsxtT1LR}@" \
        -e "s/\${networkName}/${network_ref_vip}/" \
        -e "s@\${cidr}@${cidr_vip_full}@" \
        -e "s/\${serviceType}/${serviceType}/" \
        -e "s/\${shardVSSize}/${shardVSSize}/" \
        -e "s/\${serviceEngineGroupName}/${serviceEngineGroupName}/" \
        -e "s/\${controllerVersion}/${avi_version}/" \
        -e "s/\${cloudName}/${avi_cloud_name}/" \
        -e "s/\${controllerHost}/${ip_avi}/" \
        -e "s/\${tenant}/${k8s_basename}${index}/" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/values.yml.1.12.1.template | tee /home/ubuntu/k8s/ako_${k8s_basename}${index}_values.yml > /dev/null
  done
fi
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
# folder creation for k8s cluster
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for k8s clusters"
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${k8s_basename}${index}'")' >/dev/null ) ; then
      echo "ERROR: unable to create folder ${k8s_basename}${index}: it already exists"
    else
      govc folder.create /${dc}/vm/${k8s_basename}${index}
      echo "Ending timestamp: $(date)"
    fi
  done
fi
#
# Client VMs client creation
#
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_client_list} | jq -c -r '. | length')-1)))
    do
      ip_client="$(echo ${net_client_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_clients} | jq -c -r .[$(expr ${index} - 1)])"
      prefix_client="$(echo ${net_client_list} | jq -r -c '.['${net}'].cidr' | cut -d"/" -f2)"
      gw_client="$(echo ${net_client_list} | jq -r -c '.['${net}'].gw')"
      network_ref_vip="$(echo ${net_client_list} | jq -r -c '.['${net}'].display_name')"
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/${network_ref_vip}-${client_basename}${index}/" \
          -e "s/\${ip_app}/${ip_client}/" \
          -e "s/\${prefix}/${prefix_client}/" \
          -e "s/\${packages}/${app_apt_packages}/" \
          -e "s/\${default_gw}/${gw_client}/" \
          -e "s/\${forwarders_netplan}/${ip_gw}/" /home/ubuntu/templates/userdata_client.yaml.template | tee /home/ubuntu/app/userdata_client${index}.yaml
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_client${index}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${network_ref_vip}@" \
          -e "s/\${vm_name}/${network_ref_vip}-${client_basename}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-client-${index}.json"
      #
  #    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
      govc library.deploy -options "/home/ubuntu/app/options-client-${index}.json" -folder "${folder_client}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
      govc vm.change -vm "${folder_client}/${network_ref_vip}-${client_basename}${index}" -c ${client_cpu} -m ${client_memory}
      govc vm.power -on=true "${folder_client}/${network_ref_vip}-${client_basename}${index}"
    done
  done
fi
#
# App VMs creation first group // vsphere-avi use case)
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_app_first_list} | jq -c -r '. | length')-1)))
    do
      ip_app="$(echo ${net_app_first_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
      prefix_app="$(echo ${net_app_first_list} | jq -r -c '.['${net}'].cidr' | cut -d"/" -f2)"
      gw_app="$(echo ${net_app_first_list} | jq -r -c '.['${net}'].gw')"
      network_ref_app="$(echo ${net_app_first_list} | jq -r -c '.['${net}'].display_name')"
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/${network_ref_app}-${app_basename}${index}/" \
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
          -e "s/\${forwarders_netplan}/${ip_gw}/" /home/ubuntu/templates/userdata_app.yaml.template | tee /home/ubuntu/app/userdata_app${index}.yaml
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app${index}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${network_ref_app}@" \
          -e "s/\${vm_name}/${network_ref_app}-${app_basename}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-${index}.json"
      #
  #    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
      govc library.deploy -options "/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
      govc vm.change -vm "${folder_app}/${network_ref_app}-${app_basename}${index}" -c ${app_cpu} -m ${app_memory}
      govc vm.power -on=true "${folder_app}/${network_ref_app}-${app_basename}${index}"
    done
  done
fi
#
# App VMs creation second group // vsphere-avi use case)
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    ip_app="$(echo ${net_app_second_list} | jq -r -c '.[0].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
    prefix_app="$(echo ${net_app_second_list} | jq -r -c '.[0].cidr' | cut -d"/" -f2)"
    gw_app="$(echo ${net_app_second_list} | jq -r -c '.[0].gw')"
    network_ref_app="$(echo ${net_app_second_list} | jq -r -c '.[0].display_name')"
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${network_ref_app}-${app_basename_second}${index}/" \
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
        -e "s/\${vm_name}/${network_ref_app}-${app_basename_second}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-second-${index}.json"
    #
#    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc library.deploy -options "/home/ubuntu/app/options-app-second-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
    govc vm.change -vm "${folder_app}/${network_ref_app}-${app_basename_second}${index}" -c ${app_cpu} -m ${app_memory}
    govc vm.power -on=true "${folder_app}/${network_ref_app}-${app_basename_second}${index}"
  done
fi
#
# VM k8s_clusters creation
#
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version="$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')"
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    for index_ip in $(seq 1 2)
    do
      if [[ ${kind} == "vsphere-nsx-avi" ]]; then
        cidr=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").cidr')
        if [[ ${cidr} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
          cidr_vip_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        fi
        prefix_client=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").cidr' | cut -d"/" -f2)
        gw_client=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").gateway_address' | cut -d"/" -f1)
        network_ref_vip=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").display_name')
      fi
      ip_k8s_node="${cidr_vip_three_octets}.${kube_starting_ip}"
      if [[ ${index_ip} -eq 1 ]]; then
        node_type="master"
      else
        node_type="worker"
      fi
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}/" \
          -e "s/\${ip}/${ip_k8s_node}/" \
          -e "s/\${prefix}/${prefix_client}/" \
          -e "s/\${packages}/${k8s_apt_packages}/" \
          -e "s/\${default_gw}/${gw_client}/" \
          -e "s/\${forwarders_netplan}/${ip_gw}/" \
          -e "s/\${docker_version}/${docker_version}/" \
          -e "s/\${node_type}/${node_type}/" \
          -e "s@\${pod_cidr}@${pod_cidr}@" \
          -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
          -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
          -e "s/\${cni}/${cni}/" \
          -e "s/\${cni_version}/${cni_version}/" \
          -e "s/\${K8s_version}/${K8s_version}/" /home/ubuntu/templates/userdata_k8s_node.yaml.template | tee /home/ubuntu/app/userdata_${k8s_basename}${index}_node${index_ip}.yaml
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_${k8s_basename}${index}_node${index_ip}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${network_ref_vip}@" \
          -e "s/\${vm_name}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}.json"
      #
  #    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
      govc library.deploy -options "/home/ubuntu/app/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}.json" -folder "${k8s_basename}${index}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
      govc vm.change -vm "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" -c ${k8s_node_cpu} -m ${k8s_node_memory}
      govc vm.disk.change -vm "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" -size ${k8s_node_disk}
      govc vm.power -on=true "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}"
      ((kube_starting_ip++))
    done
  done
fi
#
# VM client connectivity
#
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_client_list} | jq -c -r '. | length')-1)))
    do
      ip_client="$(echo ${net_client_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_clients} | jq -c -r .[$(expr ${index} - 1)])"
      # ssh check
      retry=60 ; pause=10 ; attempt=1
      while true ; do
        echo "attempt $attempt to verify VM app ${ip_client} is ready"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_client}" -q "exit" >/dev/null 2>&1
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
          break
        fi
        sleep $pause
      done
      echo "Ending timestamp: $(date)"
    done
  done
fi
#
# VM app connectivity first group
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_app_first_list} | jq -c -r '. | length')-1)))
    do
      ip_app="$(echo ${net_app_first_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
      # ssh check
      retry=60 ; pause=10 ; attempt=1
      while true ; do
        echo "attempt $attempt to verify VM app ${ip_app} is ready"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q "exit" >/dev/null 2>&1
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
          break
        fi
        sleep $pause
      done
      echo "Ending timestamp: $(date)"
    done
  done
fi
#
# VM app connectivity second group
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    ip_app="$(echo ${net_app_second_list} | jq -r -c '.[0].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify VM app ${ip_app} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q "exit" >/dev/null 2>&1
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
        break
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi
#
# VM k8s_clusters check and config
#
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    total_node=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].ips | length')
    sed -e "s/\${total_node}/${total_node}/" \
        -e "s@\${SLACK_WEBHOOK_URL}@${SLACK_WEBHOOK_URL}@g" \
        -e "s@\${deployment_name}@${deployment_name}@" \
        -e "s/\${clusterName}/${k8s_basename}${index}/" /home/ubuntu/templates/K8s_check.sh.template | tee "/home/ubuntu/k8s/K8s_check_${k8s_basename}${index}.sh"
    for index_ip in $(seq 1 2)
    do
      ip_k8s_node="${cidr_vip_three_octets}.${kube_starting_ip}"
      retry=60 ; pause=10 ; attempt=1
      while true ; do
        echo "attempt $attempt to verify VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} is ready"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" -q >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app} is reachable."
          ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
          if [[ $? -eq 0 ]]; then
            echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app} cloud init done."
            if [[ ${index_ip} -eq 1 ]]; then
              echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app} is a master - transfer join command file to external gw /home/ubuntu/k8s/join-command-${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command" "/home/ubuntu/k8s/join-command-${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "/home/ubuntu/k8s/K8s_check_${k8s_basename}${index}.sh" ubuntu@${ip_k8s_node}:/home/ubuntu/K8s_check_${k8s_basename}${index}.sh
            else
              echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app} is a worker - transfer join command file to worker and execute it to join the cluster ${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "/home/ubuntu/k8s/join-command-${k8s_basename}${index}" "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command-${k8s_basename}${index}"
              ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo /bin/bash /home/ubuntu/join-command-${k8s_basename}${index}"
            fi
            break
          else
            echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app}: cloud init is not finished." >> ${log_file} 2>&1
          fi
        else
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip} is not reachable."
        fi
        ((attempt++))
        if [ $attempt -eq $retry ]; then
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip} is not reachable after $attempt attempt"
          break
        fi
        sleep $pause
      done
      ((kube_starting_ip++))
    done
  done
fi
#
# VM k8s_clusters final check
#
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    for index_ip in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].ips | length'))
    do
      ip_k8s_node="${cidr_vip_three_octets}.$(echo ${k8s_clusters} | jq -c -r .[$(expr ${index} - 1)].ips[$(expr ${index_ip} - 1)])"
      if [[ ${index_ip} -eq 1 ]]; then
        scp -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}:/home/ubuntu/.kube/config" "/home/ubuntu/k8s/config-${k8s_basename}${index}"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "/bin/bash /home/ubuntu/K8s_check_${k8s_basename}${index}.sh"
      fi
    done
  done
fi
#
# consolidate k8s config files in the external gw
#
if [[ ${k8s_clusters} != "null" ]]; then
  kube_config_json="{\"apiVersion\": \"v1\"}"
  localFile=/home/ubuntu/.kube/config
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    cluster_certificate_authority_data=$(yq -c -r '.clusters[0].cluster."certificate-authority-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    cluster_server=$(yq -c -r '.clusters[0].cluster.server' /home/ubuntu/k8s/config-${k8s_basename}${index})
    name=${k8s_basename}${index}
    kube_config_json=$(echo ${kube_config_json} | jq '.clusters += [{"cluster": {"certificate-authority-data": "'$(echo $cluster_certificate_authority_data)'", "server": "'$(echo $cluster_server)'"}, "name": "'$(echo $name)'"}]')
    # contexts
    context_cluster=${k8s_basename}${index}
    context_user=user${index}
    name=context${index}
    kube_config_json=$(echo ${kube_config_json} | jq '.contexts += [{"context": {"cluster": "'$(echo $context_cluster)'", "user": "'$(echo $context_user)'"}, "name": "'$(echo $name)'"}]')
    # users
    name=user${index}
    user_client_certificate_data=$(yq -c -r '.users[0].user."client-certificate-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    user_client_key_data=$(yq -c -r '.users[0].user."client-key-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    kube_config_json=$(echo ${kube_config_json} | jq '.users += [{"user": {"client-certificate-data": "'$(echo $user_client_certificate_data)'", "client-key-data": "'$(echo $user_client_key_data)'"}, "name": "'$(echo $name)'"}]')
  done
  rm -f ${localFile}
  echo ${kube_config_json} | yq -y . | tee ${localFile} > /dev/null
  cp ${localFile} /home/ubuntu/k8s/config
  chmod 600 ${localFile}
fi