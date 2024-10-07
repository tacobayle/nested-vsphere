#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
#
api_host="${1}"
vsphere_nested_username=administrator
vcenter_domain="${2}"
vsphere_nested_password="${3}"
external_gw_ip="${4}"
storage_policy_id="${5}"
service_cidr_address="${6}"
service_cidr_prefix="${7}"
size_hint="${8}"
network_provider="VSPHERE_NETWORK"
master_management_network_subnet_mask="${9}"
master_management_network_starting_address="${10}"
master_management_network_gateway="${11}"
master_management_network_address_count="${12}"
master_management_network_network="${13}"
avi_cert="${14}"
avi_password="${15}"
avi_ip="${16}"
content_library_id="${17}"
supervisor_primary_workload_network_network="${18}"
supervisor_primary_workload_network_address="${19}"
supervisor_primary_workload_network_count="${20}"
supervisor_primary_workload_network_gateway="${21}"
tanzu_worker_dvportgroup="${22}"
supervisor_primary_workload_network_subnet_mask="${23}"
cluster_id="${24}"
#
# vCenter API session creation
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Building json data to create the supervisor cluster
#
json_data='
{
  "cluster_proxy_config": {
    "proxy_settings_source": "VC_INHERITED"
  },
  "workload_ntp_servers":["'${external_gw_ip}'"],
  "image_storage":
  {
    "storage_policy":"'${storage_policy_id}'"
  },
  "master_NTP_servers":["'${external_gw_ip}'"],
  "ephemeral_storage_policy":"'${storage_policy_id}'",
  "service_cidr":
  {
    "address":"'${service_cidr_address}'",
    "prefix": '${service_cidr_prefix}'
  },
  "size_hint":"'${size_hint}'",
  "worker_DNS":["'${external_gw_ip}'"],
  "master_DNS":["'${external_gw_ip}'"],
  "network_provider":"'${network_provider}'",
  "master_storage_policy":"'${storage_policy_id}'",
  "master_management_network":
  {
    "mode":"STATICRANGE",
    "address_range":
      {
        "subnet_mask":"'${master_management_network_subnet_mask}'",
        "starting_address":"'${master_management_network_starting_address}'",
        "gateway":"'${master_management_network_gateway}'",
        "address_count":'${master_management_network_address_count}'
      },
    "network":"'${master_management_network_network}'"
  },
  "load_balancer_config_spec": {
    "address_ranges": [],
    "avi_config_create_spec": {
      "certificate_authority_chain": '${avi_cert}',
      "password": "'${avi_password}'",
      "server": {
        "host": "'${avi_ip}'",
        "port": 443
      },
      "username": "admin"
    },
    "id": "avi",
    "provider": "AVI"
  },
  "default_kubernetes_service_content_library":"'${content_library_id}'",
  "workload_networks_spec": {
    "supervisor_primary_workload_network": {
      "network": "'${supervisor_primary_workload_network_network}'",
      "network_provider": "'${network_provider}'",
      "vsphere_network": {
        "address_ranges": [
          {
            "address": "'${supervisor_primary_workload_network_address}'",
            "count": '${supervisor_primary_workload_network_count}'
          }
        ],
        "gateway": "'${supervisor_primary_workload_network_gateway}'",
        "ip_assignment_mode": "STATICRANGE",
        "portgroup": "'${tanzu_worker_dvportgroup}'",
        "subnet_mask": "'${supervisor_primary_workload_network_subnet_mask}'"
      }
    }
  }
}'
echo "${json_data}"
vcenter_api 6 10 "POST" $token "${json_data}" $api_host "api/vcenter/namespace-management/clusters/${cluster_id}?action=enable"