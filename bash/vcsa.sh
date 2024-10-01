#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
log_file="/tmp/vcsa.log"
source /home/ubuntu/bash/variables.sh
echo '------------------------------------------------------------'
echo "Creation of VCSA  - This should take about 45 minutes"
iso_url=$(jq -c -r .spec.vsphere.iso_url $jsonFile)
download_file_from_url_to_location "${iso_url}" "/home/ubuntu/$(basename ${iso_url})" "VCSA ISO"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': ISO VCSA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
echo "ISO VCSA downloaded"
xorriso -ecma119_map lowercase -osirrox on -indev "/home/ubuntu/$(basename ${iso_url})" -extract / /tmp/vcenter_cdrom_mount
cp -r /tmp/vcenter_cdrom_mount/vcsa-cli-installer/templates/install/vCSA_with_cluster_on_ESXi.json /home/ubuntu/json/
rm -fr /tmp/vcenter_cdrom
mkdir -p /tmp/vcenter_cdrom
cp -r /tmp/vcenter_cdrom_mount/* /tmp/vcenter_cdrom
sudo rm -fr /tmp/vcenter_cdrom_mount
contents="$(jq '.new_vcsa.esxi.hostname = "'${esxi_basename}'1.'${domain}'" |
                .new_vcsa.esxi.username = "root" |
                .new_vcsa.esxi.password = "'${GENERIC_PASSWORD}'" |
                .new_vcsa.esxi.VCSA_cluster.datacenter = "'${dc}'" |
                .new_vcsa.esxi.VCSA_cluster.cluster = "'${cluster_basename}'1" |
                .new_vcsa.esxi.VCSA_cluster.disks_for_vsan.cache_disk[0] = "'${disk_cache}'" |
                .new_vcsa.esxi.VCSA_cluster.disks_for_vsan.capacity_disk[0] = "'${disk_capacity}'" |
                .new_vcsa.esxi.VCSA_cluster.enable_vsan_esa = false |
                .new_vcsa.esxi.VCSA_cluster.storage_pool.single_tier[0] = "'${disk_capacity}'" |
                .new_vcsa.appliance.thin_disk_mode = true |
                .new_vcsa.appliance.deployment_option = "small" |
                .new_vcsa.appliance.name = "'${vcsa_name}'" |
                .new_vcsa.network.ip = "'${cidr_mgmt_three_octets}'.'${ip_vcsa}'" |
                .new_vcsa.network.dns_servers[0] = "'${ip_gw}'" |
                .new_vcsa.network.prefix = "'$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)'" |
                .new_vcsa.network.gateway = "'$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)'" |
                .new_vcsa.network.system_name = "'${vcsa_name}'.'${domain}'" |
                .new_vcsa.os.password = "'${GENERIC_PASSWORD}'" |
                .new_vcsa.os.ntp_servers = "'${ip_gw}'" |
                .new_vcsa.os.ssh_enable = true |
                .new_vcsa.sso.password = "'${GENERIC_PASSWORD}'" |
                .new_vcsa.sso.domain_name = "'${ssoDomain}'" |
                .ceip.settings.ceip_enabled = 'false'' /home/ubuntu/json/vCSA_with_cluster_on_ESXi.json)"
echo "${contents}" | jq 'del (.new_vcsa.esxi.VCSA_cluster.storage_pool.single_tier)' | tee /home/ubuntu/json/vcenter_config.json
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VCSA installation on-going"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
/tmp/vcenter_cdrom/vcsa-cli-installer/lin64/vcsa-deploy install --accept-eula --acknowledge-ceip --no-esx-ssl-verify /home/ubuntu/json/vcenter_config.json
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VCSA installed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
ssh-keygen -f /home/ubuntu/.ssh/known_hosts -R ${vcsa_name}.${domain} || true
count=1
until $(curl --output /dev/null --silent --head -k https://${vcsa_name}.${domain})
do
  echo "Attempt ${count}: Waiting for vCenter host https://${vcsa_name}.${domain} to be reachable..."
  sleep 10
  count=$((count+1))
    if [[ "${count}" -eq 60 ]]; then
      echo "ERROR: Unable to connect to vCenter host https://${vcsa_name}.${domain}"
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vCenter host https://'${vcsa_name}'.'${domain}' unable to reach"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
      exit
    fi
done
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vCenter host https://'${vcsa_name}'.'${domain}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
echo "vCenter host https://${vcsa_name}.${domain} reachable"
rm -fr "/home/ubuntu/$(basename ${iso_url})"
rm -fr /tmp/vcenter_cdrom_mount
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "${vsphere_nested_username}" "${ssoDomain}" "${vsphere_nested_password}" "${api_host}")
vcenter_api 6 10 "PUT" $token '{"enabled":true}' "${api_host}" "api/appliance/access/ssh"
vcenter_api 6 10 "PUT" $token '{"enabled":true}' "${api_host}" "api/appliance/access/dcui"
vcenter_api 6 10 "PUT" $token '{"enabled":true}' "${api_host}" "api/appliance/access/consolecli"
vcenter_api 6 10 "PUT" $token '{"enabled":true,"timeout":120}' "${api_host}" "api/appliance/access/shell"
vcenter_api 6 10 "PUT" $token '{"max_days":0,"min_days":0,"warn_days":0}' "${api_host}" "api/appliance/local-accounts/global-policy"
#
# Add cluster(s) in dc
#
count_cluster=$(($(jq -r '.spec.esxi.ips | length' $jsonFile)/3))
for cluster in $(seq 1 ${count_cluster})
do
  if [[ ${cluster} -ne 1 ]] ; then
    load_govc_env_wo_cluster
    echo "Adding vSphere cluster ${cluster_basename}${cluster}"
    govc cluster.create "${cluster_basename}${cluster}" > /dev/null
  fi
done
#
# Add host in the cluster(s)
#
for esxi in $(seq 1 $(jq -r '.spec.esxi.ips | length' $jsonFile))
do
  if [[ ${esxi} != 1 ]] ; then
    load_govc_env_with_cluster "${cluster_basename}$((($esxi-1)/3+1))"
    echo "Adding ESXi host ${esxi_basename}${esxi}.${domain} in cluster ${cluster_basename}$((($esxi-1)/3+1))"
    govc cluster.add -hostname "${esxi_basename}${esxi}.${domain}" -username "root" -password "${GENERIC_PASSWORD}" -noverify > /dev/null
  fi
done
#
# saving vCenter uuid
#
govc about -json | tee /home/ubuntu/json/vcenter_about.json
#
# Network config
#
load_govc_env_wo_cluster
jq -c -r .vds_switches[] ${jsonFile} | while read vds
do
  echo "create vds $(echo ${vds} | jq -c -r '.name') with $(echo ${vds} | jq -c -r '.discovery_protocol'), mtu: $(echo ${vds} | jq -c -r '.mtu'), version $(echo ${vds} | jq -c -r '.version')"
  govc dvs.create -mtu $(echo ${vds} | jq -c -r '.mtu') -discovery-protocol $(echo ${vds} | jq -c -r '.discovery_protocol') -product-version=$(echo ${vds} | jq -c -r '.version') $(echo ${vds} | jq -c -r '.name') > /dev/null
done
#
jq -c -r .port_groups[] ${jsonFile} | while read port_group
do
  echo "create portgroup $(echo ${port_group} | jq -c -r '.name') in vds $(echo ${port_group} | jq -c -r '.vds_ref') with vlan $(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.type') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)"
  govc dvs.portgroup.add -dvs $(echo ${port_group} | jq -c -r '.vds_ref') -vlan "$(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.type') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)" $(echo ${port_group} | jq -c -r '.name') > /dev/null
done
#
if [[ ${kind} == "vsphere-avi" ]] ; then
  jq -c -r .port_groups_vsphere_avi[] ${jsonFile} | while read port_group
  do
    echo "create portgroup $(echo ${port_group} | jq -c -r '.name') in vds $(echo ${port_group} | jq -c -r '.vds_ref') with vlan $(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.name') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)"
    govc dvs.portgroup.add -dvs $(echo ${port_group} | jq -c -r '.vds_ref') -vlan "$(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.name') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)" $(echo ${port_group} | jq -c -r '.name') > /dev/null
  done
fi
#
if [[ ${kind} == "vsphere-nsx" ]] ; then
  jq -c -r .port_groups_nsx[] ${jsonFile} | while read port_group
  do
    echo "create portgroup $(echo ${port_group} | jq -c -r '.name') in vds $(echo ${port_group} | jq -c -r '.vds_ref') with vlan $(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.name') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)"
    govc dvs.portgroup.add -dvs $(echo ${port_group} | jq -c -r '.vds_ref') -vlan "$(jq -c -r --arg arg $(echo ${port_group} | jq -c -r '.name') '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)" $(echo ${port_group} | jq -c -r '.name') > /dev/null
  done
fi
#
# adding each ESXi hosts on vmnic1
#
for esxi in $(seq 1 $(jq -r '.spec.esxi.ips | length' $jsonFile))
do
  echo "Adding ESXi host ${esxi_basename}${esxi}.${domain} on $(jq -c -r .vds_switches[0].name ${jsonFile}) on pnic vmnic1"
  govc dvs.add -dvs $(jq -c -r .vds_switches[0].name ${jsonFile}) -pnic=vmnic1 "${esxi_basename}${esxi}.${domain}" > /dev/null
done
sleep 30
#
# moving VCSA VM to VDS
#
echo "migrating VCSA VM to VDS"
load_govc_env_with_cluster "${cluster_basename}1"
govc vm.network.change -vm ${vcsa_name} -net $(jq -c -r .port_groups[0].name $jsonFile) ethernet-0 & > /dev/null
govc_pid=$(echo $!)
echo "pausing for 10 seconds"
sleep 10
if ping -c 1 ${api_host} & > /dev/null
then
  echo "vCenter VM is UP"
  kill $(echo $govc_pid) || true
else
  echo "vCenter VM is DOWN - exit script config"
  exit
fi
#
# creating new vmk interfaces
#
echo "Creating new vmk interfaces"
/home/ubuntu/.local/bin/ansible-playbook /home/ubuntu/vcenter/vmk.yaml -e @${jsonFile}
echo "pausing for 30 seconds"
sleep 30
#
# migrating from standard vswitch to VDS
#
echo "migrating vmk1 and vmk2 to vds1"
for esxi in $(seq 1 $(jq -r '.spec.esxi.ips | length' $jsonFile))
do
  ip_last_octet=$(jq -r '.spec.esxi.ips['$(expr ${esxi} - 1)']' $jsonFile)
  # migrating vmk0, vmk1 and vmk2 to vds1
  echo "+++ connecting to root@${cidr_mgmt_three_octets}.${ip_last_octet}"
  echo "  +++ running: esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[3].old_vmk $jsonFile)"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[3].old_vmk $jsonFile)"
  echo "  +++ running: esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[3].vmk $jsonFile) --ipv4=${cidr_vmotion_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[3].vmk $jsonFile) --ipv4=${cidr_vmotion_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  #
  echo "  +++ running: esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[2].old_vmk $jsonFile)"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[2].old_vmk $jsonFile)"
  echo "  +++ running: esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[2].vmk $jsonFile) --ipv4=${cidr_vsan_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[2].vmk $jsonFile) --ipv4=${cidr_vsan_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  echo "  +++ running: esxcli network ip interface tag add -i $(jq -c -r .port_groups[2].vmk $jsonFile) -t VSAN"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network ip interface tag add -i $(jq -c -r .port_groups[2].vmk $jsonFile) -t VSAN"
  #
  echo "  +++ running: esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[1].old_vmk $jsonFile)"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_vsan_three_octets}.${ip_last_octet} "esxcli network ip interface remove --interface-name $(jq -c -r .port_groups[1].old_vmk $jsonFile)"
  echo "  +++ running: esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[1].vmk $jsonFile) --ipv4=${cidr_mgmt_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_vsan_three_octets}.${ip_last_octet} "esxcli network ip interface ipv4 set --interface-name=$(jq -c -r .port_groups[1].vmk $jsonFile) --ipv4=${cidr_mgmt_three_octets}.${ip_last_octet} --netmask=255.255.255.0 --type=static"
  #
done
echo "pausing for 30 seconds"
sleep 30
#
# cleaning standard Vswitch and adding vmnic0 in the vds
#
load_govc_env_with_cluster "${cluster_basename}1"
echo "cleaning standard Vswitch and adding vmnic0 in the vds"
for esxi in $(seq 1 $(jq -r '.spec.esxi.ips | length' $jsonFile))
do
  ip_last_octet=$(jq -r '.spec.esxi.ips['$(expr ${esxi} - 1)']' $jsonFile)
  echo "+++ connecting to root@${cidr_mgmt_three_octets}.${ip_last_octet}"
  echo "  +++ running: esxcli network vswitch standard uplink remove -u vmnic0 -v vSwitch0"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network vswitch standard uplink remove -u vmnic0 -v vSwitch0"
  echo "  +++ running: esxcli network vswitch standard remove -v vSwitch0"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "esxcli network vswitch standard remove -v vSwitch0"
  echo "  +++ running: port_id=XXX ; esxcfg-vswitch -P vmnic0 -V XXX $(jq -c -r .vds_switches[0].name ${jsonFile})"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "port_id=\$(esxcli network vswitch dvs vmware list | grep 'Port ID' | awk '{print \$3}' | head -2 | tail -1) ; esxcfg-vswitch -P vmnic0 -V \${port_id} $(jq -c -r .vds_switches[0].name ${jsonFile})"
  if [[ esxi -eq 1 ]] ; then
    echo "  +++ shutting down ${vcsa_name} VM"
    govc vm.power -s ${vcsa_name} > /dev/null
    echo "  +++ pausing for 60 seconds"
    sleep 60
  fi
  echo "  +++ running: reboot"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "reboot"
  echo "  +++ pausing for 60 seconds"
  sleep 60
  count=1
  until $(curl --output /dev/null --silent --head -k https://${cidr_mgmt_three_octets}.${ip_last_octet})
  do
    echo "  +++ Attempt ${count}: Waiting for ESXi host at https://${cidr_mgmt_three_octets}.${ip_last_octet} to be reachable..."
    sleep 10
    count=$((count+1))
      if [[ "${count}" -eq 60 ]]; then
        echo "  +++ ERROR: Unable to connect to ESXi host at https://${cidr_mgmt_three_octets}.${ip_last_octet}"
        exit
      fi
  done
  echo "  +++ ESXi host reachable at https://${cidr_mgmt_three_octets}.${ip_last_octet}"
  if [[ esxi -eq 1 ]] ; then
    echo "  +++ pausing for 120 seconds"
    sleep 120
    echo "  +++ restarting ${vcsa_name} VM: vim-cmd vmsvc/power.on 1"
    sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no root@${cidr_mgmt_three_octets}.${ip_last_octet} "vim-cmd vmsvc/power.on 1"
    echo "  +++ pausing for 300 seconds"
    sleep 300
  fi
done
#
# VSAN Configuration
#
count_cluster=$(($(jq -r '.spec.esxi.ips | length' $jsonFile)/3))
for cluster in $(seq 1 ${count_cluster})
do
  load_govc_env_with_cluster "${cluster_basename}${cluster}"
  echo "Enabling VSAN configuration for cluster ${cluster_basename}${cluster}"
  govc cluster.change -drs-enabled -ha-enabled -vsan-enabled -vsan-autoclaim "${cluster_basename}${cluster}" > /dev/null
done
# Adding host in VSAN config.
for esxi in $(seq 1 $(jq -r '.spec.esxi.ips | length' $jsonFile))
do
  load_govc_esxi
  ip_last_octet=$(jq -r '.spec.esxi.ips['$(expr ${esxi} - 1)']' $jsonFile)
  if [[ $esxi -ne 1 ]] ; then
    export GOVC_URL=${cidr_mgmt_three_octets}.${ip_last_octet}
    echo "Adding host ${cidr_mgmt_three_octets}.${ip_last_octet} in VSAN configuration"
    govc host.esxcli vsan storage tag add -t capacityFlash -d "${disk_capacity}" > /dev/null
    govc host.esxcli vsan storage add --disks "${disk_capacity}" -s "${disk_cache}" > /dev/null
  fi
done
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': vCenter configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
exit