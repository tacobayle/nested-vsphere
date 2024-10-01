#!/bin/bash
#
SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
deployment_name=$(jq -c -r .metadata.name $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .GENERIC_PASSWORD $jsonFile)
DOCKER_REGISTRY_USERNAME=$(jq -c -r .DOCKER_REGISTRY_USERNAME $jsonFile)
DOCKER_REGISTRY_PASSWORD=$(jq -c -r .DOCKER_REGISTRY_PASSWORD $jsonFile)
ssoDomain=$(jq -r '.spec.vsphere.ssoDomain' $jsonFile)
vsphere_nested_username="administrator"
vsphere_nested_password="${GENERIC_PASSWORD}"
dc=$(jq -c -r '.dc' $jsonFile)
vcsa_name=$(jq -c -r '.vcsa_name' $jsonFile)
domain=$(jq -c -r '.spec.domain' $jsonFile)
api_host="${vcsa_name}.${domain}"
folder=$(jq -c -r .spec.folder $jsonFile)
gw_name="${deployment_name}-gw"
cluster_basename=$(jq -c -r '.cluster_basename' $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_vmotion=$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_vmotion} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vmotion_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_vsan=$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_vsan} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vsan_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_app} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_app_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
kind=$(jq -c -r '.kind' $jsonFile)
disk_capacity=$(jq -c -r '.disks.capacity' $jsonFile)
disk_cache=$(jq -c -r '.disks.cache' $jsonFile)
esxi_basename=$(jq -c -r '.esxi_basename' $jsonFile)
ip_vcsa=$(jq -c -r '.spec.vsphere.ip' $jsonFile)
ip_gw=$(jq -c -r '.spec.gw.ip' $jsonFile)
network_ref_gw=$(jq -c -r .spec.gw.network_ref $jsonFile)
prefix_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).cidr' $jsonFile | cut -d"/" -f2)
default_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).gw' $jsonFile)
ntp_masters=$(jq -c -r '.spec.gw.ntp_masters' $jsonFile)
forwarders_netplan=$(jq -c -r '.spec.gw.dns_forwarders | join(",")' $jsonFile)
forwarders_bind=$(jq -c -r '.spec.gw.dns_forwarders | join(";")' $jsonFile)
networks=$(jq -c -r '.spec.networks' $jsonFile)
ips_esxi=$(jq -c -r '.spec.esxi.ips' $jsonFile)
if [[ $(jq -c -r '.spec.nsx.ip' $jsonFile) == "null" ]]; then
  ip_nsx=$(jq -c -r .spec.gw.ip $jsonFile)
fi
if [[ $(jq -c -r .spec.avi.ip $jsonFile) == "null" ]]; then
  ip_avi=$(jq -c -r .spec.gw.ip $jsonFile)
fi
trunk1=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
ubuntu_ova_url=$(jq -c -r .spec.gw.ova_url $jsonFile)
#
# Avi variables
#
folder_avi=$(jq -c -r '.avi_folder' $jsonFile)
if [[ $(jq -c -r .spec.avi.ip $jsonFile) != "null" ]]; then
  ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .spec.avi.ip $jsonFile)"
  ip_avi_last_octet=$(jq -c -r .spec.avi.ip $jsonFile)
fi
gw_avi=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
avi_ctrl_name=$(jq -c -r '.avi_ctrl_name' $jsonFile)
network_avi=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
avi_ova_url=$(jq -c -r .spec.avi.ova_url $jsonFile)
#
# App variables
#
ips_app=$(jq -c -r '.avi.app.ips' $jsonFile)
prefix_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
gw_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
app_basename=$(jq -c -r '.app_basename' $jsonFile)
app_apt_packages=$(jq -c -r '.app_apt_packages' $jsonFile)
docker_registry_repo_default_app=$(jq -c -r '.docker_registry_repo_default_app' $jsonFile)
docker_registry_repo_waf=$(jq -c -r '.docker_registry_repo_waf' $jsonFile)
app_tcp_default=$(jq -c -r '.app_tcp_default' $jsonFile)
app_tcp_waf=$(jq -c -r '.app_tcp_waf' $jsonFile)
network_ref_app="AVI-APP-BACKEND"
folder_app=$(jq -c -r '.folder_app' $jsonFile)
app_cpu=$(jq -c -r '.app_cpu' $jsonFile)
app_memory=$(jq -c -r '.app_memory' $jsonFile)
#
# NSX variables
#
folder_nsx=$(jq -c -r '.nsx_folder' $jsonFile)
if [[ $(jq -c -r .spec.nsx.ip $jsonFile) != "null" ]]; then
  ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .spec.nsx.ip $jsonFile)"
  ip_nsx_last_octet=$(jq -c -r .spec.nsx.ip $jsonFile)
fi
#netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
gw_nsx=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
nsx_manager_name=$(jq -c -r '.nsx_manager_name' $jsonFile)
network_nsx=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
nsx_ova_url=$(jq -c -r .spec.nsx.ova_url $jsonFile)