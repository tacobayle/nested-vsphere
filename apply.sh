#!/bin/bash
#
source /nested-vsphere/bash/download_file.sh
source /nested-vsphere/bash/ip.sh
#
rm -f /root/govc.error
jsonFile_kube="${1}"
if [ -s "${jsonFile_kube}" ]; then
  jq . ${jsonFile_kube} > /dev/null
else
  echo "ERROR: ${jsonFile_kube} file is not present"
  exit 255
fi
jsonFile_local="/nested-vsphere/json/variables.json"
operation=$(jq -c -r .operation $jsonFile_kube)
deployment_name=$(jq -c -r .metadata.name $jsonFile_kube)
if [[ ${operation} == "apply" || ${operation} == "destroy" ]] ; then log_file="/nested-vsphere/log/${deployment_name}_${operation}.stdout" ; fi
if [[ ${operation} != "apply" && ${operation} != "destroy" ]] ; then echo "ERROR: Unsupported operation" ; exit 255 ; fi
jsonFile="/root/${deployment_name}_${operation}.json"
jq -s '.[0] * .[1]' ${jsonFile_kube} ${jsonFile_local} | tee ${jsonFile}
#
# add env variables in json
#
variables_json=$(jq -c -r . $jsonFile)
variables_json=$(echo ${variables_json} | jq '. += {"SLACK_WEBHOOK_URL": "'${SLACK_WEBHOOK_URL}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"SLACK_WEBHOOK_URL_AVI": "'${SLACK_WEBHOOK_URL_AVI}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"GENERIC_PASSWORD": "'${GENERIC_PASSWORD}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"NSX_LICENSE": "'${NSX_LICENSE}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"AVI_OLD_PASSWORD": "'${AVI_OLD_PASSWORD}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"DOCKER_REGISTRY_USERNAME": "'${DOCKER_REGISTRY_USERNAME}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"DOCKER_REGISTRY_PASSWORD": "'${DOCKER_REGISTRY_PASSWORD}'"}')
variables_json=$(echo ${variables_json} | jq '. += {"DOCKER_REGISTRY_EMAIL": "'${DOCKER_REGISTRY_EMAIL}'"}')
echo ${variables_json} | jq . | tee $jsonFile > /dev/null
#
# source the variables
#
source /nested-vsphere/bash/variables.sh
#
rm -f ${log_file}
#
#
echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
source /nested-vsphere/bash/govc/load_govc_external.sh
govc about
if [ $? -ne 0 ] ; then touch /root/govc.error ; exit ; fi
list_folder=$(govc find -json . -type f)
list_gw=$(govc find -json vm -name "${gw_name}")
#
if [[ ${operation} == "apply" ]] ; then
  echo '------------------------------------------------------------' | tee ${log_file}
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Creation of a folder on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    echo "ERROR: unable to create folder ${folder}: it already exists" >> ${log_file} 2>&1
  else
    govc folder.create /${vsphere_dc}/vm/${folder} >> ${log_file} 2>&1
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vsphere external folder '${folder}' created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Creation of an external gw on the underlay infrastructure - This should take 10 minutes" >> ${log_file} 2>&1
  # ova download
  download_file_from_url_to_location "${ubuntu_ova_url}" "/root/$(basename ${ubuntu_ova_url})" "Ubuntu OVA"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Ubuntu OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  #
  sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/api.js.template | tee /nested-vsphere/html/api.js > /dev/null
  sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/clean-up.js.template | tee /nested-vsphere/html/clean-up.js > /dev/null
  sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/script.js.template | tee /nested-vsphere/html/script.js > /dev/null
  if [[ ${list_gw} != "null" ]] ; then
    echo "ERROR: unable to create VM ${gw_name}: it already exists" >> ${log_file} 2>&1
    exit
  else
    IFS="." read -r -a octets <<< "$cidr_mgmt"
    count=0
    for octet in "${octets[@]}"; do if [ $count -eq 3 ]; then break ; fi ; addr_mgmt=$octet"."$addr_mgmt ;((count++)) ; done
    reverse_mgmt=${addr_mgmt%.}
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${gw_name}/" \
        -e "s/\${ip_gw}/${ip_gw}/" \
        -e "s/\${prefix}/${prefix_gw}/" \
        -e "s/\${default_gw}/${default_gw}/" \
        -e "s/\${ntp_masters}/${ntp_masters}/" \
        -e "s/\${forwarders_netplan}/${forwarders_netplan}/" \
        -e "s@\${networks}@${networks}@" \
        -e "s@\${segments_overlay}@${segments_overlay}@" \
        -e "s@\${cidr_nsx_external_three_octets}@${cidr_nsx_external_three_octets}@" \
        -e "s@\${tier0_vip_starting_ip}@${tier0_vip_starting_ip}@" \
        -e "s/\${forwarders_bind}/${forwarders_bind}/" \
        -e "s/\${domain}/${domain}/g" \
        -e "s/\${kind}/${kind}/g" \
        -e "s@\${jsonFile}@$(basename ${jsonFile})@g" \
        -e "s/\${reverse_mgmt}/${reverse_mgmt}/g" \
        -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
        -e "s/\${ip_avi_dns}/${ip_avi_dns}/" \
        -e "s/\${avi_subdomain}/${avi_subdomain}/" \
        -e "s/\${ips_esxi}/${ips_esxi}/" \
        -e "s/\${vcsa_name}/${vcsa_name}/" \
        -e "s/\${esxi_basename}/${esxi_basename}/" \
        -e "s/\${ip_nsx}/${ip_nsx}/" \
        -e "s/\${ip_avi}/${ip_avi}/" \
        -e "s/\${ip_avi_last_octet}/${ip_avi_last_octet}/" \
        -e "s/\${ip_nsx_last_octet}/${ip_nsx_last_octet}/" \
        -e "s/\${nsx_manager_name}/${nsx_manager_name}/" \
        -e "s/\${avi_ctrl_name}/${avi_ctrl_name}/" \
        -e "s@\${vault_secret_file_path}@${vault_secret_file_path}@" \
        -e "s@\${vault_pki_name}@${vault_pki_name}@" \
        -e "s@\${vault_pki_max_lease_ttl}@${vault_pki_max_lease_ttl}@" \
        -e "s@\${vault_pki_cert_common_name}@${vault_pki_cert_common_name}@" \
        -e "s@\${vault_pki_cert_issuer_name}@${vault_pki_cert_issuer_name}@" \
        -e "s@\${vault_pki_cert_ttl}@${vault_pki_cert_ttl}@" \
        -e "s@\${vault_pki_cert_path}@${vault_pki_cert_path}@" \
        -e "s@\${vault_pki_role_name}@${vault_pki_role_name}@" \
        -e "s@\${vault_pki_intermediate_name}@${vault_pki_intermediate_name}@" \
        -e "s@\${vault_pki_intermediate_max_lease_ttl}@${vault_pki_intermediate_max_lease_ttl}@" \
        -e "s@\${vault_pki_intermediate_cert_common_name}@${vault_pki_intermediate_cert_common_name}@" \
        -e "s@\${vault_pki_intermediate_cert_issuer_name}@${vault_pki_intermediate_cert_issuer_name}@" \
        -e "s@\${vault_pki_intermediate_cert_path}@${vault_pki_intermediate_cert_path}@" \
        -e "s@\${vault_pki_intermediate_cert_path_signed}@${vault_pki_intermediate_cert_path_signed}@" \
        -e "s@\${vault_pki_intermediate_role_name}@${vault_pki_intermediate_role_name}@" \
        -e "s@\${vault_pki_intermediate_role_allow_subdomains}@${vault_pki_intermediate_role_allow_subdomains}@" \
        -e "s@\${vault_pki_intermediate_role_max_ttl}@${vault_pki_intermediate_role_max_ttl}@" \
        -e "s@\${directories}@$(jq -c -r '.directories' $jsonFile)@" \
        -e "s@\${yaml_folder}@$(jq -c -r '.yaml_folder' $jsonFile)@" \
        -e "s@\${yaml_links}@$(jq -c -r '.yaml_links' $jsonFile)@" \
        -e "s/\${K8s_version_short}/$(jq -c -r '.K8s_version_short' $jsonFile)/" \
        -e "s/\${packages}/$(jq -c -r '.apt_packages' $jsonFile)/" \
        -e "s/\${pip3_packages}/$(jq -c -r '.pip3_packages' $jsonFile)/" \
        -e "s/\${ip_vcsa}/${ip_vcsa}/" /nested-vsphere/templates/userdata_external-gw.yaml.template | tee /tmp/${gw_name}_userdata.yaml > /dev/null
    #
    sed -e "s#\${public_key}#$(awk '{printf "%s\\n", $0}' /root/.ssh/id_rsa.pub | awk '{length=$0; print substr($0, 1, length-2)}')#" \
        -e "s@\${base64_userdata}@$(base64 /tmp/${gw_name}_userdata.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_gw}@" \
        -e "s/\${vm_name}/${gw_name}/" /nested-vsphere/templates/options-ubuntu.json.template > "/tmp/options-${gw_name}.json"
    #
    govc import.ova --options="/tmp/options-${gw_name}.json" -folder "${folder}" "/root/$(basename ${ubuntu_ova_url})" >> ${log_file} 2>&1
    govc vm.change -vm "${folder}/${gw_name}" -c $(jq -c -r .gw.cpu $jsonFile) -m $(jq -c -r .gw.memory $jsonFile)
    govc vm.network.add -vm "${folder}/${gw_name}" -net "${trunk1}" -net.adapter vmxnet3 >> ${log_file} 2>&1
    govc vm.disk.change -vm "${folder}/${gw_name}" -size $(jq -c -r .gw.disk $jsonFile)
    govc vm.power -on=true "${gw_name}" >> ${log_file} 2>&1
    echo "   +++ Updating /etc/hosts..." >> ${log_file} 2>&1
    contents=$(cat /etc/hosts | grep -v ${ip_gw})
    echo "${contents}" | tee /etc/hosts > /dev/null
    contents="${ip_gw} gw"
    echo "${contents}" | tee -a /etc/hosts > /dev/null
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': external-gw '${gw_name}' VM created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    echo "pausing for 120 seconds" >> ${log_file} 2>&1
    sleep 120
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify gw ${gw_name} is ready" >> ${log_file} 2>&1
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_gw}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "Gw ${gw_name} is reachable." >> ${log_file} 2>&1
        #if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': external-gw '${gw_name}' VM reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_gw}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
        if [[ $? -eq 0 ]]; then
          for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
          do
            ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
            name_esxi="${esxi_basename}${esxi}"
            sed -e "s/\${ip_esxi}/${ip_esxi}/" \
                -e "s@\${SLACK_WEBHOOK_URL}@${SLACK_WEBHOOK_URL}@" \
                -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
                -e "s/\${esxi}/${esxi}/" \
                -e "s/\${deployment_name}/${deployment_name}/" \
                -e "s/\${cluster_basename}/${cluster_basename}/" \
                -e "s/\${name_esxi}/${name_esxi}/" \
                -e "s/\${ESXI_PASSWORD}/${GENERIC_PASSWORD}/" /nested-vsphere/templates/esxi_customization.sh.template | tee /root/esxi_customization-$esxi.sh > /dev/null
            chmod u+x /root/esxi_customization-$esxi.sh
            scp -o StrictHostKeyChecking=no /root/esxi_customization-$esxi.sh ubuntu@${ip_gw}:/home/ubuntu/esxi/esxi_customization-$esxi.sh
          done
          echo $folders_to_copy | jq -c -r .[] | while read folder
          do
            scp -o StrictHostKeyChecking=no -r /nested-vsphere/${folder} ubuntu@${ip_gw}:/home/ubuntu
          done
          scp -o StrictHostKeyChecking=no ${jsonFile} ubuntu@${ip_gw}:/home/ubuntu/json/${deployment_name}_${operation}.json
          echo "Gw ${gw_name} is ready." >> ${log_file} 2>&1
          if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': external-gw '${gw_name}' VM reachable and configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
          break
        else
          echo "Gw ${gw_name}: cloud init is not finished." >> ${log_file} 2>&1
        fi
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "Gw ${gw_name} is unreachable after $attempt attempt" >> ${log_file} 2>&1
        exit
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  names="${gw_name}"
  #
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Creation of an ESXi hosts on the underlay infrastructure - This should take 10 minutes" >> ${log_file} 2>&1
  download_file_from_url_to_location "${iso_esxi_url}" "/root/$(basename ${iso_esxi_url})" "ESXi ISO"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': ISO ESXI downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  #
  iso_mount_location="/tmp/esxi_cdrom_mount"
  iso_build_location="/tmp/esxi_cdrom"
  boot_cfg_location="efi/boot/boot.cfg"
  iso_location="/tmp/esxi"
  xorriso -ecma119_map lowercase -osirrox on -indev "/root/$(basename ${iso_esxi_url})" -extract / ${iso_mount_location}
  echo "Copying source ESXi ISO to Build directory" >> ${log_file} 2>&1
  rm -fr ${iso_build_location}
  mkdir -p ${iso_build_location}
  cp -r ${iso_mount_location}/* ${iso_build_location}
  rm -fr ${iso_mount_location}
  echo "Modifying ${iso_build_location}/${boot_cfg_location}" >> ${log_file} 2>&1
  echo "kernelopt=runweasel ks=cdrom:/KS_CUST.CFG" | tee -a ${iso_build_location}/${boot_cfg_location}
  #
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-${esxi_basename}${esxi}"
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      echo "ERROR: unable to create nested ESXi ${name_esxi}: it already exists" >> ${log_file} 2>&1
    else
      net=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
      ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
      echo "+++ Building custom ESXi ISO for ESXi${esxi}" >> ${log_file} 2>&1
      rm -f ${iso_build_location}/ks_cust.cfg
      rm -f "${iso_location}-${esxi}.iso"
      sed -e "s/\${nested_esxi_root_password}/${GENERIC_PASSWORD}/" \
          -e "s/\${ip_esxi}/${ip_esxi}/" \
          -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
          -e "s/\${cidr_vmotion_three_octets}/${cidr_vmotion_three_octets}/g" \
          -e "s/\${cidr_vsan_three_octets}/${cidr_vsan_three_octets}/g" \
          -e "s/\${netmask_mgmt}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${netmask_vmotion}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${netmask_vsan}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${vlan_id_mgmt}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${vlan_id_vmotion}/$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${vlan_id_vsan}/$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${dns_servers}/${ip_gw}/" \
          -e "s/\${ntp_servers}/${ip_gw}/" \
          -e "s/\${hostname}/${name_esxi}/" \
          -e "s/\${domain}/${domain}/" \
          -e "s/\${gateway}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)/" /nested-vsphere/templates/ks_cust.cfg.template | tee ${iso_build_location}/ks_cust.cfg > /dev/null
          echo "Modifying ${iso_build_location}/ks_cust.cfg" >> ${log_file} 2>&1
      echo "Building new ISO for ESXi ${esxi}" >> ${log_file} 2>&1
      xorrisofs -relaxed-filenames -J -R -o "${iso_location}-${esxi}.iso" -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${iso_build_location}
      echo "Uploading new ISO for ESXi ${esxi} to datastore" >> ${log_file} 2>&1
      govc datastore.upload --ds=$(jq -c -r .spec.vsphere_underlay.datastore $jsonFile) --dc=$(jq -c -r .spec.vsphere_underlay.datacenter $jsonFile) "${iso_location}-${esxi}.iso" ${deployment_name}-tmp/$(basename ${iso_location}-${esxi}.iso) > /dev/null
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': ISO ESXi '${esxi}' uploaded "}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
      names="${names} ${name_esxi}"
      govc vm.create -c $(jq -c -r .spec.esxi.cpu $jsonFile) -m $(jq -c -r .spec.esxi.memory $jsonFile) -disk $(jq -c -r .spec.esxi.disk_os_size $jsonFile) -disk.controller pvscsi -net ${net} -g vmkernel65Guest -net.adapter vmxnet3 -firmware efi -folder "${folder}" -on=false "${name_esxi}" > /dev/null
      govc device.cdrom.add -vm "${folder}/${name_esxi}" > /dev/null
      govc device.cdrom.insert -vm "${folder}/${name_esxi}" -device cdrom-3000 ${deployment_name}-tmp/$(basename ${iso_location}-${esxi}.iso) > /dev/null
      govc vm.change -vm "${folder}/${name_esxi}" -nested-hv-enabled > /dev/null
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk1 -size $(jq -c -r .spec.esxi.disk_flash_size $jsonFile) > /dev/null
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk2 -size $(jq -c -r .spec.esxi.disk_capacity_size $jsonFile) > /dev/null
      net=$(jq -c -r .spec.esxi.nics[1] $jsonFile)
      govc vm.network.add -vm "${folder}/${name_esxi}" -net ${net} -net.adapter vmxnet3 > /dev/null
      govc vm.power -on=true "${folder}/${name_esxi}" > /dev/null
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': nested ESXi '${esxi}' created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    fi
  done
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  # affinity rule
  if [[ $(jq -c -r .spec.affinity $jsonFile) == "true" ]] ; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Creation of a affinity rule on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
    govc cluster.rule.create -name "${deployment_name}-affinity-rule" -enable -affinity ${names}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "ESXI reachability check and customization (SSD) - This should take 2 minutes per nested ESXi" >> ${log_file} 2>&1
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${esxi_basename}${esxi}"
    echo "running the following command from the gw: /home/ubuntu/esxi/esxi_customization-$esxi.sh" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "/home/ubuntu/esxi/esxi_customization-$esxi.sh" >> ${log_file}
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': nested ESXi '${name_esxi}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    govc datastore.rm ${deployment_name}-tmp/$(basename ${iso_location}-${esxi}.iso) > /dev/null
  done
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Creation of VCSA  - This should take about 45 minutes" >> ${log_file} 2>&1
  echo "running the following command from the gw: /home/ubuntu/vcenter/vcsa.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
  ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/vcenter/vcsa.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  #
  if [[ ${kind} == "vsphere-nsx" || ${kind} == "vsphere-nsx-avi" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Creation of NSX Manager - This should take about 20 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/nsx/deploy_nsx.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/nsx/deploy_nsx.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  if [[ ${kind} == "vsphere-nsx" || ${kind} == "vsphere-nsx-avi" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Config. of NSX Manager - This should take about 60 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/nsx/configure_nsx.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/nsx/configure_nsx.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  if [[ ${kind} == "vsphere-avi" || ${kind} == "vsphere-nsx-avi" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Creation of Avi ctrl  - This should take about 20 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/avi/deploy_avi.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/avi/deploy_avi.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  if [[ ${kind} == "vsphere-avi" || ${kind} == "vsphere-nsx-avi" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Creation of Avi VMs app, client and k8s clusters  - This should take about 10 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/app/deploy_app.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/app/deploy_app.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  if [[ ${kind} == "vsphere-avi" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Configuration of Avi - This should take about 45 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/avi/configure_avi.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/avi/configure_avi.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  if [[ ${kind} == "vsphere-avi" && ${configure_tanzu_supervisor} == "true" ]]; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Configuration of Tanzu - This should take about 45 minutes" >> ${log_file} 2>&1
    echo "running the following command from the gw: /home/ubuntu/tanzu/configure_tanzu.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file} 2>&1
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/tanzu/configure_tanzu.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
fi
#
#
#
if [[ ${operation} == "destroy" ]] ; then
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-${esxi_basename}${esxi}"
    echo "Deletion of a nested ESXi ${name_esxi} on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      govc vm.power -off=true "${folder}/${name_esxi}"
      govc vm.destroy "${folder}/${name_esxi}"
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': nested ESXi '${name_esxi}' destroyed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    else
      echo "ERROR: unable to delete ESXi ${name_esxi}: it is already gone" >> ${log_file} 2>&1
    fi
  done
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  #
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Deletion of a VM on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
  if [[ ${list_gw} != "null" ]] ; then
    govc vm.power -off=true "${gw_name}" >> ${log_file} 2>&1
    govc vm.destroy "${gw_name}" >> ${log_file} 2>&1
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Gw destroyed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  else
    echo "ERROR: unable to delete VM ${gw_name}: it does not exists" >> ${log_file} 2>&1
  fi
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  #
  #
  if [[ $(jq -c -r .spec.affinity $jsonFile) == "true" ]] ; then
    echo '------------------------------------------------------------' >> ${log_file} 2>&1
    echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
    echo "Deletion of a affinity rule on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
    govc cluster.rule.remove -name "${deployment_name}-affinity-rule"
    echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
  fi
  #
  #
  echo '------------------------------------------------------------' >> ${log_file} 2>&1
  echo "Starting timestamp: $(date)" >> ${log_file} 2>&1
  echo "Deletion of a folder on the underlay infrastructure - This should take less than a minute" >> ${log_file} 2>&1
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    govc object.destroy /${vsphere_dc}/vm/${folder} >> ${log_file} 2>&1
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vsphere external folder '${folder}' removed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  else
    echo "ERROR: unable to delete folder ${folder}: it does not exist" >> ${log_file} 2>&1
  fi
  echo "Ending timestamp: $(date)" >> ${log_file} 2>&1
fi