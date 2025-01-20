#!/bin/bash
#
SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
SLACK_WEBHOOK_URL_AVI=$(jq -c -r .SLACK_WEBHOOK_URL_AVI $jsonFile)
deployment_name=$(jq -c -r .metadata.name $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .GENERIC_PASSWORD $jsonFile)
AVI_OLD_PASSWORD=$(jq -c -r .AVI_OLD_PASSWORD $jsonFile)
DOCKER_REGISTRY_USERNAME=$(jq -c -r .DOCKER_REGISTRY_USERNAME $jsonFile)
DOCKER_REGISTRY_PASSWORD=$(jq -c -r .DOCKER_REGISTRY_PASSWORD $jsonFile)
NSX_LICENSE=$(jq -c -r .NSX_LICENSE $jsonFile)
DOCKER_REGISTRY_EMAIL=$(jq -c -r .DOCKER_REGISTRY_EMAIL $jsonFile)
ssoDomain=$(jq -r '.spec.vsphere.ssoDomain' $jsonFile)
vsphere_nested_username="administrator"
vsphere_nested_password="${GENERIC_PASSWORD}"
dc=$(jq -c -r '.dc' $jsonFile)
vcsa_name=$(jq -c -r '.vcsa_name' $jsonFile)
domain=$(jq -c -r '.spec.domain' $jsonFile)
api_host="${vcsa_name}.${domain}"
folder=$(jq -c -r .spec.folder $jsonFile)
gw_name="${deployment_name}-gw"
gw_readonly_user=$(jq -c -r '.gw.readonly_user' $jsonFile)
gw_readonly_password=$(jq -c -r '.gw.readonly_password' $jsonFile)
kind=$(jq -c -r '.kind' $jsonFile)
cluster_basename=$(jq -c -r '.cluster_basename' $jsonFile)
ip_gw_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_mgmt_prefix_length=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
cidr_mgmt_prefix=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_vmotion=$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_vmotion_prefix=$(jq -c -r --arg arg "VMOTION" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_vmotion} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vmotion_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_vsan=$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_vsan_prefix=$(jq -c -r --arg arg "VSAN" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_vsan} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vsan_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
disk_capacity=$(jq -c -r '.disks.capacity' $jsonFile)
disk_cache=$(jq -c -r '.disks.cache' $jsonFile)
esxi_basename=$(jq -c -r '.esxi_basename' $jsonFile)
ip_vcsa=$(jq -c -r '.ip_vsphere' $jsonFile)
folders_to_copy=$(jq -c -r '.folders_to_copy' $jsonFile)
ip_gw=$(jq -c -r '.spec.gw.ip' $jsonFile)
ip_avi_dns=$(jq -c -r '.spec.gw.ip' $jsonFile)
network_ref_gw=$(jq -c -r .spec.gw.network_ref $jsonFile)
prefix_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).cidr' $jsonFile | cut -d"/" -f2)
default_gw=$(jq -c -r --arg arg "${network_ref_gw}" '.spec.vsphere_underlay.networks[] | select( .ref == $arg).gw' $jsonFile)
ntp_masters=$(jq -c -r '.spec.gw.ntp_masters' $jsonFile)
forwarders_netplan=$(jq -c -r '.spec.gw.dns_forwarders | join(",")' $jsonFile)
forwarders_bind=$(jq -c -r '.spec.gw.dns_forwarders | join(";")' $jsonFile)
networks=$(jq -c -r '.spec.networks' $jsonFile)
segments_overlay="[]"
cidr_nsx_external_three_octets="dummy_value"
tier0_vip_starting_ip="dummy_value"
ips_esxi=$(jq -c -r '.ips_esxi' $jsonFile)
iso_esxi_url=$(jq -c -r .spec.esxi.iso_url $jsonFile)
if [[ ${kind} == "vsphere" || ${kind} == "vsphere-avi" ]]; then
  ip_nsx=$(jq -c -r .spec.gw.ip $jsonFile)
fi
if [[ ${kind} == "vsphere" || ${kind} == "vsphere-nsx" ]]; then
  ip_avi=$(jq -c -r .spec.gw.ip $jsonFile)
