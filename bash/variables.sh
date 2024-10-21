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
ip_vcsa=$(jq -c -r '.spec.vsphere.ip' $jsonFile)
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
ips_esxi=$(jq -c -r '.spec.esxi.ips' $jsonFile)
iso_esxi_url=$(jq -c -r .spec.esxi.iso_url $jsonFile)
if [[ $(jq -c -r '.spec.nsx.ip' $jsonFile) == "null" ]]; then
  ip_nsx=$(jq -c -r .spec.gw.ip $jsonFile)
fi
if [[ $(jq -c -r .spec.avi.ip $jsonFile) == "null" ]]; then
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
ips_app=$(jq -c -r '.spec.avi.app.first.ips' $jsonFile)
ips_app_second=$(jq -c -r '.spec.avi.app.second.ips' $jsonFile)
app_tcp_default=$(jq -c -r '.app_tcp_default' $jsonFile)
app_tcp_waf=$(jq -c -r '.app_tcp_waf' $jsonFile)
folder_client=$(jq -c -r '.folder_client' $jsonFile)
ips_clients=$(jq -c -r '.spec.avi.client.ips' $jsonFile)
client_basename=$(jq -c -r '.client_basename' $jsonFile)
client_cpu=$(jq -c -r '.client_cpu' $jsonFile)
client_memory=$(jq -c -r '.client_memory' $jsonFile)
if [[ ${kind} == "vsphere-avi" ]]; then
  prefix_app=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
  gw_app=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  prefix_client=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
  gw_client=$(jq -c -r --arg arg "avi-vip" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  network_ref_vip="avi-vip"
fi
k8s_basename=$(jq -c -r '.k8s_basename' $jsonFile)
k8s_clusters=$(jq -c -r '.spec.k8s_clusters' $jsonFile)
k8s_basename_vm=$(jq -c -r '.k8s_basename_vm' $jsonFile)
k8s_node_cpu=$(jq -c -r '.k8s_node_cpu' $jsonFile)
k8s_node_memory=$(jq -c -r '.k8s_node_memory' $jsonFile)
k8s_node_disk=$(jq -c -r '.k8s_node_disk' $jsonFile)
k8s_apt_packages=$(jq -c -r '.k8s_apt_packages' $jsonFile)
docker_version=$(jq -c -r '.docker_version' $jsonFile)
pod_cidr=$(jq -c -r '.pod_cidr' $jsonFile)
#
# NSX variables
#
if [[ ${kind} == "vsphere-nsx" || ${kind} == "vsphere-nsx-avi" ]]; then
  nsx_avi_basename="-"
  folder_nsx=$(jq -c -r '.nsx.folder' $jsonFile)
  if [[ $(jq -c -r .spec.nsx.ip $jsonFile) != "null" ]]; then
    ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .spec.nsx.ip $jsonFile)"
    ip_nsx_last_octet=$(jq -c -r .spec.nsx.ip $jsonFile)
  fi
  cidr_nsx_external=$(jq -c -r --arg arg "nsx-external" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
  cidr_nsx_external_prefix_length=$(jq -c -r --arg arg "nsx-external" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
  if [[ ${cidr_nsx_external} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
    cidr_nsx_external_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  fi
  #netmask_avi=$(ip_netmask_by_prefix $(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2) "   ++++++")
  nsx_manager_name=$(jq -c -r '.nsx.manager_name' $jsonFile)
  network_nsx=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
  nsx_ova_url=$(jq -c -r .spec.nsx.ova_url $jsonFile)
  host_switch_profiles=$(jq -c -r .nsx.config.uplink_profiles $jsonFile)
  transport_zones=$(jq -c -r .nsx.config.transport_zones $jsonFile)
  ip_pools=$(jq -c -r .nsx.config.ip_pools $jsonFile)
  segments=$(jq -c -r .nsx.config.segments $jsonFile)
  transport_node_profiles=$(jq -c -r .nsx.config.transport_node_profiles $jsonFile)
  dhcp_servers=$(jq -c -r .nsx.config.dhcp_servers $jsonFile)
  nsx_groups=$(jq -c -r .nsx.config.nsx_groups $jsonFile)
  exclusion_list_groups=$(jq -c -r .nsx.config.exclusion_list_groups $jsonFile)
  nsx_port_group_mgmt=$(jq -c -r --arg arg "mgmt" '.port_groups[] | select( .scope == $arg).name' $jsonFile)
  nsx_port_group_overlay_edge=$(jq -c -r --arg arg "nsx-overlay-edge" '.port_groups_nsx[] | select( .scope == $arg).name' $jsonFile)
  nsx_port_group_external=$(jq -c -r --arg arg "nsx-external" '.port_groups_nsx[] | select( .scope == $arg).name' $jsonFile)
  ips_edge_mgmt=$(jq -c -r '.spec.nsx.edge.ips_mgmt' $jsonFile)
  if [[ $(jq -c -r '.spec.nsx.edge.size' $jsonFile | tr '[:upper:]' [:lower:]) == "small" ]] ;  then
    edge_cpu=2 ; edge_memory=4 ; edge_disk=200
  fi
  if [[ $(jq -c -r '.spec.nsx.edge.size' $jsonFile | tr '[:upper:]' [:lower:]) == "medium" ]] ;  then
    edge_cpu=4 ; edge_memory=8 ; edge_disk=200
  fi
  if [[ $(jq -c -r '.spec.nsx.edge.size' $jsonFile | tr '[:upper:]' [:lower:]) == "large" ]] ;  then
    edge_cpu=8 ; edge_memory=32 ; edge_disk=200
  fi
  if [[ $(jq -c -r '.spec.nsx.edge.size' $jsonFile | tr '[:upper:]' [:lower:]) == "extra_large" ]] ;  then
    edge_cpu=16 ; edge_memory=64 ; edge_disk=200
  fi
  basename_edge=$(jq -c -r .nsx.config.edge_node.basename $jsonFile)
  edge_host_switches=$(jq -c -r .nsx.config.edge_node.host_switch_spec.host_switches $jsonFile)
  edge_clusters=$(jq -c -r .nsx.config.edge_clusters $jsonFile)
  tier0s=$(jq -c -r .nsx.config.tier0s $jsonFile)
  tier0_starting_ip=11
  tier0_vip_starting_ip=211
  tier1s=$(jq -c -r .nsx.config.tier1s $jsonFile)
  supernet_overlay=$(jq -c -r '.spec.nsx.supernet_overlay' $jsonFile)
  supernet_overlay_third_octet=$(echo "${supernet_overlay}" | cut -d'.' -f3)
  supernet_first_two_octets=$(echo "${supernet_overlay}" | cut -d'.' -f1-2)
  segments_overlay="[]"
  segment_count=0
  amount_of_segment=$((${supernet_overlay_third_octet} + $(jq '.nsx.config.segments_overlay | length' $jsonFile) - 1))
  for i in $(seq ${supernet_overlay_third_octet} ${amount_of_segment})
  do
    cidr="${supernet_first_two_octets}.$i.0/24"
    cidr_three_octets="${supernet_first_two_octets}.$i."
    segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"cidr": "'${cidr}'",
                                                     "display_name": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)'",
                                                     "tier1": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)'",
                                                     "gateway_address": "'${cidr_three_octets}'1/24",
                                                     "dhcp_ranges": ["'${cidr_three_octets}''$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].dhcp_ranges[0]' $jsonFile | cut -d'-' -f1)'-'${cidr_three_octets}''$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].dhcp_ranges[0]' $jsonFile | cut -d'-' -f2)'"]
                                                     }')

    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.tanzu_supervisor_starting_ip' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"tanzu_supervisor_starting_ip": "'${cidr_three_octets}''$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tanzu_supervisor_starting_ip' $jsonFile)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.tanzu_supervisor_count' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"tanzu_supervisor_count": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tanzu_supervisor_count' $jsonFile)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.ips_app_first' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"ips_app_first": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].ips_app_first' $jsonFile)'}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.ips_app_second' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"ips_app_second": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].ips_app_second' $jsonFile)'}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.transport_zone' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"transport_zone": "'$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].transport_zone' $jsonFile)'"}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_private' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"lbaas_private": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].lbaas_private' $jsonFile)'}')
    fi
    if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_public' > /dev/null) ; then
      segments_overlay=$(echo ${segments_overlay} | jq '.['${segment_count}'] += {"lbaas_private": '$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].lbaas_public' $jsonFile)'}')
    fi
    ((segment_count++))
  done
  segment_overlay_file=$(jq -c -r '.nsx.config.segment_overlay_file' $jsonFile)
  echo ${segments_overlay} | tee ${segment_overlay_file}
