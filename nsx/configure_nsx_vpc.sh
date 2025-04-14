#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# vpc use case for vsphere 9 only
#
if [[ ${kind} == "vsphere-nsx-vpc-avi" && $(jq -c -r '.about.version' ${vcsa_about_json_file} | cut -d"." -f1) == "9" ]]; then
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
      exit 255
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
      exit 255
    fi
  done
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': starting NSX VPC config."}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  echo "#"
  echo "# VPC use case for vsphere 9 only"
  echo "#"
  #
  # ip block creation only for project default
  #
  echo ${nsx_ip_blocks} | jq -c -r .[] | while read item
  do
    if [[ $(echo ${item} | jq -r -c .project_ref) == "default" || $(echo ${item} | jq -r -c .project_ref) == "null" ]]; then
      echo "creation of ip-block '$(echo ${item} | jq -c -r .name)'"
      json_data='
        {
          "display_name": "'$(echo ${item} | jq -c -r .name)'",
          "cidr": "'$(echo ${item} | jq -c -r .cidr)'",
          "visibility": "'$(echo ${item} | jq -c -r .visibility)'"
        }'
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/ip-blocks/$(echo ${item} | jq -c -r .name)" \
              "PATCH" \
              "${json_data}"
    fi
  done
  echo "#"
  #
  # create gw_connections
  #
  echo ${nsx_gw_connections} | jq -c -r .[] | while read item
  do
    echo "creation of gateway-connection '$(echo ${item} | jq -c -r .name)'"
    # retrieve tier0_path
    file_json_output="/tmp/vpc_t0_path.json"
    json_key="t0_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/tier-0s" \
                "$(echo ${item} | jq -c -r '.tier0_ref')" \
                "${file_json_output}" \
                "${json_key}"
    tier0_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    # create gateway-connections
    json_data='
        {
          "tier0_path": "'${tier0_path}'",
          "display_name": "'$(echo ${item} | jq -c -r .name)'"
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/infra/gateway-connections/$(echo ${item} | jq -c -r .name)" \
          "PUT" \
          "${json_data}"
  done
  echo "#"
  #
  # Project creation
  #
  echo ${nsx_projects} | jq -c -r .[] | while read item
  do
    echo "creation of project '$(echo ${item} | jq -c -r .name)'"
    # retrieve external ip_block_external_path
    file_json_output="/tmp/vpc_ip_block.json"
    json_key="ip_block_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/ip-blocks" \
                "$(echo ${item} | jq -c -r '.ip_block_ref')" \
                "${file_json_output}" \
                "${json_key}"
    ip_block_external_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    # retrieve tier0_path
    file_json_output="/tmp/vpc_t0_path.json"
    json_key="t0_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/tier-0s" \
                "$(echo ${item} | jq -c -r '.tier0_ref')" \
                "${file_json_output}" \
                "${json_key}"
    tier0_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    # retrieve edge_cluster_path
    file_json_output="/home/ubuntu/nsx/vpc_edge_cluster_path.json"
    json_key="edge_cluster_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_id.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "api/v1/edge-clusters" \
                "$(echo ${item} | jq -c -r '.edge_cluster_ref')" \
                "${file_json_output}" \
                "${json_key}"
    edge_cluster_path="/infra/sites/default/enforcement-points/default/edge-clusters/$(jq -c -r .${json_key} ${file_json_output})"
    # retrieve tgw_external_connections
    gw_connections_refs="[]"
    for index_gw_connections_ref in $(seq 0 $(($(echo ${item} | jq '.gw_connections_refs | length') - 1)))
    do
      # retrieve gw_connection_path
      file_json_output="/tmp/gw_connection_path.json"
      json_key="gw_connection_path"
      /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/gateway-connections" \
                  "$(echo ${item} | jq -c -r .gw_connections_refs[${index_gw_connections_ref}])" \
                  "${file_json_output}" \
                  "${json_key}"
      gw_connection_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
      gw_connections_refs=$(echo ${gw_connections_refs} | jq -c -r '. += ["'${gw_connection_path}'"]')
    done
    # create project
    json_data='
        {
          "site_infos": [
            {
              "edge_cluster_paths": [
                "'${edge_cluster_path}'"
              ],
              "site_path": "/infra/sites/default"
            }
          ],
          "tier_0s": [
            "'${tier0_path}'"
          ],
          "tgw_external_connections": '${gw_connections_refs}',
          "external_ipv4_blocks" : [
            "'${ip_block_external_path}'"
          ],
          "activate_default_dfw_rules": false,
          "display_name": "'$(echo ${item} | jq -c -r .name)'"
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .name)" \
          "PATCH" \
          "${json_data}"
  done
  echo "#"
  #
  # associate gw_connections to Default Transit Gateway
  #
  echo ${nsx_transit_gateways} | jq -c -r .[] | while read item
  do
    echo "associate gw-connection $(echo ${item} | jq -c -r .gw_connection_ref) with transit-gateways $(echo ${item} | jq -c -r .name) for project $(echo ${item} | jq -c -r .project_ref)"
    # retrieve gw_connection_path
    file_json_output="/tmp/gw_connection_path.json"
    json_key="gw_connection_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/gateway-connections" \
                "$(echo ${item} | jq -c -r .gw_connection_ref)" \
                "${file_json_output}" \
                "${json_key}"
    gw_connection_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    json_data='
        {
          "connection_path": "'${gw_connection_path}'",
          "display_name": "'$(echo ${item} | jq -c -r .gw_connection_ref)'"
        }'

    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/transit-gateways/$(echo ${item} | jq -c -r .name)/attachments/$(echo ${item} | jq -c -r .gw_connection_ref)" \
          "PATCH" \
          "${json_data}"
  done
  echo "#"
  #
  # ip block creation only for project != default && .scope != "vpc" (only the inter vpc tgw cidr will be created as ip block under each project)
  #
  echo ${nsx_ip_blocks} | jq -c -r .[] | while read item
  do
    if [[ $(echo ${item} | jq -r -c .project_ref) != "default" && $(echo ${item} | jq -r -c .project_ref) != "null" && $(echo ${item} | jq -r -c .scope) == "vpc_tgw" ]]; then
      echo "creation of ip-block '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
      # retrieve project id
      file_json_output="/tmp/vpc_project.json"
      json_key="project_id"
      /bin/bash /home/ubuntu/nsx/retrieve_object_id.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/orgs/default/projects" \
                  "$(echo ${item} | jq -c -r '.project_ref')" \
                  "${file_json_output}" \
                  "${json_key}"
      project_id=$(jq -c -r '.'${json_key}'' ${file_json_output})
      # ip block creation
      json_data='
        {
          "display_name": "'$(echo ${item} | jq -c -r .name)'",
          "cidr": "'$(echo ${item} | jq -c -r .cidr)'",
          "visibility": "'$(echo ${item} | jq -c -r .visibility)'"
        }'
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/orgs/default/projects/${project_id}/infra/ip-blocks/$(echo ${item} | jq -c -r .name)" \
              "PATCH" \
              "${json_data}"
    fi
  done
  echo "#"
  #
  # vpc_connectivity_profiles creation
  #
  echo ${nsx_vpc_connectivity_profiles} | jq -c -r .[] | while read item
  do
    echo "creation of vpc-connectivity-profile '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    # retrieve external_ip_block_refs_paths
    external_ip_block_refs_paths="[]"
    for index_external_ip_block in $(seq 0 $(($(echo ${item} | jq '.external_ip_block_refs | length') - 1)))
    do
      # retrieve external_ip_block_path
      file_json_output="/tmp/external_ip_block_path.json"
      json_key="external_ip_block_path"
      /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/ip-blocks" \
                  "$(echo ${item} | jq -c -r .external_ip_block_refs[${index_external_ip_block}])" \
                  "${file_json_output}" \
                  "${json_key}"
      external_ip_block_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
      external_ip_block_refs_paths=$(echo ${external_ip_block_refs_paths} | jq -c -r '. += ["'${external_ip_block_path}'"]')
    done
    # retrieve edge_cluster_refs_path
    edge_cluster_refs_path="[]"
    for index_edge_cluster_refs in $(seq 0 $(($(echo ${item} | jq '.edge_cluster_refs | length') - 1)))
    do
      # retrieve edge_cluster_path
      file_json_output="/tmp/edge_cluster_path.json"
      json_key="edge_cluster_path"
      /bin/bash /home/ubuntu/nsx/retrieve_object_id.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "api/v1/edge-clusters" \
                  "$(echo ${item} | jq -c -r .edge_cluster_refs[${index_edge_cluster_refs}])" \
                  "${file_json_output}" \
                  "${json_key}"
      edge_cluster_path="/infra/sites/default/enforcement-points/default/edge-clusters/$(jq -c -r .${json_key} ${file_json_output})"
      edge_cluster_refs_path=$(echo ${edge_cluster_refs_path} | jq -c -r '. += ["'${edge_cluster_path}'"]')
    done
    # retrieve private_tgw_ip_block_refs_path
    private_tgw_ip_block_refs_path="[]"
    for index_private_tgw_ip_block_refs in $(seq 0 $(($(echo ${item} | jq '.private_tgw_ip_block_refs | length') - 1)))
    do
      # retrieve private_tgw_ip_block_path
      file_json_output="/tmp/private_tgw_ip_block_path.json"
      json_key="private_tgw_ip_block_path"
      if [[ $(echo ${item} | jq -c -r .project_ref) == "default" ]]; then
        api_endpoint="policy/api/v1/infra/ip-blocks"
      else
        api_endpoint="policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/infra/ip-blocks"
      fi
      /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "${api_endpoint}" \
                  "$(echo ${item} | jq -c -r .private_tgw_ip_block_refs[${index_private_tgw_ip_block_refs}])" \
                  "${file_json_output}" \
                  "${json_key}"
      private_tgw_ip_block_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
      private_tgw_ip_block_refs_path=$(echo ${private_tgw_ip_block_refs_path} | jq -c -r '. += ["'${private_tgw_ip_block_path}'"]')
    done
    # create vpc_connectivity_profiles
    json_data='
        {
          "transit_gateway_path": "/orgs/default/projects/'$(echo ${item} | jq -c -r .project_ref)'/transit-gateways/default",
          "external_ip_blocks": '${external_ip_block_refs_paths}',
          "is_default": true,
          "private_tgw_ip_blocks": '${private_tgw_ip_block_refs_path}',
            "service_gateway": {
              "enable": true,
              "nat_config": {
                "enable_default_snat": true
              },
              "edge_cluster_paths": '${edge_cluster_refs_path}'
            },
          "display_name": "'$(echo ${item} | jq -c -r .name)'"
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-connectivity-profiles/$(echo ${item} | jq -c -r .name)" \
          "PUT" \
          "${json_data}"
  done
  echo "#"
  #
  # vpc_service_profiles creation
  #
  echo ${nsx_vpc_service_profiles} | jq -c -r .[] | while read item
  do
    echo "creation of vpc-service-profile '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    json_data='
        {
          "display_name": "'$(echo ${item} | jq -c -r .name)'",
          "is_default": true,
          "dhcp_config": {
            "dhcp_server_config": {
              "dns_client_config": {
                "dns_server_ips": [
                  "'${ip_gw}'"
                ]
              },
              "lease_time": 86400,
              "ntp_servers": [
                "'${ip_gw}'"
              ],
              "advanced_config": {
                "is_distributed_dhcp": true
              }
            }
          }
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-service-profiles/$(echo ${item} | jq -c -r .name)" \
          "PUT" \
          "${json_data}"
  done
  echo "#"
  #
  # vpc creation
  #
  echo ${nsx_vpcs} | jq -c -r .[] | while read item
  do
    echo "creation of vpc '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    private_ips="[]"
    for index_private_ips_refs in $(seq 0 $(($(echo ${item} | jq '.private_ips_refs | length') - 1)))
    do
      # retrieve cidr
      cidr=$(echo ${nsx_ip_blocks} | jq -c -r --arg arg $(echo ${item} | jq -c -r '.private_ips_refs['${index_private_ips_refs}']') '.[] | select( .name == $arg).cidr')
      private_ips=$(echo ${private_ips} | jq -c -r '. += ["'${cidr}'"]')
    done
    # retrieve vpc_service_profile_path
    file_json_output="/tmp/vpc_service_profile_path.json"
    json_key="vpc_service_profile"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-service-profiles" \
                "$(echo ${item} | jq -c -r .vpc_service_profile_ref)" \
                "${file_json_output}" \
                "${json_key}"
    vpc_service_profile_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    json_data='
        {
          "vpc_service_profile": "'${vpc_service_profile_path}'",
          "load_balancer_vpc_endpoint": {
            "enabled": true
          },
          "private_ips": '${private_ips}',
          "display_name": "'$(echo ${item} | jq -c -r .name)'"
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpcs/$(echo ${item} | jq -c -r .name)" \
          "PUT" \
          "${json_data}"
    # retrieve vpc_connectivity_profile_path
    file_json_output="/tmp/vpc_connectivity_profile_path.json"
    json_key="vpc_connectivity_profile_path"
    /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-connectivity-profiles" \
                "$(echo ${item} | jq -c -r .connectivity_profile_ref)" \
                "${file_json_output}" \
                "${json_key}"
    vpc_connectivity_profile_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
    # vpc attachment
    json_data='
        {
          "vpc_connectivity_profile": "'${vpc_connectivity_profile_path}'"
        }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpcs/$(echo ${item} | jq -c -r .name)/attachments/$(echo ${item} | jq -c -r .connectivity_profile_ref)" \
          "PUT" \
          "${json_data}"
  done
  echo "#"
  #
  #
  #
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': NSX VPC configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
fi