fi
trunk1=$(jq -c -r .spec.esxi.nics[0] $jsonFile)
ubuntu_ova_url=$(jq -c -r .spec.gw.ova_url $jsonFile)
#
# Vault variables
#
vault_secret_file_path=$(jq -c -r '.vault.secret_file_path' $jsonFile)
vault_pki_name=$(jq -c -r '.vault.pki.name' $jsonFile)
vault_pki_max_lease_ttl=$(jq -c -r '.vault.pki.max_lease_ttl' $jsonFile)
vault_pki_cert_common_name=$(jq -c -r '.vault.pki.cert.common_name' $jsonFile)
vault_pki_cert_issuer_name=$(jq -c -r '.vault.pki.cert.issuer_name' $jsonFile)
vault_pki_cert_ttl=$(jq -c -r '.vault.pki.cert.ttl' $jsonFile)
vault_pki_cert_path=$(jq -c -r '.vault.pki.cert.path' $jsonFile)
vault_pki_role_name=$(jq -c -r '.vault.pki.role.name' $jsonFile)
vault_pki_intermediate_name=$(jq -c -r '.vault.pki_intermediate.name' $jsonFile)
vault_pki_intermediate_max_lease_ttl=$(jq -c -r '.vault.pki_intermediate.max_lease_ttl' $jsonFile)
vault_pki_intermediate_cert_common_name=$(jq -c -r '.vault.pki_intermediate.cert.common_name' $jsonFile)
vault_pki_intermediate_cert_issuer_name=$(jq -c -r '.vault.pki_intermediate.cert.issuer_name' $jsonFile)
vault_pki_intermediate_cert_path=$(jq -c -r '.vault.pki_intermediate.cert.path' $jsonFile)
vault_pki_intermediate_cert_path_signed=$(jq -c -r '.vault.pki_intermediate.cert.path_signed' $jsonFile)
vault_pki_intermediate_role_name=$(jq -c -r '.vault.pki_intermediate.role.name' $jsonFile)
vault_pki_intermediate_role_allow_subdomains=$(jq -c -r '.vault.pki_intermediate.role.allow_subdomains' $jsonFile)
vault_pki_intermediate_role_max_ttl=$(jq -c -r '.vault.pki_intermediate.role.max_ttl' $jsonFile)
#
# vcenter url
#
iso_vcenter_url=$(jq -c -r .spec.vsphere.iso_url $jsonFile)
#
# App and k8s variables
#
app_basename=$(jq -c -r '.app_basename' $jsonFile)
app_basename_second=$(jq -c -r '.app_basename_second' $jsonFile)
app_apt_packages=$(jq -c -r '.app_apt_packages' $jsonFile)
docker_registry_repo_default_app=$(jq -c -r '.docker_registry_repo_default_app' $jsonFile)
docker_registry_repo_waf=$(jq -c -r '.docker_registry_repo_waf' $jsonFile)
folder_app=$(jq -c -r '.folder_app' $jsonFile)
app_cpu=$(jq -c -r '.app_cpu' $jsonFile)
app_memory=$(jq -c -r '.app_memory' $jsonFile)
ips_app=$(jq -c -r '.avi.app.first.ips' $jsonFile)
ips_app_second=$(jq -c -r '.avi.app.second.ips' $jsonFile)
app_tcp_default=$(jq -c -r '.app_tcp_default' $jsonFile)
app_tcp_waf=$(jq -c -r '.app_tcp_waf' $jsonFile)
client_basename=$(jq -c -r '.client_basename' $jsonFile)
client_cpu=$(jq -c -r '.client_cpu' $jsonFile)
client_memory=$(jq -c -r '.client_memory' $jsonFile)
k8s_basename=$(jq -c -r '.k8s_basename' $jsonFile)
k8s_clusters=$(jq -c -r '.spec.k8s_clusters' $jsonFile)
k8s_basename_vm=$(jq -c -r '.k8s_basename_vm' $jsonFile)
k8s_node_cpu=$(jq -c -r '.k8s_node_cpu' $jsonFile)
k8s_node_memory=$(jq -c -r '.k8s_node_memory' $jsonFile)
k8s_node_disk=$(jq -c -r '.k8s_node_disk' $jsonFile)
k8s_apt_packages=$(jq -c -r '.k8s_apt_packages' $jsonFile)
k8s_namespaces=$(jq -c -r '.k8s_namespaces' $jsonFile)
docker_version=$(jq -c -r '.docker_version' $jsonFile)
pod_cidr=$(jq -c -r '.pod_cidr' $jsonFile)
#
# NSX variables
#
if [[ ${kind} == "vsphere-nsx" || ${kind} == "vsphere-nsx-avi" ]]; then
  nsx_avi_basename="-"
  nsx_username=$(jq -c -r '.nsx.username' $jsonFile)
  folder_nsx=$(jq -c -r '.nsx.folder' $jsonFile)
  ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .nsx.ip_manager $jsonFile)"
  ip_nsx_last_octet=$(jq -c -r .nsx.ip_manager $jsonFile)
  cidr_nsx_external=$(jq -c -r --arg arg "nsx-external" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  gw_nsx_external=$(jq -c -r --arg arg "nsx-external" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  nsx_group_app_name=$(jq -c -r '.nsx.nsx_group_app_name' $jsonFile)
  nsx_group_app_tag=$(jq -c -r '.nsx.nsx_group_app_tag' $jsonFile)
  cidr_nsx_external_prefix_length=$(jq -c -r --arg arg "nsx-external" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
  if [[ ${cidr_nsx_external} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_nsx_external_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  vlan_id_nsx_overlay=$(jq -c -r --arg arg "nsx-overlay" '.spec.networks[] | select( .type == $arg).vlan_id' $jsonFile)
  cidr_nsx_overlay=$(jq -c -r --arg arg "nsx-overlay" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  cidr_nsx_overlay_prefix=$(jq -c -r --arg arg "nsx-overlay" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  gw_nsx_overlay=$(jq -c -r --arg arg "nsx-overlay" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  if [[ ${cidr_nsx_overlay_prefix} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_nsx_overlay_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  ip_start_nsx_overlay="${cidr_nsx_overlay_three_octets}.$(jq -c -r .nsx.pool_start $jsonFile)"
  ip_end_nsx_overlay="${cidr_nsx_overlay_three_octets}.$(jq -c -r .nsx.pool_end $jsonFile)"

  cidr_nsx_overlay_edge=$(jq -c -r --arg arg "nsx-overlay-edge" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  cidr_nsx_overlay_edge_prefix=$(jq -c -r --arg arg "nsx-overlay-edge" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  if [[ ${cidr_nsx_overlay_edge_prefix} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_nsx_overlay_edge_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  gw_nsx_overlay_edge=$(jq -c -r --arg arg "nsx-overlay-edge" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  ip_start_nsx_overlay_edge="${cidr_nsx_overlay_edge_three_octets}.$(jq -c -r .nsx.pool_start $jsonFile)"
  ip_end_nsx_overlay_edge="${cidr_nsx_overlay_edge_three_octets}.$(jq -c -r .nsx.pool_end $jsonFile)"

  #netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
  nsx_manager_name=$(jq -c -r '.nsx.manager_name' $jsonFile)
  network_nsx=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
  nsx_ova_url=$(jq -c -r .spec.nsx.ova_url $jsonFile)
  host_switch_profiles=$(jq -c -r .nsx.config.uplink_profiles $jsonFile)
  transport_zones=$(jq -c -r .nsx.config.transport_zones $jsonFile)
  edge_node=$(jq -c -r .nsx.config.edge_node $jsonFile)
  ip_pools=$(jq -c -r .nsx.config.ip_pools $jsonFile)
  segments=$(jq -c -r .nsx.config.segments $jsonFile)
  transport_node_profiles=$(jq -c -r .nsx.config.transport_node_profiles $jsonFile)
  dhcp_servers=$(jq -c -r .nsx.config.dhcp_servers $jsonFile)
  nsx_groups=$(jq -c -r .nsx.config.nsx_groups $jsonFile)
  exclusion_list_groups=$(jq -c -r .nsx.config.exclusion_list_groups $jsonFile)
  nsx_port_group_mgmt=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
  nsx_port_group_overlay_edge=$(jq -c -r --arg arg "nsx-overlay-edge" '.port_groups_nsx[] | select( .scope == $arg).name' $jsonFile)
  nsx_port_group_external=$(jq -c -r --arg arg "nsx-external" '.port_groups_nsx[] | select( .scope == $arg).name' $jsonFile)
  ips_edge_mgmt=$(jq -c -r '.nsx.ips_edge' $jsonFile)
  edge_cpu=4 ; edge_memory=8 ; edge_disk=200
  basename_edge=$(jq -c -r .nsx.config.edge_node.basename $jsonFile)
  edge_host_switches=$(jq -c -r .nsx.config.edge_node.host_switch_spec.host_switches $jsonFile)
  edge_clusters=$(jq -c -r .nsx.config.edge_clusters $jsonFile)
  tier0s=$(jq -c -r .nsx.config.tier0s $jsonFile)
  tier0_starting_ip=11
  tier0_vip_starting_ip=211
  supernet_overlay=$(jq -c -r '.spec.nsx.supernet_overlay' $jsonFile)
  supernet_vip=$(jq -c -r '.spec.avi.supernet_vip' $jsonFile)
  supernet_vip_first_two_octets=$(echo "${supernet_vip}" | cut -d'.' -f1-2)
  supernet_vip_third_octet=$(echo "${supernet_vip}" | cut -d'.' -f3)
  supernet_nsx_vip=$(jq -c -r '.spec.nsx.supernet_vip' $jsonFile)
  supernet_nsx_vip_first_two_octets=$(echo "${supernet_nsx_vip}" | cut -d'.' -f1-2)
  supernet_nsx_vip_third_octet=$(echo "${supernet_nsx_vip}" | cut -d'.' -f3)
  nsx_vip_last_octet=$(jq -c -r '.nsx.config.nsx_vip_last_octet' $jsonFile)
  nsx_lb_size=$(jq -c -r '.nsx.config.lb_size' $jsonFile)
  nsx_lb_basename=$(jq -c -r '.nsx.config.lb_basename' $jsonFile)
  lb_vip_ports=$(jq -c -r '.nsx.config.lb_vip_ports' $jsonFile)
  lb_persistence_profile_path=$(jq -c -r '.nsx.config.lb_persistence_profile_path' $jsonFile)
  lb_application_profile_path=$(jq -c -r '.nsx.config.lb_application_profile_path' $jsonFile)
  lb_app_cert=$(jq -c -r '.nsx.config.lb_app_cert' $jsonFile)
  lb_ssl_profile_path=$(jq -c -r '.nsx.config.lb_ssl_profile_path' $jsonFile)
  #
  # tier1s - add nsx_vip_cidr if .nsx.config.tier1s[].lb is true
  #
  tier1s_spec=$(jq -c -r .nsx.config.tier1s $jsonFile)
  tier1s_file=$(jq -c -r '.nsx.config.tier1s_overlay_file' $jsonFile)
  tier1s="[]"
  echo ${tier1s_spec} | jq -c -r .[] | while read item
  do
    if $(echo ${item} | jq -e '.lb' > /dev/null) ; then
      if [[ $(echo ${item} | jq -c -r '.lb') == "true" ]] ; then
        item=$(echo ${item} | jq '. += {"nsx_vip_cidr": "'${supernet_nsx_vip_first_two_octets}'.'${supernet_nsx_vip_third_octet}'.0/24"}')
        ((supernet_nsx_vip_third_octet++))
      fi
    fi
    tier1s=$(echo ${tier1s} | jq '. += ['$(echo ${item} | jq -c -r '.')']')
    echo ${tier1s} | tee ${tier1s_file} > /dev/null 2>&1
  done
  tier1s=$(jq -c -r . ${tier1s_file})
  #
  supernet_overlay_third_octet=$(echo "${supernet_overlay}" | cut -d'.' -f3)
  supernet_first_two_octets=$(echo "${supernet_overlay}" | cut -d'.' -f1-2)
  segments_overlay="[]"
  segment_count=0
  amount_of_segment=$((${supernet_overlay_third_octet} + $(jq '.nsx.config.segments_overlay | length' $jsonFile) - 1))
  net_client_list=[]
  net_app_list=[]
  vip_subnet_index=0
  for i in $(seq ${supernet_overlay_third_octet} ${amount_of_segment})
  do
    cidr="${supernet_first_two_octets}.$i.0/24"
    cidr_three_octets="${supernet_first_two_octets}.$i"
    cidr_vip_subnet="${supernet_vip_first_two_octets}.$(($supernet_vip_third_octet+$vip_subnet_index)).0/24"
    cidr_vip_three_octets="${supernet_vip_first_two_octets}.$(($supernet_vip_third_octet+$vip_subnet_index))"
    segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"cidr": "'${cidr}'",
                                                     "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                     "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                     "cidr_three_octets": "'${cidr_three_octets}'",
                                                     "gateway_address": "'${cidr_three_octets}'.1/24",
                                                     "dhcp_ranges": ["'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].dhcp_ranges[0]' $jsonFile | cut -d'-' -f1)'-'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].dhcp_ranges[0]' $jsonFile | cut -d'-' -f2)'"]
                                                     }')

    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.tanzu_supervisor_starting_ip' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"tanzu_supervisor_starting_ip": "'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tanzu_supervisor_starting_ip' $jsonFile)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.tanzu_supervisor_count' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"tanzu_supervisor_count": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tanzu_supervisor_count' $jsonFile)'"}')
    fi
    if [[ $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq '.backend') == "true" ]] ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"backend": true}')
      net_app_list=$(echo ${net_app_list} | jq '. += [
                                                                    {
                                                                      "cidr": "'${cidr}'",
                                                                      "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                                      "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                                      "cidr_three_octets": "'${cidr_three_octets}'",
                                                                      "gw": "'${cidr_three_octets}'.1",
                                                                      "backend": true,
                                                                      "server_preserve_ip": false
                                                                    }
                                                                 ]')
      if [[ $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq '.server_preserve_ip') == "true" ]] ; then
        segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"server_preserve_ip": true}')
        net_app_list=$(echo ${net_app_list} | jq '.[-1] += {"server_preserve_ip": true}')
      fi
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.avi_mgmt' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"avi_mgmt": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_mgmt' $jsonFile)'}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.avi_ipam_pool_se' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"avi_ipam_pool_se": "'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f1)'-'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f2)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.avi_ipam_pool_vip' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"avi_ipam_vip": {"cidr": "'${cidr_vip_subnet}'", "pool": "'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f1)'-'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f2)'"}}')
      ((vip_subnet_index++))
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.transport_zone' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"transport_zone": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].transport_zone' $jsonFile)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_private' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"lbaas_private": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].lbaas_private' $jsonFile)'}')
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"cidr_vip": "'${cidr_vip_subnet}'"}')
      net_client_list=$(echo ${net_client_list} | jq '. += [
                                                             {
                                                               "cidr": "'${cidr}'",
                                                               "cidr_vip": "'${cidr_vip_subnet}'",
                                                               "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                               "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                               "cidr_three_octets": "'${cidr_three_octets}'",
                                                               "se_group_ref": "private",
                                                               "vip_preserve_ip": false,
                                                               "gw": "'${cidr_three_octets}'.1",
                                                               "avi_ipam_vip": {
                                                                 "cidr": "'${cidr_vip_subnet}'",
                                                                 "pool": "'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f1)'-'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f2)'"
                                                               },
                                                               "avi_ipam_pool_se": "'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f1)'-'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f2)'"
                                                             }
                                                           ]')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_public' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"lbaas_public": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].lbaas_public' $jsonFile)'}')
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"cidr_vip": "'${cidr_vip_subnet}'"}')
      net_client_list=$(echo ${net_client_list} | jq '. += [
                                                             {
                                                               "cidr": "'${cidr}'",
                                                               "cidr_vip": "'${cidr_vip_subnet}'",
                                                               "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                               "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                               "cidr_three_octets": "'${cidr_three_octets}'",
                                                               "se_group_ref": "public",
                                                               "vip_preserve_ip": false,
                                                               "gw": "'${cidr_three_octets}'.1",
                                                               "avi_ipam_vip": {
                                                                 "cidr": "'${cidr_vip_subnet}'",
                                                                 "pool": "'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f1)'-'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f2)'"
                                                               },
                                                               "avi_ipam_pool_se": "'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f1)'-'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f2)'"
                                                             }
                                                           ]')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.vip_preserve_ip' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"vip_preserve_ip": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].vip_preserve_ip' $jsonFile)'}')
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"cidr_vip": "'${cidr_vip_subnet}'"}')
      net_client_list=$(echo ${net_client_list} | jq '. += [
                                                             {
                                                               "cidr": "'${cidr}'",
                                                               "cidr_vip": "'${cidr_vip_subnet}'",
                                                               "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                               "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                               "cidr_three_octets": "'${cidr_three_octets}'",
                                                               "se_group_ref": "preserve_ip",
                                                               "vip_preserve_ip": true,
                                                               "gw": "'${cidr_three_octets}'.1",
                                                               "avi_ipam_vip": {
                                                                 "cidr": "'${cidr_vip_subnet}'",
                                                                 "pool": "'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f1)'-'${cidr_vip_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_vip' $jsonFile | cut -d"-" -f2)'"
                                                               },
                                                               "avi_ipam_pool_se": "'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f1)'-'${cidr_three_octets}'.'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].avi_ipam_pool_se' $jsonFile | cut -d"-" -f2)'"
                                                             }
                                                           ]')
    fi
    ((segment_count++))
  done
  segment_overlay_file=$(jq -c -r '.nsx.config.segment_overlay_file' $jsonFile)
  echo ${segments_overlay} | tee ${segment_overlay_file} > /dev/null 2>&1
  segments_overlay=$(jq -c -r . ${segment_overlay_file})
  ip_avi_dns=$(echo ${net_client_list} | jq -c -r .[0].avi_ipam_vip.pool | cut -d"-" -f1)
