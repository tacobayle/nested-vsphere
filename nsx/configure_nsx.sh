#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': starting NSX manager config."}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# check NSX Manager
#
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:${GENERIC_PASSWORD} -k -s -o /dev/null -w '%{http_code}' https://${ip_nsx}/api/v1/cluster/status)" != "200" ]]; do
  echo "waiting for NSX Manager API to be ready"
  sleep ${pause}
  ((attempt++))
  if [ ${attempt} -eq ${retry} ]; then
    echo "FAILED to get NSX Manager API to be ready after ${retry}"
    exit
  fi
done
#
# https://docs.vmware.com/en/VMware-NSX/4.1/administration/GUID-4ABD4548-4442-405D-AF04-6991C2022137.html
#
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:${GENERIC_PASSWORD} -k -s  https://${ip_nsx}/api/v1/cluster/status | jq -r .detailed_cluster_status.overall_status)" != "STABLE" ]]; do
  echo "waiting for NSX Manager API to be STABLE"
  sleep ${pause}
  ((attempt++))
  if [ ${attempt} -eq ${retry} ]; then
    echo "FAILED to get NSX Manager API to be STABLE after ${retry}"
    exit
  fi
done
echo "NSX Manager ready at https://${ip_nsx}"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX Manager ready at https://'${ip_nsx}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# Upload the license
#
/bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "api/v1/licenses" \
            "POST" \
            "{\"license_key\": \"${NSX_LICENSE}\"}"
#
# Accept EULA
#
/bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "policy/api/v1/eula/accept" \
            "POST" \
            ""
#
# host-switch-profiles
#
echo ${host_switch_profiles} | jq -c -r .[] | while read item
do
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/host-switch-profiles/$(echo ${item} | jq -c -r '.display_name')" \
              "PUT" \
              "${item}"
done
#
# Transport Zones
#
echo ${transport_zones} | jq -c -r .[] | while read zone
do
  /bin/bash /home/ubuntu/nsx/set_transport_zones.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "${zone}"
done
#
# register compute manager
#
/bin/bash /home/ubuntu/nsx/register_compute_manager.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "${vsphere_nested_username}" \
            "${ssoDomain}" \
            "${api_host}" \
            "${vsphere_nested_password}"
#
# create ip pools
#
echo ${ip_pools} | jq -c -r .[] | while read pool
do
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/ip-pools/$(echo ${pool} | jq -c -r '.display_name')" \
              "PATCH" \
              "{\"display_name\": \"$(echo ${pool} | jq -c -r '.display_name')\"}"
done
#
# create ip pool subnets
#
echo ${ip_pools} | jq -c -r .[] | while read pool
do
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/ip-pools/$(echo ${pool} | jq -c -r '.display_name')/ip-subnets/$(echo ${pool} | jq -c -r '.display_name')-subnet" \
              "PATCH" \
              "{\"display_name\": \"$(echo ${pool} | jq -c -r '.display_name')-subnet\",
                \"resource_type\": \"$(echo ${pool} | jq -c -r '.resource_type')\",
                \"cidr\": \"$(echo ${pool} | jq -c -r '.cidr')\",
                \"gateway_ip\": \"$(echo ${pool} | jq -c -r '.gateway')\",
                \"allocation_ranges\": [
                  {
                    \"start\": \"$(echo ${pool} | jq -c -r '.start')\",
                    \"end\": \"$(echo ${pool} | jq -c -r '.end')\",
                  }
                ]
              }"
done
#
# create segments
#
echo ${segments} | jq -c -r .[] | while read item
do
  #
  # retrieve transport_zone_path
  #
  file_json_output="/tmp/tz.json"
  json_key="tz_path"
  /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/sites/default/enforcement-points/default/transport-zones" \
              "$(echo ${item} | jq -c -r '.transport_zone')" \
              "${file_json_output}" \
              "${json_key}"

  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/segments/$(echo ${item} | jq -c -r '.display_name')" \
              "PUT" \
              "{\"display_name\": \"$(echo ${item} | jq -c -r '.display_name')\",
                \"description\": \"$(echo ${item} | jq -c -r '.description')\",
                \"vlan_ids\": $(echo ${item} | jq -c -r '.vlan_ids'),
                \"transport_zone_path\": \"$(jq -c -r '.'${json_key}'' ${file_json_output})\"
              }"
