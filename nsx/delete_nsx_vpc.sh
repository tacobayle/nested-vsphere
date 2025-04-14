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
  # vpc deletion
  #
  echo ${nsx_vpcs} | jq -c -r .[] | while read item
  do
    echo "deletion of vpc '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpcs/$(echo ${item} | jq -c -r .name)/attachments/$(echo ${item} | jq -c -r .connectivity_profile_ref)" \
          "DELETE" \
          ""
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpcs/$(echo ${item} | jq -c -r .name)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # vpc_connectivity_profiles deletion
  #
  echo ${nsx_vpc_connectivity_profiles} | jq -c -r .[] | while read item
  do
    echo "deletion of vpc-connectivity-profile '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-connectivity-profiles/$(echo ${item} | jq -c -r .name)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # ip block deletion only for project != default && .scope == "vpc_tgw" (only the inter vpc tgw cidr will be created as ip block under each project)
  #
  echo ${nsx_ip_blocks} | jq -c -r .[] | while read item
  do
    if [[ $(echo ${item} | jq -r -c .project_ref) != "default" && $(echo ${item} | jq -r -c .project_ref) != "null" && $(echo ${item} | jq -r -c .scope) == "vpc_tgw" ]]; then
      echo "deletion of ip-block '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
      if [[ $(echo ${item} | jq -c -r .project_ref) == "default" ]]; then
        api_endpoint="policy/api/v1/infra/ip-blocks"
      else
        api_endpoint="policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/infra/ip-blocks/$(echo ${item} | jq -c -r .name)"
      fi
      /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "${api_endpoint}" \
              "DELETE" \
              ""
    fi
  done
  echo "#"
  #
  # delete association gw_connections to Default Transit Gateway
  #
  echo ${nsx_transit_gateways} | jq -c -r .[] | while read item
  do
    echo "delete association gw-connection $(echo ${item} | jq -c -r .gw_connection_ref) with transit-gateways $(echo ${item} | jq -c -r .name) for project $(echo ${item} | jq -c -r .project_ref)"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/transit-gateways/$(echo ${item} | jq -c -r .name)/attachments/$(echo ${item} | jq -c -r .gw_connection_ref)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # vpc_service_profiles deletion
  #
  echo ${nsx_vpc_service_profiles} | jq -c -r .[] | while read item
  do
    echo "deletion of vpc-service-profile '$(echo ${item} | jq -c -r .name)' for project $(echo ${item} | jq -c -r .project_ref)"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .project_ref)/vpc-service-profiles/$(echo ${item} | jq -c -r .name)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # Project deletion
  #
  echo ${nsx_projects} | jq -c -r .[] | while read item
  do
    echo "deletion of project '$(echo ${item} | jq -c -r .name)'"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/orgs/default/projects/$(echo ${item} | jq -c -r .name)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # deletion gw_connections
  #
  echo ${nsx_gw_connections} | jq -c -r .[] | while read item
  do
    echo "deletion of gateway-connection '$(echo ${item} | jq -c -r .name)'"
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
          "policy/api/v1/infra/gateway-connections/$(echo ${item} | jq -c -r .name)" \
          "DELETE" \
          ""
  done
  echo "#"
  #
  # ip block deletion only for project default
  #
  echo ${nsx_ip_blocks} | jq -c -r .[] | while read item
  do
    if [[ $(echo ${item} | jq -r -c .project_ref) == "default" || $(echo ${item} | jq -r -c .project_ref) == "null" ]]; then
      echo "deletion of ip-block '$(echo ${item} | jq -c -r .name)'"
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/ip-blocks/$(echo ${item} | jq -c -r .name)" \
              "DELETE" \
              ""
    fi
  done
  echo "#"
fi