fi
#
# Avi variables
#
folder_avi=$(jq -c -r '.avi.ctrl_folder' $jsonFile)
ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .avi.ip_controller $jsonFile)"
vsdatascriptset=$(jq -c -r '.avi.vsdatascriptset' $jsonFile)
avi_username=$(jq -c -r '.avi.username' $jsonFile)
lbaas_username=$(jq -c -r '.avi.lbaas_username' $jsonFile)
lbaas_tenant=$(jq -c -r '.avi.lbaas_tenant' $jsonFile)
ip_avi_last_octet=$(jq -c -r .avi.ip_controller $jsonFile)
kube_starting_ip=$(jq -c -r '.avi.kube_starting_ip' $jsonFile)
content_library_name=$(jq -c -r '.avi.app.content_library_name' $jsonFile)
avi_ctrl_name=$(jq -c -r '.avi.ctrl_name' $jsonFile)
network_avi=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
avi_ova_url=$(jq -c -r .spec.avi.ova_url $jsonFile)
avi_version=$(jq -c -r .spec.avi.version $jsonFile)
import_sslkeyandcertificate_ca='[{"name": "'${vault_pki_intermediate_name}'",
                                  "cert": {"path": "'${vault_pki_intermediate_cert_path_signed}'"}},
                                 {"name": "'${vault_pki_name}'",
                                  "cert": {"path": "'${vault_pki_cert_path}'"}}]'
