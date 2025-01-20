#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
output_file="/home/ubuntu/tanzu/output.txt"
#
#
#
if [[ ${configure_supervisor} == "true" ]] ; then
  #
  # registering Avi in the NSX config
  #
  if [[ ${kind} == "vsphere-nsx-avi" ]]; then
    json_data='
    {
      "owned_by": "LCM",
      "cluster_ip": "'${ip_avi}'",
      "infra_admin_username" : "admin",
      "infra_admin_password" : "'${GENERIC_PASSWORD}'"
    }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/alb-onboarding-workflow" \
                "PUT" \
                $(echo ${json_data} | jq -c -r .)
  fi
  #
  # Create Content Library for tanzu
  #
  create_subscribed_content_library_json_output="/home/ubuntu/tanzu/tanzu_content_library.json"
  /bin/bash /home/ubuntu/vcenter/create_subscribed_content_library.sh \
    "${api_host}" \
    "${ssoDomain}" \
    "${GENERIC_PASSWORD}" \
    "$(jq -c -r .tanzu.content_library.subscription_url $jsonFile)" \
    "$(jq -c -r .tanzu.content_library.type $jsonFile)" \
    "$(jq -c -r .tanzu.content_library.automatic_sync_enabled $jsonFile)" \
    "$(jq -c -r .tanzu.content_library.on_demand $jsonFile)" \
    "$(jq -c -r .tanzu.content_library.name $jsonFile)" \
    "vsanDatastore" \
    "${create_subscribed_content_library_json_output}"
  content_library_id=$(jq -c -r .content_library_id ${create_subscribed_content_library_json_output})
  #
  # Retrieve cluster id
  #
  retrieve_cluster_id_json_output="/home/ubuntu/tanzu/vcenter_cluster_id.json"
  /bin/bash /home/ubuntu/vcenter/retrieve_cluster_id.sh \
    "${api_host}" \
    "${ssoDomain}" \
    "${GENERIC_PASSWORD}" \
    "${cluster_basename}1" \
    "${retrieve_cluster_id_json_output}"
  cluster_id=$(jq -c -r .cluster_id ${retrieve_cluster_id_json_output})
  #
  # Retrieve storage policy
  #
  retrieve_storage_policy_id_json_output="/home/ubuntu/tanzu/retrieve_storage_policy_id.json"
  /bin/bash /home/ubuntu/vcenter/retrieve_storage_policy_id.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
    "$(jq -c -r .tanzu.storage_policy_name $jsonFile)" \
    "${retrieve_storage_policy_id_json_output}"
  storage_policy_id=$(jq -c -r .storage_policy_id ${retrieve_storage_policy_id_json_output})
  #
  # Retrieve Network details of tanzu_supervisor_dvportgroup dvportgroup
  #
  retrieve_network_id_json_output="/home/ubuntu/tanzu/retrieve_network_id.json"
  /bin/bash /home/ubuntu/vcenter/retrieve_network_id.sh \
    "${api_host}" \
    "${ssoDomain}" \
    "${GENERIC_PASSWORD}" \
    "${management_tanzu_segment}" \
    "${retrieve_network_id_json_output}"
  tanzu_supervisor_dvportgroup=$(jq -c -r .network_id ${retrieve_network_id_json_output})
  #
  # vsphere-avi use case
  #
  if [[ ${kind} == "vsphere-avi" ]]; then
    #
    # Retrieve Network details of tanzu_worker_dvportgroup dvportgroup
    #
    retrieve_network_id_json_output="/home/ubuntu/tanzu/retrieve_network_id.json"
    /bin/bash /home/ubuntu/vcenter/retrieve_network_id.sh \
      "${api_host}" \
      "${ssoDomain}" \
      "${GENERIC_PASSWORD}" \
      "${worker_network}" \
      "${retrieve_network_id_json_output}"
    tanzu_worker_dvportgroup=$(jq -c -r .network_id ${retrieve_network_id_json_output})
    #
    # Retrieve Avi Cert Details
    #
    echo "   +++ getting NSX ALB certificate..."
    openssl s_client -showcerts -connect ${ip_avi}:443  </dev/null 2>/dev/null|sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > /home/ubuntu/tanzu/avi-ca.cert
    if [ ! -s /home/ubuntu/tanzu/avi-ca.cert ] ; then exit ; fi
    avi_cert=$(jq -sR . /home/ubuntu/tanzu/avi-ca.cert)
    #
    # create supervisor cluster
    #
    /bin/bash /home/ubuntu/vcenter/create_supervisor_cluster_vds.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
      "${ip_gw}" \
      "${storage_policy_id}" \
      "$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f1)" \
      "$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f2)" \
      "${supervisor_cluster_size}" \
      "255.255.255.0" \
      "${supervisor_starting_ip}" \
      "${ip_gw_tanzu}" \
      "${supervisor_count_ip}" \
      "${tanzu_supervisor_dvportgroup}" \
      "${avi_cert}" \
      "${GENERIC_PASSWORD}" \
      "${ip_avi}" \
      "${content_library_id}" \
      "${worker_network}" \
      "${workload_starting_ip}" \
      "${workload_count_ip}" \
      "${ip_gw_backend}" \
      "${tanzu_worker_dvportgroup}" \
      "255.255.255.0" \
      "${cluster_id}"
  fi
  #
  # vsphere-nsx-avi use case
  #
  if [[ ${kind} == "vsphere-nsx-avi" ]]; then
    #
    # retrieve edge cluster id
    #
    file_json_output="/home/ubuntu/tanzu/retrieve_namespace_edge_cluster_id.json"
    /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "api/v1/edge-clusters" \
                "${file_json_output}"
    namespace_edge_cluster_id=$(jq -c -r --arg arg1 "$(echo ${edge_clusters} | jq -r -c .[0].display_name)" '.results[] | select(.display_name == $arg1).id' ${file_json_output})
    #
    # create supervisor cluster
    #
    nsx_vds_uuid=$(jq -c -r '.[] | select( .name == "uuid").val' /home/ubuntu/vcenter/$(jq -c -r .vds_switches[0].name $jsonFile).json)
    /bin/bash /home/ubuntu/vcenter/create_supervisor_cluster_nsx.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
              "${content_library_id}" \
              "${storage_policy_id}" \
              "${ip_gw}" \
              "${supervisor_cluster_size}" \
              "$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f1)" \
              "$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f2)" \
              "255.255.255.0" \
              "${management_tanzu_supervisor_starting_ip}" \
              "$(echo ${management_tanzu_gw} | cut -d"/" -f1 )" \
              "${management_tanzu_supervisor_count}" \
              "${tanzu_supervisor_dvportgroup}" \
              "${nsx_vds_uuid}" \
              "$(echo ${supervisor_cluster_namespace_cidr} | cut -d"/" -f1)" \
              "$(echo ${supervisor_cluster_namespace_cidr} | cut -d"/" -f2)" \
              "${supervisor_cluster_namespace_tier0}" \
              "${namespace_edge_cluster_id}" \
              "${supervisor_cluster_prefix_per_namespace}" \
              "$(echo ${supervisor_cluster_ingress_cidr} | cut -d"/" -f1)" \
              "$(echo ${supervisor_cluster_ingress_cidr} | cut -d"/" -f2)" \
              "${cluster_id}"
  fi
  #
  # Wait for supervisor cluster to be running
  #
  /bin/bash /home/ubuntu/vcenter/wait_for_supervisor_cluster.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}"
  echo "" | tee -a ${output_file} >/dev/null 2>&1
  echo "+++++ vSphere with Tanzu" | tee -a ${output_file} >/dev/null 2>&1
  echo "Authenticate to the supervisor cluster from the external-gateway:" | tee -a ${output_file} >/dev/null 2>&1
  echo "  > /bin/bash /home/ubuntu/tanzu/auth_supervisor.sh" | tee -a ${output_file} >/dev/null 2>&1
  #
  echo "waiting 5 minutes after supervisor cluster creation..."
  sleep 300
  #
  # retrieve K8s Supervisor node IP
  #
  retrieve_api_server_cluster_endpoint_json_output="/home/ubuntu/tanzu/retrieve_api_server_cluster_endpoint.json"
  /bin/bash /home/ubuntu/vcenter/retrieve_api_server_cluster_endpoint.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
            "${retrieve_api_server_cluster_endpoint_json_output}"
  api_server_cluster_endpoint=$(jq -c -r .api_server_cluster_endpoint ${retrieve_api_server_cluster_endpoint_json_output})
  #
  # vsphere plugin install
  #
  sed -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" /home/ubuntu/templates/vsphere_plugin_install.sh.template | tee /home/ubuntu/tanzu/vsphere_plugin_install.sh > /dev/null
  /bin/bash /home/ubuntu/tanzu/vsphere_plugin_install.sh
  #
  # auth supervisor script
  #
  sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
      -e "s/\${sso_domain_name}/${ssoDomain}/" \
      -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" /home/ubuntu/templates/tanzu_auth_supervisor.sh.template | tee /home/ubuntu/tanzu/auth_supervisor.sh > /dev/null
  chmod u+x /home/ubuntu/tanzu/auth_supervisor.sh
