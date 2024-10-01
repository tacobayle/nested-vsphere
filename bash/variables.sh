SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
deployment_name=$(jq -c -r .metadata.name $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .GENERIC_PASSWORD $jsonFile)
ssoDomain=$(jq -r '.spec.vsphere.ssoDomain' $jsonFile)
vsphere_nested_username="administrator"
vsphere_nested_password="${GENERIC_PASSWORD}"
dc=$(jq -c -r '.dc' $jsonFile)
vcsa_name=$(jq -c -r '.vcsa_name' $jsonFile)
domain=$(jq -c -r '.spec.domain' $jsonFile)
api_host="${vcsa_name}.${domain}"
cluster_basename=$(jq -c -r '.cluster_basename' $jsonFile)
folder=$(jq -c -r '.avi_folder' $jsonFile)
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
kind=$(jq -c -r '.kind' $jsonFile)
disk_capacity=$(jq -c -r '.disks.capacity' $jsonFile)
disk_cache=$(jq -c -r '.disks.cache' $jsonFile)
esxi_basename=$(jq -c -r '.esxi_basename' $jsonFile)
ip_vcsa=$(jq -c -r '.spec.vsphere.ip' $jsonFile)
ip_gw=$(jq -c -r '.spec.gw.ip' $jsonFile)
#
# Avi variables
#
ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .spec.avi.ip $jsonFile)"
gw_avi=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
avi_ctrl_name=$(jq -c -r '.avi_ctrl_name' $jsonFile)
network_avi=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
avi_ova_url=$(jq -c -r .spec.avi.ova_url $jsonFile)
#
# NSX variables
#
ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .spec.nsx.ip $jsonFile)"
#netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
gw_nsx=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
nsx_manager_name=$(jq -c -r '.nsx_manager_name' $jsonFile)
network_nsx=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
nsx_ova_url=$(jq -c -r .spec.nsx.ova_url $jsonFile)