done
#
# create transport node profiles
#
echo ${transport_node_profiles} | jq -c -r .[] | while read item
do
  host_switch_spec=$(echo ${item} | jq -c -r '.host_switch_spec')
  #
  # retrieve vds switch id
  #
  nsx_vds_name=$(echo ${host_switch_spec} | jq -c -r '.host_switches[0].host_switch_vds_name_ref')
  nsx_vds_uuid=$(jq -c -r '.[] | select( .name == "uuid").val' /home/ubuntu/vcenter/${nsx_vds_name}.json)
  host_switch_spec=$(echo ${host_switch_spec} | jq -c -r '.host_switches[0] += {"host_switch_id": "'"${nsx_vds_uuid}"'"}')
  host_switch_spec=$(echo ${host_switch_spec} | jq -c -r '. | del(.host_switches[0].host_switch_vds_name_ref)')  #
  #
  # retrieve transport zone id path
  #
  file_json_output="/home/ubuntu/nsx/tz-nsx-id.json"
  json_key="tz_id"
  /bin/bash /home/ubuntu/nsx/retrieve_object_id.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/sites/default/enforcement-points/default/transport-zones" \
              "$(echo ${host_switch_spec} | jq -c -r '.host_switches[0].transport_zone_endpoints[0].transport_zone_ref')" \
              "${file_json_output}" \
              "${json_key}"
  transport_zone_id="/infra/sites/default/enforcement-points/default/transport-zones/$(jq -c -r .${json_key} ${file_json_output})"
  host_switch_spec=$(echo ${host_switch_spec} | jq -c -r '.host_switches[0].transport_zone_endpoints[0] += {"transport_zone_id": "'${transport_zone_id}'"}')
  host_switch_spec=$(echo ${host_switch_spec} | jq -c -r '. | del(.host_switches[0].transport_zone_endpoints[0].transport_zone_ref)')
  #
  # create transport node profiles
  #
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/host-transport-node-profiles/$(echo ${item} | jq -c -r '.display_name')" \
              "PUT" \
              "{\"display_name\": \"$(echo ${item} | jq -c -r '.display_name')\",
                \"description\": \"$(echo ${item} | jq -c -r '.description')\",
                \"resource_type\": \"$(echo ${item} | jq -c -r '.resource_type')\",
                \"host_switch_spec\": $(echo ${host_switch_spec} | jq -c -r '.')
              }"
done
#
# create dhcp servers
#
echo ${dhcp_servers} | jq -c -r .[] | while read item
do
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/dhcp-server-configs/$(echo ${item} | jq -c -r '.display_name')" \
              "PUT" \
              "${item}"
done
#
# create groups
#
echo ${nsx_groups} | jq -c -r .[] | while read item
do
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/domains/default/groups/$(echo ${item} | jq -c -r '.display_name')" \
              "PUT" \
              "${item}"
done
#
# Updating exclusion list
#
new_members="{\"members\": ${exclusion_list_groups}}"
/bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "policy/api/v1/infra/settings/firewall/security/exclude-list" \
            "PATCH" \
            "${new_members}"
#
# Get compute_collection_external_id
#
file_json_output="/home/ubuntu/nsx/compute_collections.json"
/bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "api/v1/fabric/compute-collections" \
            "${file_json_output}"
compute_collection_external_id=$(jq -c -r --arg arg1 "${cluster_basename}1" '.results[] | select(.display_name == $arg1).external_id' ${file_json_output})
#
# Get transport_node_profile_id
#
file_json_output="/home/ubuntu/nsx/host-transport-node-profiles.json"
/bin/bash /home/ubuntu/nsx/get_object.sh \
            "${ip_nsx}" \
            "${GENERIC_PASSWORD}" \
            "api/v1/infra/host-transport-node-profiles" \
            "${file_json_output}"
