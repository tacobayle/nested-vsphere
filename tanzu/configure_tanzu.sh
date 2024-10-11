#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
output_file="/home/ubuntu/tanzu/output.txt"
#
# registering Avi in the NSX config
#
if [[ ${kind} == "vsphere-nsx-avi" ]]; then
  /bin/bash /home/ubuntu/nsx/registering_avi_controller.sh \
              "${ip_nsx}" \
              "${GENERIC_PASSWORD}" \
              "${GENERIC_PASSWORD}" \
              "${ip_avi}"
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
  "${supervisor_network}" \
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
    "$(jq -r .tanzu.supervisor_cluster.service_cidr $jsonFile | cut -d"/" -f1)" \
    "$(jq -r .tanzu.supervisor_cluster.service_cidr $jsonFile | cut -d"/" -f2)" \
    "$(jq -r .tanzu.supervisor_cluster.size $jsonFile)" \
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
  retrieve_network_id_json_output="/home/ubuntu/tanzu/retrieve_namespace_edge_cluster_id.json"
  /bin/bash /home/ubuntu/nsx/get_edge_cluster.sh \
           "${ip_nsx}" \
           "${GENERIC_PASSWORD}" \
           "$(jq -r .nsx.config.edge_clusters[0].display_name $jsonFile)" \
           "${retrieve_network_id_json_output}"
  namespace_edge_cluster_id=$(jq -c -r .namespace_edge_cluster_id ${retrieve_network_id_json_output})
  #
  # create supervisor cluster
  #
  /bin/bash /home/ubuntu/vcenter/create_supervisor_cluster_nsx.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
            "${content_library_id}" \
            "${storage_policy_id}" \
            "${ip_gw}" \
            "$(jq -r .tanzu.supervisor_cluster.size $jsonFile)" \
            "$(jq -r .tanzu.supervisor_cluster.service_cidr $jsonFile | cut -d"/" -f1)" \
            "$(jq -r .tanzu.supervisor_cluster.service_cidr $jsonFile | cut -d"/" -f2)" \
            "$(ip_netmask_by_prefix $(echo ${management_tanzu_cidr} | cut -d"/" -f2) "   ++++++")" \
            "${management_tanzu_supervisor_starting_ip}" \
            "$(nextip $(echo ${management_tanzu_cidr} | cut -d"/" -f1 ))" \
            "${management_tanzu_supervisor_count}" \
            "${tanzu_supervisor_dvportgroup}" \
            "$(jq -c -r .vds_network_nsx_overlay_id /root/vds_network_nsx_overlay_id.json)" \
            "$(jq -r .tanzu.supervisor_cluster.namespace_cidr $jsonFile | cut -d"/" -f1)" \
            "$(jq -r .tanzu.supervisor_cluster.namespace_cidr $jsonFile | cut -d"/" -f2)" \
            "$(jq -r .tanzu.supervisor_cluster.namespace_tier0 $jsonFile)" \
            "${namespace_edge_cluster_id}" \
            "$(jq -r .tanzu.supervisor_cluster.prefix_per_namespace $jsonFile)" \
            "$(jq -r .tanzu.supervisor_cluster.ingress_cidr $jsonFile | cut -d"/" -f1)" \
            "$(jq -r .tanzu.supervisor_cluster.ingress_cidr $jsonFile | cut -d"/" -f2)" \
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
    -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" /home/ubuntu/templates/tanzu_auth_supervisor.sh.template | tee /home/ubuntu/tanzu/tanzu_auth_supervisor.sh > /dev/null
#
# Namespace creation
#
if [[ ${configure_tanzu_workload} == "true" ]] ; then
  for ns in $(echo ${tanzu_namespaces} | jq -c -r .[])
  do
    if [[ ${kind} == "vsphere-avi" ]]; then
      /bin/bash /home/ubuntu/vcenter/create_namespaces.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                "$(jq -r .tanzu.vm_classes $jsonFile)" \
                "${storage_policy_id}" \
                "$(echo $ns | jq -c -r .name)"
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      if $(echo $ns | jq -e '.ingress_cidr' > /dev/null) ; then
        /bin/bash /home/ubuntu/vcenter/create_namespaces_nsx_overwrite_network.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                  "$(jq -r .tanzu.vm_classes $jsonFile)" \
                  "${storage_policy_id}" \
                  "$(echo $ns | jq -c -r .name)" \
                  "$(echo $ns | jq -c -r .ingress_cidr | cut -d"/" -f1)" \
                  "$(echo $ns | jq -c -r .ingress_cidr | cut -d"/" -f2)" \
                  "$(echo $ns | jq -c -r .namespace_cidr | cut -d"/" -f1)" \
                  "$(echo $ns | jq -c -r .namespace_cidr | cut -d"/" -f2)" \
                  "$(jq -c -r .nsx.config.tier0s[0].display_name)" \
                  "$(echo $ns | jq -c -r .prefix_per_namespace)"
      else
        /bin/bash /home/ubuntu/vcenter/create_namespaces.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                  "$(jq -r .tanzu.vm_classes $jsonFile)" \
                  "${storage_policy_id}" \
                  "$(echo $ns | jq -c -r .name)"
      fi
    fi
  done
  #
  # tkc creation
  #
  cluster_count=1
  for cluster in $(echo ${tkc_clusters} | jq -c -r .[])
  do
    namespace=$(echo ${cluster} | jq -c -r .namespace_ref)
    tkc_name=$(echo ${cluster} | jq -c -r .name)
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
    # bash cluster create templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s@\${yaml_path}@/home/ubuntu/tkc/${tkc_name}.yml@" \
        -e "s/\${cluster_name}/${tkc_name}/" /home/ubuntu/templates/tkc_wo_antrea_wo_clusterbootstrap.sh.template | tee /home/ubuntu/tkc/${tkc_name}_create.sh > /dev/null
    # bash cluster create templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/tkc_destroy.sh.template | tee /home/ubuntu/tkc/${tkc_name}_destroy.sh > /dev/null
    # bash auth tkc templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/tanzu_auth_tkc.sh.template | tee /home/ubuntu/tkc/tanzu_auth_${tkc_name}.sh > /dev/null
    # bash create exec
    /bin/bash /home/ubuntu/tkc/${tkc_name}_create.sh
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
    sed -e "s/\${disableStaticRouteSync}/${disableStaticRouteSync}/" \
        -e "s/\${clusterName}/${tkc_name}/" \
        -e "s/\${cniPlugin}/${cniPlugin}/" \
        -e "s@\${nsxtT1LR}@${nsxtT1LR}@" \
        -e "s/\${networkName}/${network_ref_vip}/" \
        -e "s@\${cidr}@${cidr_vip}@" \
        -e "s/\${serviceType}/${serviceType}/" \
        -e "s/\${shardVSSize}/${shardVSSize}/" \
        -e "s/\${serviceEngineGroupName}/${serviceEngineGroupName}/" \
        -e "s/\${controllerVersion}/${avi_version}/" \
        -e "s/\${cloudName}/${avi_cloud_name}/" \
        -e "s/\${controllerHost}/${ip_avi}/" \
        -e "s/\${tenant}/$(echo ${cluster} | jq -c -r .avi_tenant_name)/" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/values.yml.1.12.1.template | tee /home/ubuntu/tkc/ako_${tkc_name}_values.yml > /dev/null
    ((cluster_count++))
  done
fi