vault_certificate_management_profile=$(jq -c -r .vault.certificate_mgmt_profile.name $jsonFile)
vault_control_script_name=$(jq -c -r .vault.control_script.name $jsonFile)
certificatemanagementprofile='[
                                {
                                  "name": "'${vault_certificate_management_profile}'",
                                  "run_script_ref": "/api/alertscriptconfig/?name='${vault_control_script_name}'",
                                  "script_params": [
                                    {
                                      "is_dynamic": false,
                                      "is_sensitive": false,
                                      "name": "vault_addr",
                                      "value": "https://'${ip_gw}':8200"
                                    },
                                    {
                                      "is_dynamic": false,
                                      "is_sensitive": false,
                                      "name": "vault_path",
                                      "value": "/v1/'${vault_pki_intermediate_name}'/sign/'${vault_pki_intermediate_role_name}'"
                                    },
                                    {
                                      "is_dynamic": false,
                                      "is_sensitive": true,
                                      "name": "vault_token",
                                      "value": "dummy_value"
                                    }
                                  ]
                                }
                              ]'
alertscriptconfig='[{"action_script": {"path": "'$(jq -c -r .vault.control_script.path $jsonFile)'"},
                                      "name": "'$(jq -c -r .vault.control_script.name $jsonFile)'"},
                    {"action_script": {"path": "'$(jq -c -r .avi_slack.path $jsonFile)'"},
                                      "name": "'$(jq -c -r .avi_slack.name $jsonFile)'"}]'
actiongroupconfig='[{"control_script_name": "'$(jq -c -r .avi_slack.name $jsonFile)'", "name": "alert_slack"}]'
alertconfig='[{"name": "alert_config_slack","actiongroupconfig_name": "alert_slack"}]'
tanzu_cert_name=$(jq -c -r '.tanzu.cert' $jsonFile)
sslkeyandcertificate='[
                        {
                          "name": "'${tanzu_cert_name}'",
                          "format": "SSL_PEM",
                          "certificate_base64": true,
                          "enable_ocsp_stapling": false,
                          "import_key_to_hsm": false,
                          "is_federated": false,
                          "key_base64": true,
                          "type": "SSL_CERTIFICATE_TYPE_SYSTEM",
                          "certificate": {
                            "days_until_expire": 365,
                            "self_signed": true,
                            "version": "2",
                            "signature_algorithm": "sha256WithRSAEncryption",
                            "subject_alt_names": ["'${ip_avi}'"],
                            "issuer": {
                              "common_name": "https://'${avi_ctrl_name}.${domain}'",
                              "distinguished_name": "CN='${avi_ctrl_name}.${domain}'"
                            },
                            "subject": {
                              "common_name": "'${avi_ctrl_name}.${domain}'",
                              "distinguished_name": "CN='${avi_ctrl_name}.${domain}'"
                            }
                          },
                          "key_params": {
                            "algorithm": "SSL_KEY_ALGORITHM_RSA",
                            "rsa_params": {
                              "exponent": 65537,
                              "key_size": "SSL_KEY_2048_BITS"
                            }
                          },
                          "ocsp_config": {
                            "failed_ocsp_jobs_retry_interval": 3600,
                            "max_tries": 10,
                            "ocsp_req_interval": 86400,
                            "url_action": "OCSP_RESPONDER_URL_FAILOVER"
                          }
                         }
                      ]'