transport_node_profile_id=$(jq -c -r --arg arg1 "$(echo ${transport_node_profiles} | jq -c -r '.[0].display_name')" '.results[] | select(.display_name == $arg1).unique_id' ${file_json_output})
#
# Create host transport node
#
new_members="{\"members\": ${exclusion_list_groups}}"
/bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "api/v1/transport-node-collections" \
            "POST" \
            "{\"resource_type\": \"TransportNodeCollection\",
              \"display_name\": \"TransportNodeCollection-1\",
              \"compute_collection_id\": \"${compute_collection_external_id}\",
              \"transport_node_profile_id\": \"${transport_node_profile_id}\"
            }"
#
# waiting for host transport node to be ready
#
sleep 240
file_json_output="/home/ubuntu/nsx/host-transport-nodes-status.json"
/bin/bash /home/ubuntu/nsx/get_object.sh \
            "${ip_nsx}" \
            "${GENERIC_PASSWORD}" \
            "api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes" \
            "${file_json_output}"
retry=60 ; pause=30 ; attempt=0
jq -c -r .results[] ${file_json_output} | while read item
do
  echo "Waiting for host transport nodes to be ready, attempt: ${retry}"
  unique_id=$(echo $item | jq -c -r .unique_id)
  while true ; do
    file_json_output="/home/ubuntu/nsx/host-transport-nodes-status-${unique_id}.json"
    /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/${unique_id}/state" \
                "${file_json_output}"


    hosts_host_transport_node_state=$(echo $response_body)
    if [[ "$(jq -r .deployment_progress_state.progress ${file_json_output})" == 100 ]] && [[ "$(jq -r .state ${file_json_output})" == "success"  ]] ; then
      echo "  SUCCESS: Host transport node id ${unique_id} progress at 100% and host transport node state success"
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Host transport node id '${unique_id}' ready"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
      break
    else
      echo "  Waiting for host transport node id ${unique_id} to be ready, attempt: ${attempt} on ${retry}"
    fi
    if [ ${attempt} -eq ${retry} ]; then
      echo "  FAILED to get transport node deployment progress at 100% after ${attempt}"
      exit
    fi
    sleep $pause
    ((attempt++))
  done
done
#
# Get compute manager id
#
file_json_output="/home/ubuntu/nsx/compute_managers.json"
/bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
            "api/v1/fabric/compute-managers" \
            "${file_json_output}"