fi
#
# Avi variables
#
folder_avi=$(jq -c -r '.avi_folder' $jsonFile)
if [[ $(jq -c -r .spec.avi.ip $jsonFile) != "null" ]]; then
  ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .spec.avi.ip $jsonFile)"
  ip_avi_last_octet=$(jq -c -r .spec.avi.ip $jsonFile)
fi
avi_ctrl_name=$(jq -c -r '.avi_ctrl_name' $jsonFile)
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
                                      "value": "/v1/'${ip_gw}'/sign/'${vault_pki_intermediate_role_name}'"
                                    },
                                    {
                                      "is_dynamic": false,
                                      "is_sensitive": true,
                                      "name": "vault_token",
                                      "value": "placeholder"
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
if [[ $(jq -c -r '.spec.avi.applicationprofile' $jsonFile) == "null" ]]; then
  applicationprofile=$(jq -c -r '.applicationprofile' $jsonFile)
else
  applicationprofile=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.applicationprofile $jsonFile)'')
  applicationprofile=$(echo ${applicationprofile} | jq '. += '$(jq -c -r '.applicationprofile' $jsonFile)'')
fi
if [[ $(jq -c -r '.spec.avi.httppolicyset' $jsonFile) == "null" ]]; then
  httppolicyset=$(jq -c -r '.httppolicyset' $jsonFile)
