#!/bin/bash
#
SLACK_WEBHOOK_URL=$(jq -c -r .SLACK_WEBHOOK_URL $jsonFile)
SLACK_WEBHOOK_URL_AVI=$(jq -c -r .SLACK_WEBHOOK_URL_AVI $jsonFile)
deployment_name=$(jq -c -r .metadata.name $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .GENERIC_PASSWORD $jsonFile)
AVI_OLD_PASSWORD=$(jq -c -r .AVI_OLD_PASSWORD $jsonFile)
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
cidr_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_app_prefix=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_app} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_app_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_vip=$(jq -c -r --arg arg "AVI-VIP" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_vip_prefix=$(jq -c -r --arg arg "AVI-VIP" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_vip} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_vip_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_tanzu=$(jq -c -r --arg arg "TANZU" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_tanzu_prefix=$(jq -c -r --arg arg "TANZU" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_tanzu} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_tanzu_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
cidr_se_mgmt=$(jq -c -r --arg arg "AVI-SE-MGMT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
cidr_se_mgmt_prefix=$(jq -c -r --arg arg "AVI-SE-MGMT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile)
if [[ ${cidr_se_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_se_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
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
# App variables
#
prefix_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f2)
gw_app=$(jq -c -r --arg arg "AVI-APP-BACKEND" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
app_basename=$(jq -c -r '.app_basename' $jsonFile)
app_apt_packages=$(jq -c -r '.app_apt_packages' $jsonFile)
docker_registry_repo_default_app=$(jq -c -r '.docker_registry_repo_default_app' $jsonFile)
docker_registry_repo_waf=$(jq -c -r '.docker_registry_repo_waf' $jsonFile)
folder_app=$(jq -c -r '.folder_app' $jsonFile)
app_cpu=$(jq -c -r '.app_cpu' $jsonFile)
app_memory=$(jq -c -r '.app_memory' $jsonFile)
ips_app=$(jq -c -r '.spec.avi.app.ips' $jsonFile)
app_tcp_default=$(jq -c -r '.app_tcp_default' $jsonFile)
app_tcp_waf=$(jq -c -r '.app_tcp_waf' $jsonFile)
#
# Avi variables
#
folder_avi=$(jq -c -r '.avi_folder' $jsonFile)
if [[ $(jq -c -r .spec.avi.ip $jsonFile) != "null" ]]; then
  ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .spec.avi.ip $jsonFile)"
  ip_avi_last_octet=$(jq -c -r .spec.avi.ip $jsonFile)
fi
gw_avi=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
gw_avi_se=$(jq -c -r --arg arg "AVI-SE-MGMT" '.spec.networks[] | select( .type == $arg).gw' $jsonFile)
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
if [[ $(jq -c -r '.spec.avi.tenants' $jsonFile) == "null" ]]; then
  tenants=$(jq -c -r '.tenants' $jsonFile)
else
  tenants=$(echo "[]" | jq '. += '$(jq -c -r .spec.avi.tenants $jsonFile)'')
  tenants=$(echo ${tenants} | jq '. += '$(jq -c -r '.tenants' $jsonFile)'')
fi
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
  network_ref_app="AVI-APP-BACKEND"
  ipam='["AVI-SE-MGMT", "AVI-APP-BACKEND", "AVI-VIP", "TANZU"]'
  networks_avi='[
              {
                "avi_ipam_pool": "'${cidr_se_mgmt_three_octets}'.'${avi_ipam_first}'-'${cidr_se_mgmt_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_se_mgmt_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": true,
                "name": "AVI-SE-MGMT",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_vip_three_octets}'.'${avi_ipam_first}'-'${cidr_vip_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_vip_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "AVI-VIP",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_app_three_octets}'.'${avi_ipam_first}'-'${cidr_se_mgmt_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_app_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "AVI-APP-BACKEND",
                "type": "V4"
              },
              {
                "avi_ipam_pool": "'${cidr_tanzu_three_octets}'.'${avi_ipam_first}'-'${cidr_tanzu_three_octets}'.'${avi_ipam_last}'",
                "cidr": "'${cidr_tanzu_prefix}'",
                "dhcp_enabled": false,
                "exclude_discovered_subnets": true,
                "management": false,
                "name": "TANZU",
                "type": "V4"
              }
            ]'
  contexts='[]'
  additional_subnets='[]'
  service_engine_groups=$(jq -c -r '.service_engine_groups' $jsonFile)
  ips_app_full=$(echo ${ips_app} | jq '. | map("'${cidr_app_three_octets}'." + (. | tostring))')
  pools="[]"
  virtual_services_http="[]"
  virtual_services_dns="[]"
  pool='{
              "name": "pool1",
              "default_server_port": '${app_tcp_default}',
              "type": "V4",
              "avi_app_server_ips": '${ips_app_full}'
            }'
  pools=$(echo ${pools} | jq '. += ['$(echo $pool| jq -c -r .)']')
  pool='{
              "name": "pool2",
              "default_server_port": '${app_tcp_waf}',
              "type": "V4",
              "avi_app_server_ips": '${ips_app_full}'
            }'
  pools=$(echo ${pools} | jq '. += ['$(echo $pool| jq -c -r .)']')
  virtual_service_http='{
                     "name": "app-avi",
                     "type": "V4",
                     "cidr": "'${cidr_vip_prefix}'",
                     "network_ref": "AVI-VIP",
                     "pool_ref": "pool1",
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
                   }'
  virtual_services_http=$(echo ${virtual_services_http} | jq '. += ['$(echo $virtual_service_http | jq -c -r .)']')
  virtual_service_http='{
                     "name": "app-waf",
                     "type": "V4",
                     "cidr": "'${cidr_vip_prefix}'",
                     "network_ref": "AVI-VIP",
                     "pool_ref": "pool2",
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
                   }'
  virtual_services_http=$(echo ${virtual_services_http} | jq '. += ['$(echo $virtual_service_http | jq -c -r .)']')
  virtual_service_dns='{
                         "name": "app-dns",
                         "type": "V4",
                         "cidr": "'${cidr_vip_prefix}'",
                         "network_ref": "AVI-VIP",
                         "se_group_ref": "Default-Group",
                         "services": [{"port": 53}]
                       }'
  virtual_services_dns=$(echo ${virtual_services_dns} | jq '. += ['$(echo $virtual_service_dns | jq -c -r .)']')
  virtual_services='{"http": '${virtual_services_http}', "dns": '${virtual_services_dns}'}'
  avi_config_repo=$(jq -c -r '.avi_config_repo' $jsonFile)
  playbook=$(jq -c -r '.playbook_vcenter' $jsonFile)
  tag=$(jq -c -r '.tag_vcenter' $jsonFile)
fi
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