applicationprofile=$(jq -c -r '.applicationprofile' $jsonFile)
httppolicyset=$(jq -c -r '.httppolicyset' $jsonFile)
roles=$(jq -c -r '.roles' $jsonFile)
tenants=$(jq -c -r '.tenants' $jsonFile)
for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
do
  tenants=$(echo $tenants | jq -c -r '. += [{"name": "'${k8s_basename}${index}'",
                                               "local": true,
                                               "config_settings" : {
                                                 "tenant_vrf": false,
                                                 "se_in_provider_context": '$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].se_in_provider_context')',
                                                 "tenant_access_to_provider_se": true
                                               }}]')
done
users=$(jq -c -r '.users' $jsonFile)
avi_subdomain=$(jq -c -r '.avi.subdomain' $jsonFile)
avi_config_repo=$(jq -c -r '.avi.config_repo' $jsonFile)
helm_url=$(jq -c -r '.avi.helm_url' $jsonFile)
avi_content_library_name=$(jq -c -r '.avi_content_library_name' $jsonFile)
avi_ipam_first=$(jq -c -r '.avi.ipam_pool' $jsonFile | cut -d"-" -f1)
avi_ipam_last=$(jq -c -r '.avi.ipam_pool' $jsonFile | cut -d"-" -f2)
service_engine_groups=$(jq -c -r '.service_engine_groups' $jsonFile)
if [[ ${kind} == "vsphere-avi" ]]; then
  avi_lsc_se_folder=$(jq -c -r '.avi_lsc_se_folder' $jsonFile)
  avi_lsc_kernel_version=$(jq -c -r '.avi_lsc_kernel_version' $jsonFile)
  lsc_ova_url=$(jq -c -r '.spec.avi.lsc.ova_url' $jsonFile)
  avi_lsc_se_basename=$(jq -c -r '.avi_lsc_se_basename' $jsonFile)
  avi_lsc_se_cpu=$(jq -c -r '.avi_lsc_se_cpu' $jsonFile)
  avi_lsc_se_memory=$(jq -c -r '.avi_lsc_se_memory' $jsonFile)
  avi_lsc_se_disk=$(jq -c -r '.avi_lsc_se_disk' $jsonFile)
  lsc_ips_last_octet=$(jq -c -r '.avi.ips_se_lsc' $jsonFile)
  gw_avi_se=$(jq -c -r --arg arg "avi-se-mgmt" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  gw_avi_vip=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  avi_static_routes='[
                       {
                         "vrf_name": "management",
                         "addr": "0.0.0.0",
                         "type": "V4",
                         "mask": "0",
                         "next_hop": "'${gw_avi_se}'"
                       },
                       {
                         "vrf_name": "global",
                         "addr": "0.0.0.0",
                         "type": "V4",
                         "mask": "0",
                         "next_hop": "'${gw_avi_vip}'"
                       }
                     ]'
  #
  cidr_app=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  cidr_app_prefix=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  if [[ ${cidr_app} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_app_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  cidr_vip_full=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  cidr_vip=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  cidr_vip_prefix=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  if [[ ${cidr_vip} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_vip_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  cidr_tanzu=$(jq -c -r --arg arg "tanzu" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  cidr_tanzu_prefix=$(jq -c -r --arg arg "tanzu" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  if [[ ${cidr_tanzu} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_tanzu_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  cidr_se_mgmt=$(jq -c -r --arg arg "avi-se-mgmt" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  cidr_se_mgmt_prefix=$(jq -c -r --arg arg "avi-se-mgmt" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  if [[ ${cidr_se_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_se_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  #
  cidr_app=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
  gw_app=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  prefix_client=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
  gw_client=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  network_ref_vip="avi-vip"
  network_ref_app="avi-app-backend"
  net_client_list='[{"cidr_three_octets": "'${cidr_vip_three_octets}'", "cidr": "'${cidr_vip_full}'", "tier1": "dummy", "gw": "'${gw_client}'", "display_name": "'${network_ref_vip}'"}]'
  net_app_list='[{"cidr_three_octets": "'${cidr_app_three_octets}'", "cidr": "'${cidr_app}'", "tier1": "", "gw": "'${gw_app}'", "display_name": "'${network_ref_app}'"}]'
  #
  lsc_ips_mgmt=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_se_mgmt_three_octets}'." + (. | tostring))')
  lsc_ips_backend=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  lsc_ips_vip=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_vip_three_octets}'." + (. | tostring))')
  #
  ip_avi_dns="${cidr_vip_three_octets}.${avi_ipam_first}"
  ipam='{"networks": ["'${network_ref_vip}'"]}'
  networks_avi='[
              {
                "avi_ipam_pool": "'${cidr_se_mgmt_three_octets}'.'${avi_ipam_first}'-'${cidr_se_mgmt_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_se_mgmt_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": true,
                "name": "avi-se-mgmt",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_vip_three_octets}'.'${avi_ipam_first}'-'${cidr_vip_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_vip_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "'${network_ref_vip}'",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_app_three_octets}'.'${avi_ipam_first}'-'${cidr_app_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_app_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "avi-app-backend",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_tanzu_three_octets}'.'${avi_ipam_first}'-'${cidr_tanzu_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_tanzu_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "tanzu",
                "type": "V4"
              }
            ]'
  contexts='[]'
  additional_subnets='[]'
  ips_app_full=$(echo ${ips_app} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  ips_app_second_full=$(echo ${ips_app_second} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  playbook=$(jq -c -r '.playbook_vcenter' $jsonFile)
  tag=$(jq -c -r '.tag_vcenter' $jsonFile)
  supernet_overlay_third_octet=0
  amount_of_segment=0
  se_group_ref="private"
fi
if [[ ${kind} == "vsphere-nsx-avi" ]]; then
  nsx_cloud_name=$(jq -c -r '.avi.nsx.cloud.name' $jsonFile)
  cloud_obj_name_prefix=$(jq -c -r '.avi.nsx.cloud.cloud_obj_name_prefix' $jsonFile)
  playbook=$(jq -c -r '.playbook_nsx' $jsonFile)
  tag=$(jq -c -r '.tag_nsx' $jsonFile)
  #
  # Adding proper VRF, SEG and Floating IP for the preserve IP use case only for NSX cloud
  #
  network_services_tmp=$(jq -c -r '.network_services' $jsonFile)
  network_services="[]"
  for net_svc_index in $(seq 0 $(($(echo ${network_services_tmp} | jq -c -r '. | length')-1)))
  do
    network_service="{}"
    network_service=$(echo ${network_services_tmp} | jq -c -r '.['${net_svc_index}']')
    if [[ $(echo ${network_services_tmp} | jq -c -r '.['${net_svc_index}'].vip_preserve_ip') == "true" ]]; then
      vrf_preserve_ip=$(echo ${segments_overlay} | jq -c -r '[.[] | select(.vip_preserve_ip == true)] | first | .tier1')
      seg_preserve_ip=$(echo ${service_engine_groups} | jq -c -r '[.[] | select(.vip_preserve_ip == true)] | first | .name')
      floating_preserve_ip="$(echo ${segments_overlay} | jq -c -r '[.[] | select(.vip_preserve_ip == true)] | first | .cidr_three_octets').$(jq -c -r '.avi.preserve_ip_floating' $jsonFile)"
      network_service=$(echo ${network_service} | jq '. += { "se_group_ref": "'${seg_preserve_ip}'",
                                                             "vrf_ref": "'${vrf_preserve_ip}'",
                                                             "floating_intf_ip": "'${floating_preserve_ip}'"
                                                           }')
    fi
    network_services=$(jq '. += [$new_item]' --argjson new_item "${network_service}" <<< "${network_services}")
    echo "${network_services}" | jq -c -r . | tee /tmp/tmp.json >/dev/null 2>&1
    network_services=$(jq -c -r '.' /tmp/tmp.json)
  done
fi
#
# pools and vs definitions
#
one_done="false"
if [[ ${kind} == "vsphere-avi" || ${kind} == "vsphere-nsx-avi" ]] ; then
  if [[ ${ips_app} != "null" ]]; then
    pools="[]"
    virtual_services_http="[]"
    virtual_services_dns="[]"
    for net_vip in $(seq 0 $(($(echo ${net_client_list} | jq -c -r '. | length')-1)))
    do
      cidr_vip_prefix="$(echo ${net_client_list} | jq -r -c '.['${net_vip}'].cidr_vip')"
      network_ref_vip="$(echo ${net_client_list} | jq -r -c '.['${net_vip}'].display_name')"
      tier1_name="$(echo ${net_client_list} | jq -r -c '.['${net_vip}'].tier1')"
      se_group_ref="$(echo ${net_client_list} | jq -r -c '.['${net_vip}'].se_group_ref')"
      for net in $(seq 0 $(($(echo ${net_app_list} | jq -c -r '. | length')-1)))
      do
        network_ref_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].display_name')"
        server_preserve_ip=$(echo ${net_app_list} | jq -r -c '.['${net}'].server_preserve_ip')
        ips_app_full=$(echo "$(jq -c -r '.avi.app.first.ips' $jsonFile)" | jq '. | map("'$(echo ${net_app_list} | jq -r -c '.['${net}'].cidr_three_octets')'." + (. | tostring))')
        if [[ ${kind} == "vsphere-nsx-avi" ]]; then
          if [[ $(echo ${net_app_list} | jq -r -c '.['${net}'].server_preserve_ip') == $(echo ${net_client_list} | jq -r -c '.['${net_vip}'].vip_preserve_ip') ]]; then
            pool="{}"
            pool=$(echo ${pool} | jq '. += {
                        "name": "'${nsx_group_app_tag}_${network_ref_app}_${tier1_name}'",
                        "default_server_port": 80,
                        "tier1": "'${tier1_name}'",
                        "type": "nsx-group-based"
                      }')
            pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
            virtual_service_http="{}"
            virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                             "name": "'${tier1_name}''${nsx_avi_basename}'nsx-group",
                             "type": "V4",
                             "tier1": "'${tier1_name}'",
                             "cidr": "'${cidr_vip_prefix}'",
                             "network_ref": "'${network_ref_vip}'",
                             "pool_ref": "'${nsx_group_app_tag}_${network_ref_app}_${tier1_name}'",
                             "se_group_ref": "'${se_group_ref}'",
                             "services": [
                                           {
                                             "port": 80,
                                             "enable_ssl": false
                                            },
                                            {
                                              "port": 443,
                                              "enable_ssl": true
                                            }
                             ]
                    }')
            if [[ $(echo ${net_client_list} | jq -r -c '.['${net_vip}'].vip_preserve_ip') == "true" ]]; then
              app_profile_preserve_ip=$(echo ${applicationprofile} | jq -c -r '[.[] | select(.vip_preserve_ip == true)] | first | .name')
              virtual_service_http=$(echo ${virtual_service_http} | jq -c -r '. += {"application_profile_ref": "'${app_profile_preserve_ip}'"}')
              seg_preserve_ip=$(echo ${service_engine_groups} | jq -c -r '[.[] | select(.vip_preserve_ip == true)] | first | .name')
              virtual_service_http=$(echo ${virtual_service_http} | jq -c -r '. += {"se_group_ref": "'${seg_preserve_ip}'"}')
            fi
            virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
          fi
        fi
        if [[ ${kind} == "vsphere-avi" ]] ; then tier1_name="" ; fi
        pool_ports="[80, ${app_tcp_default}, ${app_tcp_waf}]"
        vs_names='["hello-world", "avi", "waf"]'
        for pool_ports_index in $(seq 0 $(($(echo ${pool_ports} | jq -c -r '. | length')-1)))
        do
          if [[ $(echo ${net_app_list} | jq -r -c '.['${net}'].server_preserve_ip') == "false" ]] && [[ $(echo ${net_client_list} | jq -r -c '.['${net_vip}'].vip_preserve_ip') == "false" ]]; then
            pool="{}"
            pool=$(echo ${pool} | jq '. += {
                        "name": "pool'$((${pool_ports_index} + 1))'_'${network_ref_app}'_'${tier1_name}'",
                        "default_server_port": '$(echo ${pool_ports} | jq -r -c '.['${pool_ports_index}']')',
                        "tier1": "'${tier1_name}'",
                        "type": "ip-based",
                        "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                        "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
                      }')
            pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
            virtual_service_http="{}"
            virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                             "name": "'${tier1_name}''${nsx_avi_basename}''$(echo ${vs_names} | jq -r -c '.['${pool_ports_index}']')'",
                             "type": "V4",
                             "tier1": "'${tier1_name}'",
                             "cidr": "'${cidr_vip_prefix}'",
                             "network_ref": "'${network_ref_vip}'",
                             "pool_ref": "pool'$((${pool_ports_index} + 1))'_'${network_ref_app}'_'${tier1_name}'",
                             "se_group_ref": "'${se_group_ref}'",
                             "services": [
                                           {
                                             "port": 80,
                                             "enable_ssl": false
                                            },
                                            {
                                              "port": 443,
                                              "enable_ssl": true
                                            }
                             ]
                    }')
            virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
          fi
        done
        #
        # pools and pool groups that are created only on the first app segments - which has not the server_preserve_ip flag
        #
        if [[ $(echo ${net_app_list} | jq -r -c '.['${net}'].server_preserve_ip') == "false" \
           && $(echo ${net_app_list} | jq -r -c '.['${net}'].tier1') == ${tier1_name} \
           && ${one_done} == "false" ]]; then
          one_done="true"
          #
          pool="{}"
          pool=$(echo ${pool} | jq '. += {
                      "name": "pool1-cs_'${network_ref_app}'_'${tier1_name}'",
                      "default_server_port": '$(echo ${pool_ports} | jq -c -r .[0])',
                      "tier1": "'${tier1_name}'",
                      "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                      "type": "ip-based",
                      "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
                    }')
          pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
          pool="{}"
          pool=$(echo ${pool} | jq '. += {
                      "name": "pool2-cs_'${network_ref_app}'_'${tier1_name}'",
                      "default_server_port": '$(echo ${pool_ports} | jq -c -r .[1])',
                      "tier1": "'${tier1_name}'",
                      "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                      "type": "ip-based",
                      "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
                    }')
          pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
          httppolicy='
          {
            "http_request_policy": {
              "rules": [
                {
                  "match": {
                    "path": {
                      "match_criteria": "CONTAINS",
                      "match_str": [
                        "hello",
                        "world"
                      ]
                    }
                  },
                  "name": "Rule 1",
                  "rewrite_url_action": {
                    "path": {
                      "tokens": [
                        {
                          "str_value": "index.html",
                          "type": "URI_TOKEN_TYPE_STRING"
                        }
                      ],
                      "type": "URI_PARAM_TYPE_TOKENIZED"
                    },
                    "query": {
                      "keep_query": true
                    }
                  },
                  "switching_action": {
                    "action": "HTTP_SWITCHING_SELECT_POOL",
                    "pool_ref": "/api/pool?name=pool1-cs_'${network_ref_app}'_'${tier1_name}'",
                    "status_code": "HTTP_LOCAL_RESPONSE_STATUS_CODE_200"
                  }
                },
                {
                  "match": {
                    "path": {
                      "match_criteria": "CONTAINS",
                      "match_str": [
                        "avi"
                      ]
                    }
                  },
                  "name": "Rule 2",
                  "rewrite_url_action": {
                    "path": {
                      "tokens": [
                        {
                          "str_value": "",
                          "type": "URI_TOKEN_TYPE_STRING"
                        }
                      ],
                      "type": "URI_PARAM_TYPE_TOKENIZED"
                    },
                    "query": {
                      "keep_query": true
                    }
                  },
                  "switching_action": {
                    "action": "HTTP_SWITCHING_SELECT_POOL",
                    "pool_ref": "/api/pool?name=pool2-cs_'${network_ref_app}'_'${tier1_name}'",
                    "status_code": "HTTP_LOCAL_RESPONSE_STATUS_CODE_200"
                  }
                }
              ]
            },
            "name": "http-request-policy-content-switching"
          }'
          httppolicyset=$(jq '. += [$new_item]' --argjson new_item "${httppolicy}" <<< "${httppolicyset}")
          #
          # dns vs
          #
          virtual_service_dns="{}"
          virtual_service_dns=$(echo ${virtual_service_dns} | jq '. += {
                                 "name": "'${tier1_name}''${nsx_avi_basename}'dns",
                                 "type": "V4",
                                 "tier1": "'${tier1_name}'",
                                 "cidr": "'${cidr_vip_prefix}'",
                                 "network_ref": "'${network_ref_vip}'",
                                 "se_group_ref": "Default-Group",
                                 "services": [{"port": 53}]
                  }')
          virtual_services_dns=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_dns}" <<< "${virtual_services_dns}")
          #
          # pool group
          #
          ips_app_second_full=$(echo "$(jq -c -r '.avi.app.second.ips' $jsonFile)" | jq '. | map("'$(echo ${net_app_list} | jq -r -c '.['${net}'].cidr_three_octets')'." + (. | tostring))')
          if [[ ${ips_app_second} != "null" ]]; then
            pool_groups='
            [
              {
                "name": "pg1",
                "members": [
                  {
                    "name": "pg1-pool1-app-v1",
                    "ratio": 70
                  },
                  {
                    "name": "pg1-pool2-app-v2",
                    "ratio": 30
                  }
                ]
              }
            ]'
            pool="{}"
            pool=$(echo ${pool} | jq '. += {
                        "name": "pg1-pool1-app-v1",
                        "default_server_port": 80,
                        "tier1": "'${tier1_name}'",
                        "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                        "type": "ip-based",
                        "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
                      }')
            pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
            #
            if [[ ${kind} == "vsphere-avi" ]] ; then tier1_name="" ; fi
            pool="{}"
            pool=$(echo ${pool} | jq '. += {
                        "name": "pg1-pool2-app-v2",
                        "default_server_port": 80,
                        "tier1": "'${tier1_name}'",
                        "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                        "type": "ip-based",
                        "avi_app_server_ips": '$(echo ${ips_app_second_full} | jq -c -r .)'
                      }')
            pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
            #
            #
            virtual_service_http="{}"
            virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                               "name": "'${tier1_name}''${nsx_avi_basename}'content-switching",
                               "type": "V4",
                               "tier1": "'${tier1_name}'",
                               "cidr": "'${cidr_vip_prefix}'",
                               "network_ref": "'${network_ref_vip}'",
                               "pool_ref": "pool1-cs_'${network_ref_app}'_'${tier1_name}'",
                               "http_policies": [{"http_policy_set_ref": "/api/httppolicyset?name=http-request-policy-content-switching", "index": 11}],
                               "se_group_ref": "private",
                               "services": [
                                             {
                                               "port": 80,
                                               "enable_ssl": false
                                              },
                                              {
                                                "port": 443,
                                                "enable_ssl": true
                                              }
                               ]
                    }')
            virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
            #
            #
            virtual_service_http="{}"
            virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                               "name": "'${tier1_name}''${nsx_avi_basename}'migration",
                               "type": "V4",
                               "tier1": "'${tier1_name}'",
                               "cidr": "'${cidr_vip_prefix}'",
                               "network_ref": "'${network_ref_vip}'",
                               "pool_group_ref": "pg1",
                               "se_group_ref": "private",
                               "services": [
                                             {
                                               "port": 80,
                                               "enable_ssl": false
                                              },
                                              {
                                                "port": 443,
                                                "enable_ssl": true
                                              }
                               ]
                    }')
            virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
          fi
          #
          colors='["blue", "orange", "green"]'
          tenants_vs='["dev", "preprod", "prod"]'
          for color_index in $(seq 0 $(($(echo ${colors} | jq -c -r '. | length')-1)))
          do
            color="$(echo ${colors} | jq -r -c '.['${color_index}']')"
            for tenant_index in $(seq 0 $(($(echo ${tenants_vs} | jq -c -r '. | length')-1)))
            do
              tenant="$(echo ${tenants_vs} | jq -r -c '.['${tenant_index}']')"
              pool="{}"
              pool=$(echo ${pool} | jq '. += {
                          "name": "'${color}'-'${tenant}'-Pool",
                          "tenant_ref": "'${tenant}'",
                          "tier1": "'${tier1_name}'",
                          "markers": [{"key": "app", "values": ["'${color}'"]}],
                          "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                          "default_server_port": 80,
                          "type": "ip-based",
                          "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
                        }')
              pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
              virtual_service_http="{}"
              virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                                 "name": "'${tier1_name}''${nsx_avi_basename}''${color}'-'${tenant}'",
                                 "type": "V4",
                                 "tier1": "'${tier1_name}'",
                                 "cidr": "'${cidr_vip_prefix}'",
                                 "network_ref": "'${network_ref_vip}'",
                                 "pool_ref": "'${color}'-'${tenant}'-Pool",
                                 "tenant_ref": "'${tenant}'",
                                 "markers": [{"key": "app", "values": ["'${color}'"]}],
                                 "se_group_ref": "'${se_group_ref}'",
                                 "services": [
                                               {
                                                 "port": 80,
                                                 "enable_ssl": false
                                                },
                                                {
                                                  "port": 443,
                                                  "enable_ssl": true
                                                }
                                 ]
                      }')
              if [[ $(echo ${tenants} | jq -c -r --arg arg1 "${tenant}" '.[] | select(.name == $arg1).config_settings.se_in_provider_context') == "false" ]] ; then
                virtual_service_http=$(echo ${virtual_service_http} | jq '. += {"se_group_ref": "Default-Group"}')
              else
                virtual_service_http=$(echo ${virtual_service_http} | jq '. += {"se_group_ref": "'${se_group_ref}'"}')
              fi
              virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
            done
          done
        fi
      done
    done
    echo "${pools}" | jq -c -r . | tee /tmp/tmp.json >/dev/null 2>&1
    pools=$(jq -c -r '.' /tmp/tmp.json)
    virtual_services='{"http": '${virtual_services_http}', "dns": '${virtual_services_dns}'}'
    echo "${virtual_services}" | jq -c -r . | tee /tmp/tmp.json >/dev/null 2>&1
    virtual_services=$(jq -c -r '.' /tmp/tmp.json)
  fi
fi
#
# Tanzu variables
#
configure_supervisor=$(jq -r '.spec.tanzu.configure_supervisor' $jsonFile)
configure_namespace=$(jq -r '.spec.tanzu.configure_namespace' $jsonFile)
configure_workload=$(jq -r '.spec.tanzu.configure_workload' $jsonFile)
supervisor_starting_ip_last_octet=$(jq -r '.tanzu.supervisor_starting_ip' $jsonFile)
supervisor_count_ip=$(jq -r '.tanzu.supervisor_count_ip' $jsonFile)
workload_starting_ip_last_octet=$(jq -r '.tanzu.workload_starting_ip' $jsonFile)
workload_count_ip=$(jq -r '.tanzu.workload_count_ip' $jsonFile)
if [[ ${kind} == "vsphere-avi" ]]; then
  management_tanzu_segment="tanzu"
  worker_network="avi-app-backend"
  supervisor_starting_ip="${cidr_tanzu_three_octets}.${supervisor_starting_ip_last_octet}"
  workload_starting_ip="${cidr_app_three_octets}.${workload_starting_ip_last_octet}"
  ip_gw_tanzu=$(jq -c -r --arg arg "tanzu" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  ip_gw_backend=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  supervisor_cluster_namespace_cidr="1.1.1.0/24"
  supervisor_cluster_ingress_cidr="1.1.1.0/24"
fi
if [[ ${kind} == "vsphere-nsx-avi" ]]; then
  management_tanzu_segment=$(jq -c -r '.[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).display_name' ${segment_overlay_file})
  management_tanzu_cidr=$(jq -c -r '.[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).cidr' ${segment_overlay_file})
  management_tanzu_gw=$(jq -c -r '.[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).gateway_address' ${segment_overlay_file})
  management_tanzu_supervisor_starting_ip=$(jq -c -r '.[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).tanzu_supervisor_starting_ip' ${segment_overlay_file})
  management_tanzu_supervisor_count=$(jq -c -r '.[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).tanzu_supervisor_count' ${segment_overlay_file})
  supervisor_cluster_namespace_tier0=$(jq -c -r '.tanzu.supervisor_cluster.namespace_tier0' $jsonFile)
  supervisor_cluster_prefix_per_namespace=$(jq -c -r '.tanzu.supervisor_cluster.prefix_per_namespace' $jsonFile)
  supervisor_cluster_namespace_cidr=$(jq -c -r '.tanzu.supervisor_cluster.namespace_cidr' $jsonFile)
  supervisor_cluster_ingress_cidr=$(jq -c -r '.tanzu.supervisor_cluster.ingress_cidr' $jsonFile)
fi
supervisor_cluster_size=$(jq -c -r '.tanzu.supervisor_cluster.size' $jsonFile)
supervisor_cluster_service_cidr=$(jq -c -r '.tanzu.supervisor_cluster.service_cidr' $jsonFile)
tanzu_namespaces=$(jq -c -r '.tanzu.namespaces' $jsonFile)
tkc_clusters=$(jq -c -r '.tanzu.tkc_clusters' $jsonFile)
for cluster in $(echo ${tkc_clusters} | jq -c -r .[])
do
  tenants=$(echo "$tenants" | jq -c -r '. += [{"name": "'$(echo ${cluster} | jq -c -r .avi_tenant_name)'",
                                               "local": true,
                                               "config_settings" : {
                                                 "tenant_vrf": false,
                                                 "se_in_provider_context": '$(echo ${cluster} | jq -c -r .se_in_provider_context)',
                                                 "tenant_access_to_provider_se": true
                                               }}]')
done