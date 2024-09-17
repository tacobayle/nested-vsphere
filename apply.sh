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
#
folder=$(jq -c -r .spec.folder $jsonFile)
gw_name="${deployment_name}-gw"
domain=$(jq -c -r .spec.domain $jsonFile)
ip_gw=$(jq -c -r .spec.gw.ip $jsonFile)
network_ref_gw=$(jq -c -r .spec.gw.network_ref $jsonFile)
prefix_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).cidr' $jsonFile | cut -d"/" -f2)
default_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).gw' $jsonFile)
ntp_masters=$(jq -c -r '.spec.gw.ntp_masters' $jsonFile)
forwarders_netplan=$(jq -c -r '.spec.gw.dns_forwarders | join(",")' $jsonFile)
forwarders_bind=$(jq -c -r '.spec.gw.dns_forwarders | join(";")' $jsonFile)
networks=$(jq -c -r '.spec.networks' $jsonFile)
ips_esxi=$(jq -c -r '.spec.esxi.ips' $jsonFile)
ip_vcsa=$(jq -c -r '.spec.vsphere.ip' $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_vmotion=$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_vsan=$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
if [[ ${cidr_vmotion} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vmotion_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
if [[ ${cidr_vsan} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vsan_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
if [[ $(jq -c -r '.spec.nsx.ip' $jsonFile) == "null" ]]; then
  ip_nsx=$(jq -c -r .spec.gw.ip $jsonFile)
else
  ip_nsx=$(jq -c -r '.spec.nsx.ip' $jsonFile)
fi
if [[ $(jq -c -r .spec.avi.ip $jsonFile) == "null" ]]; then
  ip_avi=$(jq -c -r .spec.gw.ip $jsonFile)
else
  ip_avi=$(jq -c -r '.spec.avi.ip' $jsonFile)
fi
trunk1=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
#
rm -f ${log_file}
#
#
echo "Starting timestamp: $(date)" | tee -a ${log_file}
source /nested-vsphere/bash/govc/load_govc_external.sh
govc about
if [ $? -ne 0 ] ; then touch /root/govc.error ; fi
list_folder=$(govc find -json . -type f)
list_gw=$(govc find -json vm -name "${gw_name}")
echo '------------------------------------------------------------' | tee ${log_file}
#
if [[ ${operation} == "apply" ]] ; then
  echo "Creation of a folder on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    echo "ERROR: unable to create folder ${folder}: it already exists" | tee -a ${log_file}
  else
    govc folder.create /${vsphere_dc}/vm/${folder} | tee -a ${log_file}
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vsphere external folder '${folder}' created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  fi
  #
  #
  echo '------------------------------------------------------------' | tee -a ${log_file}
  echo "Creation of an external gw on the underlay infrastructure - This should take 10 minutes" | tee -a ${log_file}
  # ova download
  ova_url=$(jq -c -r .spec.gw.ova_url $jsonFile)
  download_file_from_url_to_location "${ova_url}" "/root/$(basename ${ova_url})" "Ubuntu OVA"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Ubuntu OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  #
  if [[ ${list_gw} != "null" ]] ; then
    echo "ERROR: unable to create VM ${gw_name}: it already exists" | tee -a ${log_file}
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
        -e "s/\${forwarders_bind}/${forwarders_bind}/" \
        -e "s/\${domain}/${domain}/g" \
        -e "s/\${reverse_mgmt}/${reverse_mgmt}/g" \
        -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
        -e "s/\${ips_esxi}/${ips_esxi}/" \
        -e "s/\${ip_nsx}/${ip_nsx}/" \
        -e "s/\${ip_avi}/${ip_avi}/" \
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
        -e "s/\${EXTERNAL_GW_PASSWORD}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_gw}@" \
        -e "s/\${gw_name}/${gw_name}/" /nested-vsphere/templates/options-gw.json.template | tee "/tmp/options-${gw_name}.json"
    #
    govc import.ova --options="/tmp/options-${gw_name}.json" -folder "${folder}" "/root/$(basename ${ova_url})" | tee -a ${log_file}
    govc vm.network.add -vm "${folder}/${gw_name}" -net "${trunk1}" -net.adapter vmxnet3 | tee -a ${log_file}
    govc vm.power -on=true "${gw_name}" | tee -a ${log_file}
    echo "   +++ Updating /etc/hosts..." | tee -a ${log_file}
    contents=$(cat /etc/hosts | grep -v ${ip_gw})
    echo "${contents}" | tee /etc/hosts > /dev/null
    contents="${ip_gw} gw"
    echo "${contents}" | tee -a /etc/hosts > /dev/null
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': external-gw '${gw_name}' VM created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify ssh to gw ${gw_name}" | tee -a ${log_file}
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_gw}" -q >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "Gw ${gw_name} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': external-gw '${gw_name}' VM reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
        do
          ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
          name_esxi="esxi0${esxi}"
          sed -e "s/\${ip_esxi}/${ip_esxi}/" \
              -e "s@\${SLACK_WEBHOOK_URL}@${SLACK_WEBHOOK_URL}@" \
              -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
              -e "s/\${esxi}/${esxi}/" \
              -e "s/\${deployment_name}/${deployment_name}/" \
              -e "s/\${name_esxi}/${name_esxi}/" \
              -e "s/\${ESXI_PASSWORD}/${ESXI_PASSWORD}/" /nested-vsphere/templates/esxi_customization.sh.template | tee /root/esxi_customization-$esxi.sh > /dev/null
          scp -o StrictHostKeyChecking=no /root/esxi_customization-$esxi.sh ubuntu@${ip_gw}:/home/ubuntu/esxi_customization-$esxi.sh
        done
        break
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "Gw ${gw_name} is unreachable after $attempt attempt" | tee -a ${log_file}
        exit
      fi
      sleep $pause
    done
  fi
  names="${gw_name}"
  #
  #
  echo '------------------------------------------------------------' | tee -a ${log_file}
  echo "Creation of an ESXi hosts on the underlay infrastructure - This should take 10 minutes" | tee -a ${log_file}
  iso_url=$(jq -c -r .spec.esxi.iso_url $jsonFile)
  download_file_from_url_to_location "${iso_url}" "/root/$(basename ${iso_url})" "ESXi ISO"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': ISO ESXI downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  #
  iso_mount_location="/tmp/esxi_cdrom_mount"
  iso_build_location="/tmp/esxi_cdrom"
  boot_cfg_location="efi/boot/boot.cfg"
  iso_location="/tmp/esxi"
  xorriso -ecma119_map lowercase -osirrox on -indev "/root/$(basename ${iso_url})" -extract / ${iso_mount_location}
  echo "Copying source ESXi ISO to Build directory" | tee -a ${log_file}
  rm -fr ${iso_build_location}
  mkdir -p ${iso_build_location}
  cp -r ${iso_mount_location}/* ${iso_build_location}
  rm -fr ${iso_mount_location}
  echo "Modifying ${iso_build_location}/${boot_cfg_location}" | tee -a ${log_file}
  echo "kernelopt=runweasel ks=cdrom:/KS_CUST.CFG" | tee -a ${iso_build_location}/${boot_cfg_location}
  #
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-esxi0${esxi}"
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      echo "ERROR: unable to create nested ESXi ${name_esxi}: it already exists" | tee -a ${log_file}
    else
      net=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
      ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
      echo "Building custom ESXi ISO for ESXi${esxi}"
      rm -f ${iso_build_location}/ks_cust.cfg
      rm -f "${iso_location}-${esxi}.iso"
      sed -e "s/\${nested_esxi_root_password}/${GENERIC_PASSWORD}/" \
          -e "s/\${ip_esxi}/${ip_esxi}/" \
          -e "s/\${cidr_mgmt_three_octets}/${cidr_mgmt_three_octets}/g" \
          -e "s/\${cidr_vmotion_three_octets}/${cidr_mgmt_three_octets}/g" \
          -e "s/\${cidr_vsan_three_octets}/${cidr_mgmt_three_octets}/g" \
          -e "s/\${netmask_mgmt}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${netmask_vmotion}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${netmask_vsan}/$(ip_netmask_by_prefix $(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")/" \
          -e "s/\${vlan_id_mgmt}/$(jq -c -r --arg arg "MANAGEMENT" '.specs.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${vlan_id_vmotion}/$(jq -c -r --arg arg "VMOTION" '.specs.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${vlan_id_vsan}/$(jq -c -r --arg arg "VSAN" '.specs.networks[] | select( .type == $arg).vlan_id' $jsonFile)/" \
          -e "s/\${dns_servers}/${ip_gw}/" \
          -e "s/\${ntp_servers}/${ip_gw}/" \
          -e "s/\${hostname}/${name_esxi}/" \
          -e "s/\${domain}/${domain}/" \
          -e "s/\${gateway}/$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)/" /nested-vsphere/templates/ks_cust.cfg.template | tee ${iso_build_location}/ks_cust.cfg > /dev/null
      echo "Building new ISO for ESXi ${esxi}"
      xorrisofs -relaxed-filenames -J -R -o "${iso_location}-${esxi}.iso" -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${iso_build_location}
      govc datastore.upload  --ds=$(jq -c -r .spec.vsphere_underlay.datastore $jsonFile) --dc=$(jq -c -r .spec.vsphere_underlay.datacenter $jsonFile) "${iso_location}-${esxi}.iso" nic-vsphere/$(basename ${iso_location}-${esxi}.iso) | tee -a ${log_file}
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': ISO ESXi '${esxi}' uploaded "}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
      names="${names} ${name_esxi}"
      govc vm.create -c $(jq -c -r .spec.esxi.cpu $jsonFile) -m $(jq -c -r .spec.esxi.memory $jsonFile) -disk $(jq -c -r .spec.esxi.disk_os_size $jsonFile) -disk.controller pvscsi -net ${net} -g vmkernel65Guest -net.adapter vmxnet3 -firmware efi -folder "${folder}" -on=false "${name_esxi}" | tee -a ${log_file}
      govc device.cdrom.add -vm "${folder}/${name_esxi}" | tee -a ${log_file}
      govc device.cdrom.insert -vm "${folder}/${name_esxi}" -device cdrom-3000 nic-vsphere/$(basename ${iso_location}-${esxi}.iso) | tee -a ${log_file}
      govc vm.change -vm "${folder}/${name_esxi}" -nested-hv-enabled | tee -a ${log_file}
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk1 -size $(jq -c -r .spec.esxi.disk_flash_size $jsonFile) | tee -a ${log_file}
      govc vm.disk.create -vm "${folder}/${name_esxi}" -name ${name_esxi}/disk2 -size $(jq -c -r .spec.esxi.disk_capacity_size $jsonFile) | tee -a ${log_file}
      net=$(jq -c -r .spec.esxi.nics[1] $jsonFile)
      govc vm.network.add -vm "${folder}/${name_esxi}" -net ${net} -net.adapter vmxnet3 | tee -a ${log_file}
      govc vm.power -on=true "${folder}/${name_esxi}" | tee -a ${log_file}
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': nested ESXi '${esxi}' created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    fi
  done
  # affinity rule
  if [[ $(jq -c -r .spec.affinity $jsonFile) == "true" ]] ; then
    govc cluster.rule.create -name "${deployment_name}-affinity-rule" -enable -affinity ${names}
  fi
fi
#
#
#
if [[ ${operation} == "destroy" ]] ; then
  echo '------------------------------------------------------------' | tee -a ${log_file}
  for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
  do
    name_esxi="${deployment_name}-esxi0${esxi}"
    echo "Deletion of a nested ESXi ${name_esxi} on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
    if [[ $(govc find -json vm | jq '[.[] | select(. == "vm/'${folder}'/'${name_esxi}'")] | length') -eq 1 ]]; then
      govc vm.power -off=true "${folder}/${name_esxi}"
      govc vm.destroy "${folder}/${name_esxi}"
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': nested ESXi '${name_esxi}' destroyed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    else
      echo "ERROR: unable to delete ESXi ${name_esxi}: it is already gone" | tee -a ${log_file}
    fi
  done
  #
  #
  echo '------------------------------------------------------------' | tee -a ${log_file}
  echo "Deletion of a VM on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
  if [[ ${list_gw} != "null" ]] ; then
    govc vm.power -off=true "${gw_name}" | tee -a ${log_file}
    govc vm.destroy "${gw_name}" | tee -a ${log_file}
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Gw destroyed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  else
    echo "ERROR: unable to delete VM ${gw_name}: it already exists" | tee -a ${log_file}
  fi
  #
  #
  govc cluster.rule.remove -name "${deployment_name}-affinity-rule"
  #
  #
  echo '------------------------------------------------------------' | tee -a ${log_file}
  echo "Deletion of a folder on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    govc object.destroy /${vsphere_dc}/vm/${folder} | tee -a ${log_file}
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vsphere external folder '${folder}' removed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  else
    echo "ERROR: unable to delete folder ${folder}: it does not exist" | tee -a ${log_file}
  fi
fi