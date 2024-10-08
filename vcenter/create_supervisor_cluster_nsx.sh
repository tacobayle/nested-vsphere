#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
#
# https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/namespace-management/clusters/clusteractionenable/post/
#
api_host="${1}"
vsphere_nested_username=administrator
vcenter_domain="${2}"
vsphere_nested_password="${3}"
content_library_id="${4}"
storage_policy_id="${5}"
external_gw_ip="${6}"
size_hint="${7}"
service_cidr_address="${8}"
service_cidr_prefix="${9}"
master_management_network_subnet_mask="${10}"
master_management_network_starting_address="${11}"
master_management_network_gateway="${12}"
master_management_network_address_count="${13}"
tanzu_supervisor_dvportgroup="${14}"
cluster_distributed_switch="${15}"
pod_cidr_address="${16}"
pod_cidr_prefix="${17}"
nsx_tier0_gateway="${18}"
nsx_edge_cluster="${19}"
namespace_subnet_prefix="${20}"
ingress_cidr_address="${21}"
ingress_cidr_prefix="${22}"
cluster_id="${23}"
#
# vCenter API session creation
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "$vsphere_nested_username" "$vcenter_domain" "$vsphere_nested_password" "$api_host")
#
# Building json data to create the supervisor cluster
#
network_provider="NSXT_CONTAINER_PLUGIN"
json_data='
{
  "default_kubernetes_service_content_library":"'${content_library_id}'",
  "ephemeral_storage_policy":"'${storage_policy_id}'",
  "image_storage":
  {
    "storage_policy":"'${storage_policy_id}'"
  },
  "master_storage_policy":"'${storage_policy_id}'",
  "cluster_proxy_config": {
    "proxy_settings_source": "VC_INHERITED"
  },
  "worker_DNS":["'${external_gw_ip}'"],
  "master_DNS":["'${external_gw_ip}'"],
  "workload_ntp_servers":["'${external_gw_ip}'"],
  "master_NTP_servers":["'${external_gw_ip}'"],
  "network_provider":"'${network_provider}'",
  "size_hint":"'${size_hint}'",
  "service_cidr":
  {
    "address":"'${service_cidr_address}'",
    "prefix": "'${service_cidr_prefix}'"
  },
  "master_management_network":
  {
    "mode":"STATICRANGE",
    "address_range":
      {
        "subnet_mask":"'${master_management_network_subnet_mask}'",
        "starting_address":"'${master_management_network_starting_address}'",
        "gateway":"'${master_management_network_gateway}'",
        "address_count":"'${master_management_network_address_count}'"
      },
    "network":"'${tanzu_supervisor_dvportgroup}'"
  },
  "ncp_cluster_network_spec":
  {
    "cluster_distributed_switch": "'${cluster_distributed_switch}'",
    "egress_cidrs": [],
    "ingress_cidrs": [
      {
        "address": "'${ingress_cidr_address}'",
        "prefix": "'${ingress_cidr_prefix}'"
      }
    ],
    "namespace_subnet_prefix": "'${namespace_subnet_prefix}'",
    "nsx_edge_cluster": "'${nsx_edge_cluster}'",
    "nsx_tier0_gateway": "'${nsx_tier0_gateway}'",
    "pod_cidrs": [
      {
        "address": "'${pod_cidr_address}'",
        "prefix": "'${pod_cidr_prefix}'"
      }
    ],
    "routed_mode": true
  }
}'
echo "${json_data}"
vcenter_api 6 10 "POST" $token "${json_data}" $api_host "api/vcenter/namespace-management/clusters/${cluster_id}?action=enable"