fi
#
# Namespace creation
#
if [[ ${configure_supervisor} == "true" && ${configure_namespace} == "true" ]] ; then
  for ns in $(echo ${tanzu_namespaces} | jq -c -r .[])
  do
    if [[ ${kind} == "vsphere-avi" ]]; then
      /bin/bash /home/ubuntu/vcenter/create_namespaces.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                "$(jq -r .tanzu.vm_classes $jsonFile)" \
                "${storage_policy_id}" \
                "$(echo $ns | jq -c -r .name)"
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      if $(echo $ns | jq -e '.tkc' > /dev/null) ; then
        if [[ ${echo $ns | jq -e '.tkc'} == "true" ]]; then
          if $(echo $ns | jq -e '.ingress_cidr' > /dev/null) ; then
            /bin/bash /home/ubuntu/vcenter/create_namespaces_nsx_overwrite_network.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                      "$(jq -r .tanzu.vm_classes $jsonFile)" \
                      "${storage_policy_id}" \
                      "$(echo $ns | jq -c -r .name)" \
                      "$(echo $ns | jq -c -r .ingress_cidr | cut -d"/" -f1)" \
                      "$(echo $ns | jq -c -r .ingress_cidr | cut -d"/" -f2)" \
                      "$(echo $ns | jq -c -r .namespace_cidr | cut -d"/" -f1)" \
                      "$(echo $ns | jq -c -r .namespace_cidr | cut -d"/" -f2)" \
                      "$(echo $ns | jq -c -r .namespace_tier0)" \
                      "$(echo $ns | jq -c -r .prefix_per_namespace)"
          else
            /bin/bash /home/ubuntu/vcenter/create_namespaces.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                      "$(jq -r .tanzu.vm_classes $jsonFile)" \
                      "${storage_policy_id}" \
                      "$(echo $ns | jq -c -r .name)"
          fi
        fi
      fi
      if $(echo $ns | jq -e '.vm' > /dev/null) ; then
        if [[ ${echo $ns | jq -e '.vm'} == "true" ]]; then
          retrieve_cl_uuid_json_output="/home/ubuntu/tanzu/retrieve_cl_uuid.json"
          retrieve_cl_uuid_json_key="cl_uuid"
          /bin/bash /home/ubuntu/vcenter/retrieve_cl_uuid_from_name.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                    "$(echo $ns | jq -c -r .content_library_name)" \
                    "${retrieve_cl_uuid_json_output}" \
                    "${retrieve_cl_uuid_json_key}"
          cl_uuid=$(jq -c -r .${retrieve_cl_uuid_json_key} ${retrieve_cl_uuid_json_output})
          /bin/bash /home/ubuntu/vcenter/create_namespaces_vm.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                    "$(jq -r .tanzu.vm_classes $jsonFile)" \
                    "${storage_policy_id}" \
                    "$(echo $ns | jq -c -r .name)" \
                    "${cl_uuid}"
        fi
      fi
    fi
  done
  #
  # tkc creation
  #
  echo "waiting 1 minute before tkc/ako templating/creation"
  sleep 60
  cluster_count=1
  for cluster in $(echo ${tkc_clusters} | jq -c -r .[])
  do
    namespace=$(echo ${cluster} | jq -c -r .namespace_ref)
    tkc_name=$(echo ${cluster} | jq -c -r .name)
    # yaml antrea config map templating
    sed -e "s/\${name}/${tkc_name}/" \
        -e "s/\${namespace_ref}/${namespace}/" /home/ubuntu/templates/tkc_antrea.yml.template | tee /home/ubuntu/tkc/${tkc_name}-antrea-package.yml > /dev/null
    sudo cp /home/ubuntu/tkc/${tkc_name}-antrea-package.yml /var/www/html/
    # yaml cluster templating
    sed -e "s/\${name}/${tkc_name}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s@\${services_cidrs}@"$(echo ${cluster} | jq -c -r .services_cidrs)"@" \
        -e "s@\${pods_cidrs}@$(echo ${cluster} | jq -c -r .pods_cidrs)@" \
        -e "s/\${serviceDomain}/${domain}/" \
        -e "s/\${k8s_version}/$(echo ${cluster} | jq -c -r .k8s_version)/" \
        -e "s/\${control_plane_count}/$(echo ${cluster} | jq -c -r .control_plane_count)/" \
        -e "s/\${cluster_count}/${cluster_count}/" \
        -e "s/\${workers_count}/$(echo ${cluster} | jq -c -r .workers_count)/" \
        -e "s/\${vm_class}/$(echo ${cluster} | jq -c -r .vm_class)/" /home/ubuntu/templates/tkc.yml.template | tee /home/ubuntu/tkc/${tkc_name}.yml > /dev/null
    sudo cp /home/ubuntu/tkc/${tkc_name}.yml /var/www/html/
    # bash cluster create templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s@\${yaml_antrea_path}@/home/ubuntu/tkc/${tkc_name}-antrea-package.yml@" \
        -e "s@\${yaml_path}@/home/ubuntu/tkc/${tkc_name}.yml@" \
        -e "s/\${cluster_name}/${tkc_name}/" /home/ubuntu/templates/tkc_wo_antrea_wo_clusterbootstrap.sh.template | tee /home/ubuntu/tkc/${tkc_name}_create.sh > /dev/null
    chmod u+x /home/ubuntu/tkc/${tkc_name}_create.sh
    # bash cluster delete templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/tkc_destroy.sh.template | tee /home/ubuntu/tkc/${tkc_name}_destroy.sh > /dev/null
    chmod u+x /home/ubuntu/tkc/${tkc_name}_destroy.sh
    # bash auth tkc templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/tanzu_auth_tkc.sh.template | tee /home/ubuntu/tkc/auth_${tkc_name}.sh > /dev/null
    chmod u+x /home/ubuntu/tkc/auth_${tkc_name}.sh
    # bash create tkc exec
    if [[ ${configure_workload} == "true" ]] ; then
      /bin/bash /home/ubuntu/tkc/${tkc_name}_create.sh
    fi
    # ako values templating
    serviceEngineGroupName="Default-Group"
    shardVSSize="SMALL"
    serviceType="NodePortLocal" # needs to be configured before cluster creation
    cniPlugin="antrea"
    disableStaticRouteSync="true" # needs to be true if NodePortLocal is enabled
    if [[ ${kind} == "vsphere-avi" ]]; then
      nsxtT1LR="''"
      avi_cloud_name="Default-Cloud"
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      avi_cloud_name=${nsx_cloud_name}
      if [[ $(echo ${cluster} | jq -c -r '.se_in_provider_context') == "true" ]]; then
        serviceEngineGroupName="${cluster_id}:$(jq -c -r '.about.instanceUuid' /home/ubuntu/json/vcenter_about.json)"
      fi
      nsxtT1LR_name="t1-${cluster_id}:$(jq -c -r '.about.instanceUuid' /home/ubuntu/json/vcenter_about.json)-${namespace}-rtr"
      file_json_output="/home/ubuntu/nsx/t1_path.json"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/tier-1s" \
                  "${file_json_output}"
      nsxtT1LR=$(jq -c -r --arg arg1 "${nsxtT1LR_name}" '.results[] | select(.display_name == $arg1).path' ${file_json_output})
      if $(echo ${tanzu_namespaces} | jq -e --arg arg1 ${namespace} '.[] | select(.name == $arg1) | .ingress_cidr' > /dev/null) ; then
        cidr_vip_full=$(echo ${tanzu_namespaces} | jq -c -r --arg arg ${namespace} '.[] | select(.name == $arg) | .ingress_cidr')
      else
        cidr_vip_full=${supervisor_cluster_ingress_cidr}
      fi
      json_api_output="/home/ubuntu/avi/cloud-details.json"
      /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                           "api/cloud" \
                                           "GET" \
                                           "${avi_version}" \
                                           "admin" \
                                           "" \
                                           "${json_api_output}"
      cloud_url=$(jq -c -r --arg arg1 "${avi_cloud_name}" '.results[] | select( .name == $arg1 ) | .url' ${json_api_output})
      json_api_output="/home/ubuntu/avi/network-details.json"
      /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                           "api/network?page_size=-1" \
                                           "GET" \
                                           "${avi_version}" \
                                           "admin" \
                                           "" \
                                           "${json_api_output}"
      network_ref_vip=$(jq -c -r --arg arg1 "${cloud_url}" \
                                 --arg arg2 "$(echo ${cidr_vip_full} | cut -d"/" -f1)" \
                                 '.results[] | select(.cloud_ref == $arg1 and .configured_subnets != null and .configured_subnets[0].prefix.ip_addr.addr == $arg2)' ${json_api_output} | jq .name)
    fi
    if $(echo ${cluster} | jq -e '.ako_api_gateway' > /dev/null) ; then
      if [[ $(echo ${cluster} | jq -c -r .ako_api_gateway) == "true" ]]; then
        echo "defaulting to AKO version 1.12.1 with gatewayApi for cluster ${tkc_name}"
        ako_template_file_name="values_api_gw.yml.$(echo ${cluster} | jq -c -r .ako_version).template"
      else
        echo "defaulting to AKO version 1.12.1 without gatewayApi for cluster ${tkc_name}"
        ako_template_file_name="values.yml.$(echo ${cluster} | jq -c -r .ako_version).template"
      fi
    else
      echo "defaulting to AKO version 1.12.1 without gatewayApi  for cluster ${tkc_name}"
      ako_template_file_name="values.yml.$(echo ${cluster} | jq -c -r .ako_version).template"
    fi
    sed -e "s/\${disableStaticRouteSync}/${disableStaticRouteSync}/" \
        -e "s/\${clusterName}/${tkc_name}/" \
        -e "s/\${cniPlugin}/${cniPlugin}/" \
        -e "s@\${nsxtT1LR}@${nsxtT1LR}@" \
        -e "s/\${networkName}/${network_ref_vip}/" \
        -e "s@\${cidr}@${cidr_vip_full}@" \
        -e "s/\${serviceType}/${serviceType}/" \
        -e "s/\${shardVSSize}/${shardVSSize}/" \
        -e "s/\${serviceEngineGroupName}/${serviceEngineGroupName}/" \
        -e "s/\${controllerVersion}/${avi_version}/" \
        -e "s/\${cloudName}/${avi_cloud_name}/" \
        -e "s/\${controllerHost}/${ip_avi}/" \
        -e "s/\${tenant}/$(echo ${cluster} | jq -c -r .avi_tenant_name)/" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/${ako_template_file_name} | tee /home/ubuntu/tkc/ako_${tkc_name}_values.yml > /dev/null
    sudo cp /home/ubuntu/tkc/ako_${tkc_name}_values.yml /var/www/html/
    ((cluster_count++))
  done
fi