vc_id=$(jq -c -r --arg arg1 "${api_host}" '.results[] | select(.display_name == $arg1).id' ${file_json_output})
#
# vCenter API session creation to retrieve various things
#
token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "${vsphere_nested_username}" "${ssoDomain}" "${vsphere_nested_password}" "${api_host}")
vcenter_api 2 2 "GET" ${token} '' "${api_host}" "api/vcenter/datastore"
storage_id=$(echo ${response_body} | jq -r .[0].datastore)
vcenter_api 2 2 "GET" ${token} "" ${api_host} "api/vcenter/network"
management_network_id=$(echo ${response_body} | jq -c -r --arg arg1 "${nsx_port_group_mgmt}" '.[] | select(.name == $arg1).network')
data_network_ids="[]"
data_network_ids=$(echo ${data_network_ids} | jq '. += ["'$(echo ${response_body} | jq -c -r --arg arg1 "${nsx_port_group_overlay_edge}" '.[] | select(.name == $arg1).network')'"]')
data_network_ids=$(echo ${data_network_ids} | jq '. += ["'$(echo ${response_body} | jq -c -r --arg arg1 "${nsx_port_group_external}" '.[] | select(.name == $arg1).network')'"]')
vcenter_api 2 2 "GET" ${token} "" ${api_host} "api/vcenter/cluster"
cluster=$(echo ${response_body} | jq -c -r --arg arg1 "${cluster_basename}1" '.[] | select(.name == $arg1).cluster')
vcenter_api 2 2 "GET" ${token} "" ${api_host} "api/vcenter/cluster/${cluster}"
compute_id=$(echo ${response_body} | jq -c -r '.resource_pool')
#
#
#
edge_ids="[]"
for edge_index in $(seq 1 $(echo ${ips_edge_mgmt} | jq -r '. | length'))
do
  edge_name="${basename_edge}${edge_index}"
  edge_fqdn="${basename_edge}${edge_index}.${domain}"
  ip_edge="${cidr_mgmt_three_octets}.$(echo ${ips_edge_mgmt} | jq -r .[$(expr ${edge_index} - 1)])"
  host_switch_count=0
  json_data='{"host_switch_spec": {"host_switches": [], "resource_type": "StandardHostSwitchSpec"}}'
  echo ${json_data} | jq . | tee /tmp/tmp.json
  echo ${edge_host_switches} | jq -c -r .[] | while read item
  do
    json_data=$(jq -r -c '.host_switch_spec.host_switches |= .+ ['${item}']' /tmp/tmp.json)
    json_data=$(echo ${json_data} | jq '.host_switch_spec.host_switches['${host_switch_count}'] += {"host_switch_profile_ids": []}')
    json_data=$(echo ${json_data} | jq '.host_switch_spec.host_switches['${host_switch_count}'] += {"transport_zone_endpoints": []}')
    echo ${json_data} | jq . | tee /tmp/tmp.json
    echo ${item} | jq -c -r .host_switch_profile_names[] | while read host_switch_profile_name
    do
      file_json_output="/home/ubuntu/nsx/host-switch-profiles"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "api/v1/host-switch-profiles" \
                  "${file_json_output}"
      host_switch_profile_id=$(jq -c -r --arg arg1 "${host_switch_profile_name}" '.results[] | select(.display_name == $arg1).id' ${file_json_output})
      json_data=$(jq '.host_switch_spec.host_switches['${host_switch_count}'].host_switch_profile_ids += [{"key": "UplinkHostSwitchProfile", "value": "'${host_switch_profile_id}'"}]' /tmp/tmp.json)
      echo ${json_data} | jq . | tee /tmp/tmp.json
    done
    echo ${item} | jq -c -r .transport_zone_names[] | while read tz
    do
      file_json_output="/home/ubuntu/nsx/tzs.json"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "api/v1/transport-zones" \
                  "${file_json_output}"
      transport_zone_id=$(jq -c -r --arg arg1 "${tz}" '.results[] | select(.display_name == $arg1).id' ${file_json_output})
      json_data=$(jq '.host_switch_spec.host_switches['${host_switch_count}'].transport_zone_endpoints += [{"transport_zone_id": "'${transport_zone_id}'"}]' /tmp/tmp.json)
      echo ${json_data} | jq . | tee /tmp/tmp.json
    done
    if $(echo ${item} | jq -e '. | has("ip_pool_name")') ; then
      file_json_output="/home/ubuntu/nsx/ip-pools.json"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "api/v1/infra/ip-pools" \
                  "${file_json_output}"
      ip_pool_id=$(jq -c -r --arg arg1 "$(echo ${json_data} | jq -r '.host_switch_spec.host_switches['${host_switch_count}'].ip_pool_name')" '.results[] | select(.display_name == $arg1).realization_id' ${file_json_output})
      json_data=$(jq '.host_switch_spec.host_switches['${host_switch_count}'] += {"ip_assignment_spec": {"ip_pool_id": "'${ip_pool_id}'", "resource_type": "StaticIpPoolSpec"}}' /tmp/tmp.json)
      json_data=$(echo ${json_data} | jq 'del (.host_switch_spec.host_switches['${host_switch_count}'].ip_pool_name)')
      echo ${json_data} | jq . | tee /tmp/tmp.json
    fi
    json_data=$(jq 'del (.host_switch_spec.host_switches['${host_switch_count}'].host_switch_profile_names)' /tmp/tmp.json)
    json_data=$(echo ${json_data} | jq 'del (.host_switch_spec.host_switches['${host_switch_count}'].transport_zone_names)')
    echo ${json_data} | jq . | tee /tmp/tmp.json
    host_switch_count=$((host_switch_count+1))
  done
  json_data=$(jq '. +=  {"maintenance_mode": "DISABLED"}' /tmp/tmp.json)
  json_data=$(echo ${json_data} | jq '. +=  {"display_name":"'${edge_name}'"}')
  json_data=$(echo ${json_data} | jq '. +=  {"node_deployment_info": {
                                               "resource_type":"EdgeNode",
                                               "deployment_type": "VIRTUAL_MACHINE",
                                               "deployment_config": {
                                                 "vm_deployment_config": {
                                                   "vc_id": "'${vc_id}'",
                                                   "compute_id": "'${compute_id}'",
                                                   "storage_id": "'${storage_id}'",
                                                   "management_network_id": "'${management_network_id}'",
                                                   "management_port_subnets": [
                                                     {
                                                       "ip_addresses": ["'${ip_edge}'"],
                                                       "prefix_length": '${cidr_mgmt_prefix_length}'
                                                      }
                                                   ],
                                                   "default_gateway_addresses": ["'${ip_gw_mgmt}'"],
                                                   "data_network_ids": '$(echo ${data_network_ids} | jq -r -c .)',
                                                   "reservation_info": {
                                                     "memory_reservation" : {"reservation_percentage": 100 },
                                                     "cpu_reservation": {
                                                       "reservation_in_shares": "HIGH_PRIORITY",
                                                       "reservation_in_mhz": 0
                                                     }
                                                   },
                                                   "resource_allocation": {
                                                     "cpu_count": '${edge_cpu}',
                                                     "memory_allocation_in_mb": '${edge_memory}'
                                                   },
                                                   "placement_type": "VsphereDeploymentConfig"
                                                 },
                                                 "form_factor": "MEDIUM",
                                                 "node_user_settings": {
                                                   "cli_username": "admin",
                                                   "root_password": "'${GENERIC_PASSWORD}'",
                                                   "cli_password": "'${GENERIC_PASSWORD}'"
                                                 }
                                               },
                                               "node_settings": {
                                                 "hostname": "'${edge_fqdn}'",
                                                 "allow_ssh_root_login": true
                                               }}}')
  /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "api/v1/transport-nodes" \
              "POST" \
              $(echo ${json_data} | jq -c -r .)
  edge_ids=$(echo ${edge_ids} | jq '. += ["'$(jq -r .id /home/ubuntu/nsx/response_body.json)'"]')
