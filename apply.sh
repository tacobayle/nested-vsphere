#!/bin/bash
#
source /nested-vsphere/bash/ip.sh
source /nested-vsphere/bash/functions.sh
source /nested-vsphere/bash/log_message.sh
source /nested-vsphere/bash/test_remote_script.sh
#
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
if [[ ${operation} != "apply" && ${operation} != "destroy" ]] ; then log_message "${deployment_name}: $(date): ERROR: Unsupported operation" "${log_file}" "" ""; exit 255 ; fi
jsonFile="/root/${deployment_name}_${operation}.json"
jsonFile_remote="/home/ubuntu/json/${deployment_name}_${operation}.json"
jq -s '.[0] * .[1]' ${jsonFile_kube} ${jsonFile_local} > ${jsonFile}
# source the variables
source /nested-vsphere/bash/variables.sh
# remove previous log files
rm -f ${log_file}
touch ${log_file}
# load govc vars
source /nested-vsphere/bash/govc/load_govc_external.sh
govc about
if [ $? -ne 0 ] ; then
  log_message "${deployment_name}: $(date): ERROR: unable to connect to vCenter" "" "${slack_webhook}" "${google_webhook}"
  exit
fi
list_folder=$(govc find -json . -type f)
list_gw=$(govc find -json vm -name "${gw_name}")
#
# Apply
#
if [[ ${operation} == "apply" ]] ; then
  log_message "${deployment_name}: $(date): -----------------------------APPLY-------------------------------" "${log_file}" "" ""
  # ubuntu ova download
  /nested-vsphere/bash/download_file_from_url_to_location.sh "${ubuntu_ova_url}" "/root/$(basename ${ubuntu_ova_url})" "${deployment_name}, Ubuntu OVA" > /dev/null 2>&1 &
  # esxi iso download
  /nested-vsphere/bash/download_file_from_url_to_location.sh "${iso_esxi_url}" "/root/$(basename ${iso_esxi_url})" "${deployment_name}, ESXi ISO" > /dev/null 2>&1 &
  # folder creation
  log_message "${deployment_name}: $(date): Creation of a folder on the underlay infrastructure - This should take less than a minute" "${log_file}" "" ""
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    log_message "${deployment_name}: $(date): ERROR: unable to create folder ${folder}: it already exists" "${log_file}" "" ""
  else
    govc folder.create /${vsphere_dc}/vm/${folder} >> ${log_file} 2>&1
    log_message "${deployment_name}: $(date): vsphere external folder ${folder} created" "${log_file}" "${slack_webhook}" "${google_webhook}"
  fi
  #
  # gw creation
  #
  log_message "${deployment_name}: $(date): external gateway creation" "${log_file}" "" ""
  # templating files
  sed -e "s@\${ip_gw}@${ip_gw}@" /nested-vsphere/templates/html/socks.html.template | tee /nested-vsphere/html/socks.html > /dev/null
  sed -e "s@\${ip_gw}@${ip_gw}@" /nested-vsphere/templates/html/vault.html.template | tee /nested-vsphere/html/vault.html.tmp > /dev/null
  sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/html/details-${kind}.html.template | tee /nested-vsphere/html/details.html > /dev/null
  sed -e "s@\${domain}@${domain}@" -e "s@\${avi_subdomain}@${avi_subdomain}@" /nested-vsphere/templates/html/rate-limiting-ako-cookie.html.template | tee /nested-vsphere/html/rate-limiting-ako-cookie.html > /dev/null
  if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]]; then
    sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/html/api.js.template | tee /nested-vsphere/html/api.js > /dev/null
    sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/html/clean-up.js.template | tee /nested-vsphere/html/clean-up.js > /dev/null
    sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/html/script.js.template | tee /nested-vsphere/html/script.js > /dev/null
    sed -e "s@\${domain}@${domain}@" /nested-vsphere/templates/html/demos-${kind}.html.template | tee /nested-vsphere/html/demos.html > /dev/null
  fi
  if [[ ${list_gw} != "null" ]] ; then
    rm -f "/tmp/${deployment_name}_gw_creation.done"
    log_message "${deployment_name}: $(date): unable to create VM ${gw_name}: it already exists" "${log_file}" "" ""
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
        -e "s@\${networks}@$(echo ${networks} | jq -c -r '.')@" \
        -e "s@\${segments_overlay}@${segments_overlay}@" \
        -e "s@\${supervisor_cluster_ingress_cidr}@${supervisor_cluster_ingress_cidr}@" \
        -e "s@\${supervisor_cluster_namespace_cidr}@${supervisor_cluster_namespace_cidr}@" \
        -e "s@\${tanzu_namespaces}@${tanzu_namespaces}@" \
        -e "s@\${cidr_nsx_external_three_octets}@${cidr_nsx_external_three_octets}@" \
        -e "s@\${tier0_vip_starting_ip}@${tier0_vip_starting_ip}@" \
        -e "s/\${forwarders_bind}/${forwarders_bind}/" \
        -e "s/\${domain}/${domain}/g" \
        -e "s/\${kind}/${kind}/g" \
        -e "s@\${net_client_list}@$(echo ${net_client_list} | jq -c -r '.')@g" \
        -e "s@\${ip_blocks_json}@$(echo ${ip_blocks_json} | jq -c -r '.')@g" \
        -e "s@\${jsonFile}@$(basename ${jsonFile})@g" \
        -e "s@\${gw_pip_artefact}@${gw_pip_artefact}@g" \
        -e "s/\${reverse_mgmt}/${reverse_mgmt}/g" \
        -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
        -e "s/\${ip_avi_dns}/${ip_avi_dns}/" \
        -e "s/\${openshift_cluster_name}/${openshift_cluster_name}/" \
        -e "s/\${openshift_api_ip}/${openshift_api_ip}/" \
        -e "s/\${openshift_ingress_ip}/${openshift_ingress_ip}/" \
        -e "s/\${avi_subdomain}/${avi_subdomain}/" \
        -e "s/\${avi_gslb_subdomain}/${avi_gslb_subdomain}/" \
        -e "s/\${gw_readonly_user}/${gw_readonly_user}/" \
        -e "s/\${gw_readonly_password}/${gw_readonly_password}/" \
        -e "s/\${ips_esxi}/${ips_esxi}/" \
        -e "s/\${vcsa_name}/${vcsa_name}/" \
        -e "s/\${esxi_basename}/${esxi_basename}/" \
        -e "s/\${ip_nsx}/${ip_nsx}/" \
        -e "s/\${ip_act}/${ip_act}/" \
        -e "s/\${act_name}/${act_name}/" \
        -e "s/\${act_last_octet}/${act_last_octet}/" \
        -e "s/\${ip_vra}/${ip_vra}/" \
        -e "s/\${vra_name}/${vra_name}/" \
        -e "s/\${vra_last_octet}/${vra_last_octet}/" \
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
        -e "s@\${vault_pki_role_name}@${vault_pki_role_name}@g" \
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
        -e "s/\${K8s_version_short}/$(jq -c -r '.K8s_version_short' $jsonFile)/" \
        -e "s/\${packages}/$(jq -c -r '.apt_packages' $jsonFile)/" \
        -e "s/\${pip3_packages}/$(jq -c -r '.pip3_packages' $jsonFile)/" \
        -e "s/\${ip_vcsa}/${ip_vcsa}/" /nested-vsphere/templates/userdata_external-gw.yaml.template | tee /tmp/${gw_name}_userdata.yaml > /dev/null
        # the following needs to be uncommented if kickstart file needs to be consumed by http
        # -e "s@\${deployment_name}@${deployment_name}@" \
        # -e "s@\${esxi_basename}@${esxi_basename}@" \
        # -e "s/\${cidr_vmotion_three_octets}/${cidr_vmotion_three_octets}/g" \
        # -e "s/\${cidr_vsan_three_octets}/${cidr_vsan_three_octets}/g" \
        # -e "s/\${netmask_mgmt}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
        # -e "s/\${netmask_vmotion}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
        # -e "s/\${netmask_vsan}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
        # -e "s/\${gateway}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)/" \
        # -e "s/\${vlan_id_mgmt}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
        # -e "s/\${vlan_id_vmotion}/$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
        # -e "s/\${vlan_id_vsan}/$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
        # -e "s/\${iso_esxi_url}/$(basename ${iso_esxi_url})/" \
    #
    sed -e "s#\${public_key}#$(awk '{printf "%s\\n", $0}' /root/.ssh/id_rsa.pub | awk '{length=$0; print substr($0, 1, length-2)}')#" \
        -e "s@\${base64_userdata}@$(base64 /tmp/${gw_name}_userdata.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_gw}@" \
        -e "s/\${vm_name}/${gw_name}/" /nested-vsphere/templates/options-ubuntu.json.template > "/tmp/options-${gw_name}.json"
    #
    wait
    govc import.ova --options="/tmp/options-${gw_name}.json" -folder "${folder}" "/root/$(basename ${ubuntu_ova_url})" >> ${log_file} 2>&1
    govc vm.change -vm "${folder}/${gw_name}" -c $(jq -c -r .gw.cpu $jsonFile) -m $(jq -c -r .gw.memory $jsonFile)
    govc vm.network.add -vm "${folder}/${gw_name}" -net "${trunk1}" -net.adapter vmxnet3 >> ${log_file} 2>&1
    govc vm.disk.change -vm "${folder}/${gw_name}" -size $(jq -c -r .gw.disk $jsonFile)
    govc vm.power -on=true "${gw_name}" >> ${log_file} 2>&1
    touch "/tmp/${deployment_name}_gw_creation.done"
    log_message "${deployment_name}: $(date):    +++ Updating /etc/hosts..." "${log_file}" "" ""
    contents=$(cat /etc/hosts | grep -v ${ip_gw})
    echo "${contents}" | tee /etc/hosts > /dev/null
    contents="${ip_gw} gw"
    echo "${contents}" | tee -a /etc/hosts > /dev/null
    log_message "${deployment_name}: $(date): external-gw ${gw_name} VM created" "${log_file}" "${slack_webhook}" "${google_webhook}"
  fi
  affinity_members="${gw_name}"
  #
  # esx creation
  #
  log_message "${deployment_name}: $(date): esx creation" "${log_file}" "" ""
  iso_mount_location="/tmp/esxi_cdrom_mount"
  iso_build_location="/tmp/esxi_cdrom"
  boot_cfg_location="efi/boot/boot.cfg"
  iso_location="/tmp/esxi"
  xorriso -ecma119_map lowercase -osirrox on -indev "/root/$(basename ${iso_esxi_url})" -extract / ${iso_mount_location}
  log_message "${deployment_name}: $(date): Copying source ESXi ISO to Build directory" "${log_file}" "" ""
  rm -fr ${iso_build_location}
  mkdir -p ${iso_build_location}
  cp -r ${iso_mount_location}/* ${iso_build_location}
  rm -fr ${iso_mount_location}
  # the following needs to be uncommented if kickstart file needs to be consumed by http
  #  if [[ $(basename ${iso_esxi_url}) != "VMware-VMvisor-Installer-9.0.0.0.24528266.x86_64.iso" ]]; then
  #    echo "Modifying ${iso_build_location}/${boot_cfg_location}" >> ${log_file} 2>&1
  #    echo "kernelopt=runweasel ks=cdrom:/KS_CUST.CFG" | tee -a ${iso_build_location}/${boot_cfg_location}
  #  else
  #    cp ${iso_build_location}/${boot_cfg_location} /root/boot.cfg.ori
  #  fi
  log_message "${deployment_name}: $(date): Modifying ${iso_build_location}/${boot_cfg_location}" "${log_file}" "" ""
  echo "kernelopt=runweasel ks=cdrom:/KS_CUST.CFG" | tee -a ${iso_build_location}/${boot_cfg_location} > /dev/null 2>&1
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-${esxi_basename}${esxi}"
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      log_message "${deployment_name}: $(date): ERROR: unable to create nested ESXi ${name_esxi}: it already exists" "${log_file}" "" ""
      rm -f "/tmp/${deployment_name}_esx_creation.done"
    else
      net=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
      ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
      rm -f ${iso_build_location}/ks_cust.cfg
      rm -f "${iso_location}-${esxi}.iso"
      log_message "${deployment_name}: $(date): Modifying ${iso_build_location}/ks_cust.cfg" "${log_file}" "" ""
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
          -e "s/\${gateway}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)/" /nested-vsphere/templates/vsphere/ks_cust.cfg.template | tee ${iso_build_location}/ks_cust.cfg > /dev/null
      # the following needs to be uncommented if kickstart file needs to be consumed by http
      #      if [[ $(basename ${iso_esxi_url}) == "VMware-VMvisor-Installer-9.0.0.0.24528266.x86_64.iso" ]]; then
      #        cp /root/boot.cfg.ori ${iso_build_location}/${boot_cfg_location}
      #        echo "Modifying ${iso_build_location}/${boot_cfg_location}" >> ${log_file} 2>&1
      #        echo "kernelopt=runweasel ks=http://${ip_gw}/kickstart/KS${esxi}.CFG nameserver=${ip_gw} ip=${cidr_mgmt_three_octets}.${ip_esxi} mask=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++") gateway=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile) vlanid=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)" | tee -a ${iso_build_location}/${boot_cfg_location}
      #      fi
      log_message "${deployment_name}: $(date): +++ Building custom ESXi ISO for ESXi${esxi}" "${log_file}" "" ""
      xorrisofs -relaxed-filenames -J -R -o "${iso_location}-${esxi}.iso" -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${iso_build_location}
      log_message "${deployment_name}: $(date): +++ Uploading custom ESXi ISO for ESXi${esxi} to datastore" "${log_file}" "" ""
      govc datastore.upload --ds=$(jq -c -r .spec.vsphere_underlay.datastore $jsonFile) --dc=$(jq -c -r .spec.vsphere_underlay.datacenter $jsonFile) "${iso_location}-${esxi}.iso" ${deployment_name}-tmp/$(basename ${iso_location}-${esxi}.iso) > /dev/null
      log_message "${deployment_name}: $(date): ISO ESXi ${esxi} uploaded" "${log_file}" "${slack_webhook}" "${google_webhook}"
      affinity_members="${affinity_members} ${name_esxi}"
      govc vm.create -c $(jq -c -r .spec.esxi.cpu $jsonFile) -m $(jq -c -r .spec.esxi.memory $jsonFile) -disk $(jq -c -r .spec.esxi.disk_os_size $jsonFile) -disk.controller pvscsi -net ${net} -g vmkernel65Guest -net.adapter vmxnet3 -firmware efi -folder "${folder}" -on=false "${name_esxi}" > /dev/null
      token=$(/bin/bash /nested-vsphere/vcenter/create_vcenter_api_session.sh "${GOVC_USERNAME}" "" "${GOVC_PASSWORD}" "$(basename ${GOVC_URL})")
      vcenter_api 2 2 "GET" $token "${json_data}" "$(basename ${GOVC_URL})" "api/vcenter/vm"
      esxi_nested_vm_id=$(echo ${response_body} | jq -c -r --arg arg "${name_esxi}" '.[] | select(.name == $arg).vm')
      # adding a SATA controller
      json_data='{"type": "AHCI"}'
      vcenter_api 2 2 "POST" $token "${json_data}" "$(basename ${GOVC_URL})" "api/vcenter/vm/${esxi_nested_vm_id}/hardware/adapter/sata"
      # adding a cdrom based on sata
      json_data='{"type": "SATA", "start_connected": true, "backing": {"iso_file": "['${GOVC_DATASTORE}'] '${deployment_name}'-tmp/'$(basename ${iso_location}-${esxi}.iso)'","type": "ISO_FILE"}}'
      vcenter_api 2 2 "POST" $token "${json_data}" "$(basename ${GOVC_URL})" "api/vcenter/vm/${esxi_nested_vm_id}/hardware/cdrom"
      # adding a cdrom based on IDE
      # govc device.cdrom.add -vm "${folder}/${name_esxi}" > /dev/null
      # govc device.cdrom.insert -vm "${folder}/${name_esxi}" -device cdrom-3000 ${deployment_name}-tmp/$(basename ${iso_location}-${esxi}.iso) > /dev/null
      govc vm.change -vm "${folder}/${name_esxi}" -nested-hv-enabled > /dev/null
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk1 -size $(jq -c -r .spec.esxi.disk_flash_size $jsonFile) > /dev/null
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk2 -size $(jq -c -r .spec.esxi.disk_capacity_size $jsonFile) > /dev/null
      net=$(jq -c -r .spec.esxi.nics[1] $jsonFile)
      govc vm.network.add -vm "${folder}/${name_esxi}" -net ${net} -net.adapter vmxnet3 > /dev/null
      govc vm.power -on=true "${folder}/${name_esxi}" > /dev/null
      touch "/tmp/${deployment_name}_esx_creation.done"
      log_message "${deployment_name}: $(date): nested ESXi ${esxi} created" "${log_file}" "${slack_webhook}" "${google_webhook}"
    fi
  done
  #
  # gw ssh check
  #
  log_message "${deployment_name}: $(date): Starting timestamp gw check" "${log_file}" "" ""
  retry=60 ; pause=10 ; attempt=1
  if [[ -f "/tmp/${deployment_name}_gw_creation.done" ]]; then
    while true ; do
      log_message "${deployment_name}: $(date): attempt $attempt to verify gw ${gw_name} is ready" "${log_file}" "" ""
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_gw}" -q "exit" >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        log_message "${deployment_name}: $(date): Gw ${gw_name} is reachable" "${log_file}" "" ""
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_gw}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
        if [[ $? -eq 0 ]]; then
          # scp folders_to_copy
          echo $folders_to_copy | jq -c -r .[] | while read folder
          do
            scp -o StrictHostKeyChecking=no -r /nested-vsphere/${folder} ubuntu@${ip_gw}:/home/ubuntu
          done
          # scp jsonFile
          scp -o StrictHostKeyChecking=no ${jsonFile} ubuntu@${ip_gw}:/home/ubuntu/json/${deployment_name}_${operation}.json
          # details config.
          ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo mv /home/ubuntu/html/* /var/www/html/" >> ${log_file}
          ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo chown root /var/www/html/*" >> ${log_file}
          ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo chgrp root /var/www/html/*" >> ${log_file}
          # lbaas config.
          if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]]; then
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo mv /home/ubuntu/lbaas/avi-lbaas.service /etc/systemd/system/avi-lbaas.service" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo chown root /etc/systemd/system/avi-lbaas.service" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo chgrp root /etc/systemd/system/avi-lbaas.service" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo chmod 644 /etc/systemd/system/avi-lbaas.service" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo systemctl start avi-lbaas" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sudo systemctl enable avi-lbaas" >> ${log_file}
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "sed -e \"s@dummy_value@\$(jq -c -r '.root_token' ${vault_secret_file_path})@\" /var/www/html/vault.html.tmp | sudo tee /var/www/html/vault.html" >> ${log_file}
          fi
          # yaml domain update
          if [[ ${kind} == *"-avi" ]]; then
            sed -e "s@\${yaml_folder}@${yaml_folder}@" \
                -e "s@\${yaml_links}@${yaml_links}@" /nested-vsphere/templates/k8s/yaml_download_update.sh.template | tee /root/yaml_download_update.sh > /dev/null
            scp -o StrictHostKeyChecking=no /root/yaml_download_update.sh ubuntu@${ip_gw}:/home/ubuntu/bash/yaml_download_update.sh
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "chmod u+x /home/ubuntu/bash/yaml_download_update.sh"
            ssh -o StrictHostKeyChecking=no -t ubuntu@${ip_gw} "/home/ubuntu/bash/yaml_download_update.sh /home/ubuntu/json/${deployment_name}_${operation}.json" >> ${log_file}
            # update ingress boutique
            sed -e "s@\${avi_subdomain}@${avi_subdomain}@" -e "s@\${domain}@${domain}@" /nested-vsphere/templates/yaml-files/ako_boutique_ingress.yaml.template | tee /root/ako_boutique_ingress.yaml
            sed -e "s@\${avi_subdomain}@${avi_subdomain}@" -e "s@\${domain}@${domain}@" /nested-vsphere/templates/yaml-files/ako_boutique_hostrule.yaml.template | tee /root/ako_boutique_hostrule.yaml
            scp -o StrictHostKeyChecking=no /root/ako_boutique_hostrule.yaml ubuntu@${ip_gw}:/home/ubuntu/yaml-files/ako_boutique_hostrule.yaml
            scp -o StrictHostKeyChecking=no /root/ako_boutique_ingress.yaml ubuntu@${ip_gw}:/home/ubuntu/yaml-files/ako_boutique_ingress.yaml
          fi
          log_message "${deployment_name}: $(date): external-gw ${gw_name} VM reachable and configured" "${log_file}" "${slack_webhook}" "${google_webhook}"
          break
        else
          log_message "${deployment_name}: $(date): Gw ${gw_name}: cloud init is not finished." "${log_file}" "" ""
        fi
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        log_message "${deployment_name}: $(date): external-gw ${gw_name} VM is unreachable after $attempt attempt" "${log_file}" "${slack_webhook}" "${google_webhook}"
        exit
      fi
      sleep $pause
    done
  fi
  # Start downloading VCSA ISO remotely
  ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${iso_vcenter_url}\" \"/home/ubuntu/bin/$(basename ${iso_vcenter_url})\" \"${deployment_name}, VCSA ISO\"" > /dev/null 2>&1 &
  #
  # affinity rule
  #
  if [[ $(jq -c -r .spec.vsphere_underlay.affinity $jsonFile) == "true" && ! -f "/tmp/${deployment_name}_affinity.done" ]] ; then
    log_message "${deployment_name}: $(date): Creation of a affinity rule on the underlay infrastructure - This should take less than a minute" "${log_file}" "" ""
    govc cluster.rule.create -name "${deployment_name}-affinity-rule" -enable -affinity ${affinity_members}
    touch /tmp/${deployment_name}_affinity.done
    log_message "${deployment_name}: $(date): Ending timestamp: $(date)" "${log_file}" "" ""
  fi
  #
  # ESX customization
  #
  if [[ -f "/tmp/${deployment_name}_esx_creation.done" ]]; then
    script_file="/home/ubuntu/vcenter/esxi_customization.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  wait
  #
  # Start downloading OVA(s) remotely
  #
  if [[ ${kind} == "vsphere-nsx"* ]]; then
    # Start downloading NSX OVA remotely
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${nsx_ova_url}\" \"/home/ubuntu/bin/$(basename ${nsx_ova_url})\" \"${deployment_name}, NSX OVA\"" > /dev/null 2>&1 &
  fi
  #
  if [[ ${kind} == *"-avi" ]]; then
    # Start downloading Avi OVA remotely
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${avi_ova_url}\" \"/home/ubuntu/bin/$(basename ${avi_ova_url})\" \"${deployment_name}, Avi OVA\"" > /dev/null 2>&1 &
    # Start downloading Ubuntu OVA remotely
    ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${ubuntu_ova_url}\" \"/home/ubuntu/bin/$(basename ${ubuntu_ova_url})\" \"${deployment_name}, Ubuntu OVA\"" > /dev/null 2>&1 &
    # Start downloading OpenShift Installer remotely
    if [[ ${kind} == "vsphere-avi" && ${openshift} != "null" ]]; then
      ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${openshift_installer_url}\" \"/home/ubuntu/bin/$(basename ${openshift_installer_url})\" \"${deployment_name}, OpenShift Installer\"" > /dev/null 2>&1 &
    fi
    if [[ ${kind} == "vsphere-nsx"* ]] ; then
      # Start downloading ACT remotely
      ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${act_ova_url}\" \"/home/ubuntu/bin/$(basename ${act_ova_url})\" \"${deployment_name}, ACT OVA\"" > /dev/null 2>&1 &
    fi
  fi
  #
  # vCenter Deployment and Config.
  #
  if [[ ! -f "/tmp/${deployment_name}_vcenter_creation.done" ]]; then
    script_file="/home/ubuntu/vcenter/vcsa.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
    touch "/tmp/${deployment_name}_vcenter_creation.done"
    # Transfer of vcsa_about_json_file from the gw to the pod
    scp -o StrictHostKeyChecking=no ubuntu@${ip_gw}:${vcsa_about_json_file} /root/${deployment_name}_$(basename ${vcsa_about_json_file})
    # Start downloading VRA remotely if vsphere 8
    if [[ ${vra_ova_url} != "null" && $(jq -c -r '.about.version' /root/${deployment_name}_$(basename ${vcsa_about_json_file}) | cut -d"." -f1) == "8" ]] ; then
      # Start downloading VRA OVA remotely
      ssh -o StrictHostKeyChecking=no ubuntu@${ip_gw} "/home/ubuntu/bash/download_file_from_url_to_location.sh \"${vra_ova_url}\" \"/home/ubuntu/bin/$(basename ${vra_ova_url})\" \"${deployment_name}, VRA OVA\"" > /dev/null 2>&1 &
    fi
  fi
  #
  wait
  # NSX use case
  if [[ ${kind} == "vsphere-nsx"* ]]; then
    # NSX deployment
    script_file="/home/ubuntu/nsx/deploy_nsx.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
    # NSX configuration
    script_file="/home/ubuntu/nsx/configure_nsx.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
    # NSX VPC config.
    script_file="/home/ubuntu/nsx/configure_nsx_vpc.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # Avi ctrl creation
  if [[ ${kind} == *"-avi" ]]; then
    script_file="/home/ubuntu/avi/deploy_avi.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # App creation
  if [[ ${kind} == *"-avi" ]]; then
    script_file="/home/ubuntu/app/deploy_app.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # K8s clusters config creation
  if [[ ${kind} == *"-avi" ]]; then
    script_file="/home/ubuntu/k8s/deploy_k8s.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # ACT creation
  if [[ ${act_ova_url} != "null" ]]; then
    script_file="/home/ubuntu/act/deploy_act.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # vRA creation
  if [[ $(jq -c -r '.about.version' /root/${deployment_name}_$(basename ${vcsa_about_json_file}) | cut -d"." -f1) == "8" && ${vra_ova_url} != "null" ]] ; then
    script_file="/home/ubuntu/vra/deploy_vra.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # Avi ctrl config.
  if [[ ${kind} == *"-avi" ]]; then
    script_file="/home/ubuntu/avi/configure_avi.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # ACT configure
  if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]] ; then
    script_file="/home/ubuntu/act/configure_act.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # vRA bootstrap and config
  if [[ $(jq -c -r '.about.version' /root/${deployment_name}_$(basename ${vcsa_about_json_file}) | cut -d"." -f1) == "8" && ${vra_ova_url} != "null" ]] ; then
    script_file="/home/ubuntu/vra/bootstrap_vra.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      # In the future configure_vra will need to wait until bootstrap_vra.sh is done
      script_file="/home/ubuntu/vra/configure_vra.sh"
      log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
      test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
    fi
  fi
  #
  wait
  # VKS config.
  if [[ ${kind} == *"-avi" && ${configure_supervisor} == "true" ]]; then
    script_file="/home/ubuntu/tanzu/configure_tanzu.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
  # Openshift creation
  if [[ ${kind} == "vsphere-avi" && ${openshift} != "null" ]]; then
    script_file="/home/ubuntu/openshift/deploy_openshift.sh"
    log_message "${deployment_name}: $(date): running the following command from the gw: ${script_file} ${jsonFile_remote} ${script_file%.*}.done" ${log_file} ${slack_webhook} ${google_webhook}
    test_remote_script "${ip_gw}" "${script_file}" "${jsonFile_remote}" >> ${log_file} 2>&1
  fi
fi
#
# Destroy
#
if [[ ${operation} == "destroy" ]] ; then
  log_message "${deployment_name}: $(date): -----------------------------DESTROY-------------------------------" "${log_file}" "" ""
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-${esxi_basename}${esxi}"
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      govc vm.power -off=true "${folder}/${name_esxi}"
      govc vm.destroy "${folder}/${name_esxi}"
      log_message "${deployment_name}: $(date): nested ESXi '${name_esxi}' destroyed" "${log_file}" "${slack_webhook}" "${google_webhook}"
    else
      log_message "${deployment_name}: $(date): ERROR: unable to delete ESXi ${name_esxi}: it is already gone" "${log_file}" "" ""
    fi
  done
  #
  if [[ ${list_gw} != "null" ]] ; then
    govc vm.power -off=true "${gw_name}" >> ${log_file} 2>&1
    govc vm.destroy "${gw_name}" >> ${log_file} 2>&1
    log_message "${deployment_name}: $(date): Gw destroyed" "${log_file}" "${slack_webhook}" "${google_webhook}"
  else
    log_message "${deployment_name}: $(date): ERROR: unable to delete VM ${gw_name}: it does not exists" "${log_file}" "" ""
  fi
  #
  if [[ $(jq -c -r .spec.vsphere_underlay.affinity $jsonFile) == "true" ]] ; then
    govc cluster.rule.remove -name "${deployment_name}-affinity-rule"
    rm -f /tmp/${deployment_name}_affinity.done
    log_message "${deployment_name}: $(date): Affinity rule on the underlay infrastructure destroyed" "${log_file}" "${slack_webhook}" "${google_webhook}"
  fi
  #
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    govc object.destroy /${vsphere_dc}/vm/${folder} >> ${log_file} 2>&1
    log_message "${deployment_name}: $(date): vsphere external folder ${folder} removed" "${log_file}" "${slack_webhook}" "${google_webhook}"
  else
    log_message "${deployment_name}: $(date): ERROR: unable to delete folder ${folder}: it does not exist" "${log_file}" "" ""
  fi
fi