else
  httppolicyset=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.httppolicyset $jsonFile)'')
  httppolicyset=$(echo ${httppolicyset} | jq '. += '$(jq -c -r '.httppolicyset' $jsonFile)'')
fi
if [[ $(jq -c -r '.spec.avi.roles' $jsonFile) == "null" ]]; then
  roles=$(jq -c -r '.roles' $jsonFile)
else
  roles=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.roles $jsonFile)'')
  roles=$(echo ${roles} | jq '. += '$(jq -c -r '.roles' $jsonFile)'')
fi
if [[ $(jq -c -r '.spec.avi.tenants' $jsonFile) == "null" ]]; then
  tenants=$(jq -c -r '.tenants' $jsonFile)
else
  tenants=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.tenants $jsonFile)'')
  tenants=$(echo ${tenants} | jq '. += '$(jq -c -r '.tenants' $jsonFile)'')
fi
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
if [[ $(jq -c -r '.spec.avi.users' $jsonFile) == "null" ]]; then
  users=$(jq -c -r '.users' $jsonFile)
else
  users=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.users $jsonFile)'')
  users=$(echo ${users} | jq '. += '$(jq -c -r '.users' $jsonFile)'')
fi
avi_subdomain=$(jq -c -r '.avi_subdomain' $jsonFile)
avi_content_library_name=$(jq -c -r '.avi_content_library_name' $jsonFile)
avi_ipam_first=$(jq -c -r '.spec.avi.ipam_pool' $jsonFile | cut -d"-" -f1)
avi_ipam_last=$(jq -c -r '.spec.avi.ipam_pool' $jsonFile | cut -d"-" -f2)
if [[ ${kind} == "vsphere-avi" ]]; then
  avi_lsc_se_folder=$(jq -c -r '.avi_lsc_se_folder' $jsonFile)
  avi_lsc_kernel_version=$(jq -c -r '.avi_lsc_kernel_version' $jsonFile)
  lsc_ova_url=$(jq -c -r '.spec.avi.lsc.ova_url' $jsonFile)
  avi_lsc_se_basename=$(jq -c -r '.avi_lsc_se_basename' $jsonFile)
  avi_lsc_se_cpu=$(jq -c -r '.avi_lsc_se_cpu' $jsonFile)
  avi_lsc_se_memory=$(jq -c -r '.avi_lsc_se_memory' $jsonFile)
  avi_lsc_se_disk=$(jq -c -r '.avi_lsc_se_disk' $jsonFile)
  lsc_ips_last_octet=$(jq -c -r '.spec.avi.lsc.ips' $jsonFile)
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
  lsc_ips_mgmt=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_se_mgmt_three_octets}'." + (. | tostring))')
  lsc_ips_backend=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  lsc_ips_vip=$(echo ${lsc_ips_last_octet} | jq '. | map("'${cidr_vip_three_octets}'." + (. | tostring))')
  #
  network_ref_app="avi-app-backend"
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
  service_engine_groups=$(jq -c -r '.service_engine_groups' $jsonFile)
  ips_app_full=$(echo ${ips_app} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  ips_app_second_full=$(echo ${ips_app_second} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  avi_config_repo=$(jq -c -r '.avi_config_repo' $jsonFile)
  playbook=$(jq -c -r '.playbook_vcenter' $jsonFile)
  tag=$(jq -c -r '.tag_vcenter' $jsonFile)
  supernet_overlay_third_octet=0
  amount_of_segment=0
  se_group_ref="private"
fi
#
# pools and vs definitions
#
if [[ ${kind} == "vsphere-avi" || ${kind} == "vsphere-nsx-avi" ]] ; then
  pools="[]"
  virtual_services_http="[]"
  virtual_services_dns="[]"
  segment_count=0
  migration_pool=0
  content_switching_pool=0
  multi_tenant_pool=0
  for i in $(seq ${supernet_overlay_third_octet} ${amount_of_segment})
  do
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then
      nsx_segment_pool="false"
      nsx_segment_vip="false"
      nsx_dns="false"
      nsx_app_migration="false"
      content_switching_vip="false"
      multi_tenant_vip="false"
      cidr="${supernet_first_two_octets}.$i.0/24"
      cidr_three_octets="${supernet_first_two_octets}.$i."
      tier1_name=$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].tier1' $jsonFile)
      cidr_vip_prefix="${supernet_first_two_octets}.$i.0/24"
      network_ref_vip=$(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].display_name' $jsonFile)
      if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.ips_app_first' > /dev/null) ; then
        ips_app_full=$(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].ips_app_first' $jsonFile) | jq '. | map("'${cidr_three_octets}'" + (. | tostring))')
        nsx_segment_pool="true"
        ((content_switching_pool++))
        ((multi_tenant_pool++))
        ((migration_pool++))
      fi
      if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.ips_app_second' > /dev/null) ; then
        ips_app_second_full=$(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}'].ips_app_second' $jsonFile) | jq '. | map("'${cidr_three_octets}'" + (. | tostring))')
        nsx_segment_pool="true"
      fi
      virtual_service_dns='{"vrf_ref": "'${tier1_name}'"}'
      if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_public' > /dev/null) ; then
        se_group_ref="public"
        nsx_segment_vip="true"
      fi
      if $(echo $(jq -c -r '.nsx.config.segments_overlay['${segment_count}']' $jsonFile) | jq -e '.lbaas_private' > /dev/null) ; then
        se_group_ref="private"
        nsx_segment_vip="true"
        nsx_dns="true"
        content_switching_vip="true"
        nsx_app_migration="true"
        multi_tenant_vip="true"
      fi
      ((segment_count++))
    fi
    #
    # pool creation
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'pool1",
                "default_server_port": 80,
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_pool} == "true" ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'pool2",
                "default_server_port": '${app_tcp_default}',
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_pool} == "true" ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'pool3",
                "default_server_port": '${app_tcp_waf}',
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_pool} == "true" ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'pg1-pool1-app-v1",
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${migration_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'pg1-pool2-app-v2",
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_second_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${migration_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'blue-dev-Pool",
                "tenant_ref": "dev",
                "markers": [{"key": "app", "values": ["blue"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'blue-preprod-Pool",
                "tenant_ref": "preprod",
                "markers": [{"key": "app", "values": ["blue"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'blue-prod-Pool",
                "tenant_ref": "prod",
                "markers": [{"key": "app", "values": ["blue"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'orange-dev-Pool",
                "tenant_ref": "dev",
                "markers": [{"key": "app", "values": ["orange"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'orange-preprod-Pool",
                "tenant_ref": "preprod",
                "markers": [{"key": "app", "values": ["orange"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'orange-prod-Pool",
                "tenant_ref": "prod",
                "markers": [{"key": "app", "values": ["orange"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'green-dev-Pool",
                "tenant_ref": "dev",
                "markers": [{"key": "app", "values": ["green"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'green-preprod-Pool",
                "tenant_ref": "preprod",
                "markers": [{"key": "app", "values": ["green"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then pool="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then pool='{"vrf_ref": "'${tier1_name}'"}' ; fi
    pool=$(echo ${pool} | jq '. += {
                "name": "'${tier1_name}''${nsx_avi_basename}'green-prod-Pool",
                "tenant_ref": "prod",
                "markers": [{"key": "app", "values": ["green"]}],
                "lb_algorithm": "LB_ALGORITHM_ROUND_ROBIN",
                "default_server_port": 80,
                "type": "V4",
                "avi_app_server_ips": '$(echo ${ips_app_full} | jq -c -r .)'
              }')
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_pool} -eq 1 ]] ; then
      pools=$(jq '. += [$new_item]' --argjson new_item "${pool}" <<< "${pools}")
    fi
    #
    # httppolicyset
    #
    if [[ ${kind} == "vsphere-avi" || ${content_switching_pool} -eq 1 ]] ; then
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
                "pool_ref": "/api/pool?name='${tier1_name}''${nsx_avi_basename}'pool1",
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
                "pool_ref": "/api/pool?name='${tier1_name}''${nsx_avi_basename}'pool2",
                "status_code": "HTTP_LOCAL_RESPONSE_STATUS_CODE_200"
              }
            }
          ]
        },
        "name": "http-request-policy-content-switching"
      }'
      httppolicyset=$(jq '. += [$new_item]' --argjson new_item "${httppolicy}" <<< "${httppolicyset}")
    fi
    #
    # pool group
    #
    if [[ ${kind} == "vsphere-avi" || migration_pool -eq 1 ]] ; then
      pool_groups='
      [
        {
          "name": "pg1",
          "members": [
            {
              "name": "'${tier1_name}''${nsx_avi_basename}'pg1-pool1-app-v1",
              "ratio": 70
            },
            {
              "name": "'${tier1_name}''${nsx_avi_basename}'pg1-pool2-app-v2",
              "ratio": 30
            }
          ]
        }
      ]'
    fi
    #
    # vs creation
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                     "name": "'${tier1_name}''${nsx_avi_basename}'app-hello-world",
                     "type": "V4",
                     "cidr": "'${cidr_vip_prefix}'",
                     "network_ref": "'${network_ref_vip}'",
                     "pool_ref": "'${tier1_name}''${nsx_avi_basename}'pool1",
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
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'app-avi",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'pool2",
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
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'app-waf",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'pool3",
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
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'app-security",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'pool1",
                       "http_policies" : [
                         {
                           "http_policy_set_ref": "/api/httppolicyset?name=http-request-header",
                           "index": 11
                         }
                       ],
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
    if [[ ${kind} == "vsphere-avi" || ${nsx_segment_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'app-migration",
                       "type": "V4",
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
    if [[ ${kind} == "vsphere-avi" || ${nsx_app_migration} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                        "name": "'${tier1_name}''${nsx_avi_basename}'app-content-switching",
                        "type": "V4",
                        "cidr": "'${cidr_vip_prefix}'",
                        "network_ref": "'${network_ref_vip}'",
                        "pool_ref": "'${tier1_name}''${nsx_avi_basename}'pool2",
                        "http_policies" : [
                          {
                            "http_policy_set_ref": "/api/httppolicyset?name=http-request-policy-content-switching",
                            "index": 11
                          }
                        ],
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
    if [[ ${kind} == "vsphere-avi" || ${content_switching_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'blue-dev",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'blue-dev-Pool",
                       "tenant_ref": "dev",
                       "markers": [{"key": "app", "values": ["blue"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'blue-preprod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'blue-preprod-Pool",
                       "tenant_ref": "preprod",
                       "markers": [{"key": "app", "values": ["blue"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'blue-prod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'blue-prod-Pool",
                       "tenant_ref": "prod",
                       "markers": [{"key": "app", "values": ["blue"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'green-dev",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'green-dev-Pool",
                       "tenant_ref": "dev",
                       "markers": [{"key": "app", "values": ["green"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'green-preprod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'green-preprod-Pool",
                       "tenant_ref": "preprod",
                       "markers": [{"key": "app", "values": ["green"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'green-prod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'green-prod-Pool",
                       "tenant_ref": "prod",
                       "markers": [{"key": "app", "values": ["green"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'orange-dev",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'orange-dev-Pool",
                       "tenant_ref": "dev",
                       "markers": [{"key": "app", "values": ["orange"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'orange-preprod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'orange-preprod-Pool",
                       "tenant_ref": "preprod",
                       "markers": [{"key": "app", "values": ["orange"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_http="{}" ; fi
    if [[ ${kind} == "vsphere-nsx-avi" ]] ; then virtual_service_http='{"vrf_ref": "'${tier1_name}'"}' ; fi
    virtual_service_http=$(echo ${virtual_service_http} | jq '. += {
                       "name": "'${tier1_name}''${nsx_avi_basename}'orange-prod",
                       "type": "V4",
                       "cidr": "'${cidr_vip_prefix}'",
                       "network_ref": "'${network_ref_vip}'",
                       "pool_ref": "'${tier1_name}''${nsx_avi_basename}'orange-prod-Pool",
                       "tenant_ref": "prod",
                       "markers": [{"key": "app", "values": ["orange"]}],
                       "se_group_ref": "Default-Group",
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
    if [[ ${kind} == "vsphere-avi" || ${multi_tenant_vip} == "true" ]] ; then
      virtual_services_http=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_http}" <<< "${virtual_services_http}")
    fi
    #
    # dns vs
    #
    if [[ ${kind} == "vsphere-avi" ]] ; then virtual_service_dns="{}" ; fi
    if [[ ${kind} == "vsphere-avi" || ${nsx_dns} == "true" ]] ; then
    virtual_service_dns=$(echo ${virtual_service_dns} | jq '. += {
                           "name": "'${tier1_name}''${nsx_avi_basename}'app-dns",
                           "type": "V4",
                           "cidr": "'${cidr_vip_prefix}'",
                           "network_ref": "'${network_ref_vip}'",
                           "se_group_ref": "Default-Group",
                           "services": [{"port": 53}]
            }')
    virtual_services_dns=$(jq '. += [$new_item]' --argjson new_item "${virtual_service_dns}" <<< "${virtual_services_dns}")
    fi
  done
  #
  # virtual_services consolidation
  #
  virtual_services='{"http": '${virtual_services_http}', "dns": '${virtual_services_dns}'}'
fi
#
# Tanzu variables
#
configure_tanzu_supervisor=$(jq -r '.spec.tanzu.configure_tanzu_supervisor' $jsonFile)
configure_tanzu_workload=$(jq -r '.spec.tanzu.configure_tanzu_workload' $jsonFile)
supervisor_starting_ip_last_octet=$(jq -r '.spec.tanzu.supervisor_starting_ip' $jsonFile)
supervisor_count_ip=$(jq -r '.spec.tanzu.supervisor_count_ip' $jsonFile)
workload_starting_ip_last_octet=$(jq -r '.spec.tanzu.workload_starting_ip' $jsonFile)
workload_count_ip=$(jq -r '.spec.tanzu.workload_count_ip' $jsonFile)
if [[ ${kind} == "vsphere-avi" ]]; then
  supervisor_network="tanzu"
  worker_network="avi-app-backend"
  supervisor_starting_ip="${cidr_tanzu_three_octets}.${supervisor_starting_ip_last_octet}"
  workload_starting_ip="${cidr_app_three_octets}.${workload_starting_ip_last_octet}"
  ip_gw_tanzu=$(jq -c -r --arg arg "tanzu" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
  ip_gw_backend=$(jq -c -r --arg arg "avi-app-backend" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
fi
if [[ ${kind} == "vsphere-nsx-avi" ]]; then
  management_tanzu_segment=$(jq '.nsx.config.segments_overlay[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).display_name' ${segment_overlay_file})
  management_tanzu_cidr=$(jq '.nsx.config.segments_overlay[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).cidr' ${segment_overlay_file})
  management_tanzu_supervisor_starting_ip=$(jq '.nsx.config.segments_overlay[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).tanzu_supervisor_starting_ip' ${segment_overlay_file})
  management_tanzu_supervisor_count=$(jq '.nsx.config.segments_overlay[] | select(has("tanzu_supervisor_starting_ip") and has("tanzu_supervisor_count")).tanzu_supervisor_count' ${segment_overlay_file})
fi
tanzu_namespaces=$(jq -c -r '.tanzu.namespaces' $jsonFile)
tkc_clusters=$(jq -c -r '.tanzu.tkc_clusters' $jsonFile)
for cluster in $(echo ${tkc_clusters} | jq -c -r .[])
do
  tenants=$(echo $tenants | jq -c -r '. += [{"name": "'$(echo ${cluster} | jq -c -r .avi_tenant_name)'",
                                               "local": true,
                                               "config_settings" : {
                                                 "tenant_vrf": false,
                                                 "se_in_provider_context": '$(echo ${cluster} | jq -c -r .se_in_provider_context)',
                                                 "tenant_access_to_provider_se": true
                                               }}]')
done