done
#
# Check the status of Nodes (including transport node and edge nodes but filtered with edge_ids
#
retry=240 ; pause=20 ; attempt=0
echo ${edge_ids} | jq -c -r .[] | while read item
do
  while true ; do
    echo "attempt ${attempt} to get node id ${item} ready"
    file_json_output="/home/ubuntu/nsx/transport-nodes-state.json"
    /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/transport-nodes/state" \
                "${file_json_output}"
    jq -c -r .results[] ${file_json_output} | while read edge
    do
      if [[ $(echo ${edge} | jq -r .transport_node_id) == ${item} ]] && [[ $(echo ${edge} | jq -r .state) == "success" ]] ; then
        echo "new edge node id ${item} state is success after ${attempt} attempts of ${pause} seconds"
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': edge node '${item}' ready"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      fi
    done
    ((attempt++))
    if [ ${attempt} -eq ${retry} ]; then
      echo "Unable to get node id ${item} ready after ${attempt} of ${pause} seconds"
      exit 1
    fi
    sleep ${pause}
  done
done
#
# edge cluster creation
#
echo ${edge_clusters} | jq -c -r .[] | while read item
do
  echo ${item} | jq -c -r .members[] | while read display_name
  do
    file_json_output="/home/ubuntu/nsx/transport-nodes.json"
    /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "api/v1/transport-nodes" \
                "${file_json_output}"
    transport_node_id=$(jq -c -r --arg arg1 "${display_name}" '.results[] | select(.display_name == $arg1).id' ${file_json_output})
  done
done
#
#
#
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX manager configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
