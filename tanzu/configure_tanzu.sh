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
  if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]]; then
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
  if [[ ${kind} == "vsphere-nsx-vpc-avi" ]]; then
    # test after vCenter config
    exit
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
  # place holder to detect the version of vsphere
  #
  if [[ $(jq -c -r '.about.version' ${vcsa_about_json_file} | cut -d"." -f1) == "8" ]] ; then echo "this is vSphere8" ; fi
  if [[ $(jq -c -r '.about.version' ${vcsa_about_json_file} | cut -d"." -f1) == "9" ]] ; then echo "this is vSphere9" ; fi
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
      "${cluster_id}" \
      "${supervisor_cluster_count_vm}"
  fi
  #
  # vsphere-nsx-vpc-avi use case only for vSphere9
  #
  if [[ ${kind} == "vsphere-nsx-vpc-avi" && $(jq -c -r '.about.version' ${vcsa_about_json_file} | cut -d"." -f1) == "9" ]]; then
    token=$(/bin/bash /home/ubuntu/vcenter/create_vcenter_api_session.sh "administrator" "${ssoDomain}" "${GENERIC_PASSWORD}" "${api_host}")
    private_ip_block_name=$(echo ${nsx_vpcs} | jq -c -r --arg arg "${supervisor_cluster_project}" '.[] | select( .project_ref == $arg).private_ips_refs[0]')
    private_ip_block_address="$(echo ${nsx_ip_blocks} | jq -c -r --arg arg ${private_ip_block_name} '.[] | select( .name == $arg).cidr' | cut -d"." -f1-3).128"
    json_data='
    {
        "control_plane": {
          "count": '${supervisor_cluster_count_vm}',
          "network": {
            "backing": {
              "backing": "NETWORK_SEGMENT",
              "network_segment": {
                "networks": [ "'${tanzu_supervisor_dvportgroup}'" ]
              }
            },
            "ip_management": {
              "dhcp_enabled": false,
              "gateway_address": "'$(echo ${management_tanzu_gw} | cut -d"/" -f1)'",
              "ip_assignments": [ {
                "assignee": "NODE",
                "ranges": [ {
                  "address": "'${master_management_network_starting_address}'",
                  "count": "'${management_tanzu_supervisor_count}'"
                } ]
              } ]
            },
            "network": "managementnetwork0",
            "proxy": {
              "proxy_settings_source": "VC_INHERITED"
            },
            "services": {
              "dns": {
                "search_domains": [ "'${domain}'" ],
                "servers": [ "'${ip_gw}'" ]
              },
              "ntp": {
                "servers": [ "'${ip_gw}'" ]
              }
            }
          },
          "size": "'${supervisor_cluster_size}'",
          "storage_policy": "'${storage_policy_id}'"
        },
        "name": "sup-01",
        "workloads": {
          "edge": {
            "provider": "NSX_VPC"
          },
          "network": {
            "ip_management": {
              "dhcp_enabled": false,
              "gateway_address": "'$(echo ${management_tanzu_gw} | cut -d"/" -f1)'",
              "ip_assignments": [ {
                "assignee": "SERVICE",
                "ranges": [ {
                  "address": "'${master_management_network_starting_address}'",
                  "count": "'${management_tanzu_supervisor_count}'"
                } ]
              } ]
            },
            "network": "workloadnetwork0",
            "network_type": "NSX_VPC",
            "nsx_vpc": {
              "default_private_cidrs": [ {
                "address": "'${private_ip_block_address}'",
                "prefix": 25
              } ],
              "nsx_project": "/orgs/default/projects/'${supervisor_cluster_project}'",
              "vpc_connectivity_profile": "/orgs/default/projects/'${supervisor_cluster_project}'/vpc-connectivity-profiles/'$(echo ${nsx_vpc_connectivity_profiles} | jq -c -r --arg arg "${supervisor_cluster_project}" '.[] | select( .project_ref == $arg).name')'"
              },
              "services": {
                "dns": {
                  "search_domains": [ "'${domain}'" ],
                  "servers": [ "'${ip_gw}'" ]
                },
                "ntp": {
                  "servers": [ "'${ip_gw}'" ]
                }
              }
          },
          "storage": {
            "ephemeral_storage_policy": "'${storage_policy_id}'",
            "image_storage_policy": "'${storage_policy_id}'"
          }
        }
    }'


    json_data='
    {
      "cluster_proxy_config": {
        "proxy_settings_source": "VC_INHERITED"
      },
      "workload_ntp_servers": ["'${ip_gw}'"],
      "image_storage":
      {
        "storage_policy":"'${storage_policy_id}'"
      },
      "master_NTP_servers":["'${ip_gw}'"],
      "ephemeral_storage_policy":"'${storage_policy_id}'",
      "service_cidr":
      {
        "address":"'$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f1)'",
        "prefix": "'$(echo ${supervisor_cluster_service_cidr} | cut -d"/" -f2)'"
      },
      "size_hint":"'${supervisor_cluster_size}'",
      "worker_DNS":["'${ip_gw}'"],
      "master_DNS":["'${ip_gw}'"],
      "network_provider": "NSX_VPC",
      "master_storage_policy":"'${storage_policy_id}'",
      "count": '${supervisor_cluster_count_vm}',
      "master_management_network":
      {
        "mode":"STATICRANGE",
        "address_range":
          {
            "subnet_mask":"255.255.255.0",
            "starting_address":"'${master_management_network_starting_address}'",
            "gateway":"'$(echo ${management_tanzu_gw} | cut -d"/" -f1)'",
            "address_count":"'${management_tanzu_supervisor_count}'"
          },
        "network":"'${tanzu_supervisor_dvportgroup}'"
      },
      "vpc_network": {
        "nsx_project": "/orgs/default/projects/'${supervisor_cluster_project}'",
        "auto_created": true,
        "default_private_cidrs": [
          {
            "address": "",
            "prefix": 0
          },
          {
            "address": "'${private_ip_block_address}'",
            "prefix": 25
          }
        ],
        "vpc_connectivity_profile": "/orgs/default/projects/'${supervisor_cluster_project}'/vpc-connectivity-profiles/'$(echo ${nsx_vpc_connectivity_profiles} | jq -c -r --arg arg "${supervisor_cluster_project}" '.[] | select( .project_ref == $arg).name')'"
      },
      "default_kubernetes_service_content_library":"'${content_library_id}'"
    }'
    echo "${json_data}"
    vcenter_api 2 2 "POST" $token "${json_data}" $api_host "api/vcenter/namespace-management/clusters/${cluster_id}?action=enable"
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
              "${cluster_id}" \
              "${supervisor_cluster_count_vm}"
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
  sed -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" /home/ubuntu/templates/vks/vsphere_plugin_install.sh.template | tee /home/ubuntu/tanzu/vsphere_plugin_install.sh > /dev/null
  /bin/bash /home/ubuntu/tanzu/vsphere_plugin_install.sh
  #
  # auth supervisor script
  #
  sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
      -e "s/\${sso_domain_name}/${ssoDomain}/" \
      -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" /home/ubuntu/templates/vks/tanzu_auth_supervisor.sh.template | tee /home/ubuntu/tanzu/auth_supervisor.sh > /dev/null
  chmod u+x /home/ubuntu/tanzu/auth_supervisor.sh
fi
#
# Namespace creation
#
if [[ ${configure_supervisor} == "true" && ${configure_namespace} == "true" ]] ; then
  for ns in $(echo ${tanzu_namespaces} | jq -c -r .[])
  do
    ns_wo_overwrite_network="dummy"
    # bash auth ns templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/$(echo ${ns} | jq -c -r .name)/" /home/ubuntu/templates/vks/tanzu_auth_ns.sh.template | tee /home/ubuntu/tanzu/auth_$(echo ${ns} | jq -c -r .name).sh > /dev/null
    chmod u+x /home/ubuntu/tanzu/auth_$(echo ${ns} | jq -c -r .name).sh
    #
    if $(echo $ns | jq -e '.tkc' > /dev/null) ; then
      if [[ $(echo $ns | jq -e '.tkc') == "true" ]]; then
        if $(echo $ns | jq -e '.ingress_cidr' > /dev/null) ; then
          if [[ ${kind} == "vsphere-nsx-avi" ]]; then
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
            ns_wo_overwrite_network="false"
          fi
        else
          ns_wo_overwrite_network="false"
        fi
      fi
    fi
    if [[ ${ns_wo_overwrite_network} == "false" ]]; then
      /bin/bash /home/ubuntu/vcenter/create_namespaces.sh "${api_host}" "${ssoDomain}" "${GENERIC_PASSWORD}" \
                "$(jq -r .tanzu.vm_classes $jsonFile)" \
                "${storage_policy_id}" \
                "$(echo $ns | jq -c -r .name)"
    fi
    if $(echo $ns | jq -e '.vm' > /dev/null) ; then
      if [[ $(echo $ns | jq -e '.vm') == "true" ]]; then
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
  done
  #
  # tkc creation
  #
  echo "waiting 1 minute before tkc/ako templating/creation"
  sleep 60
  cluster_count=1
  #
  # html /home/ubuntu/tkc/tkgs-workload.html
  #
  tee /home/ubuntu/tkc/tkgs-workload.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Workload Clusters</title>
    <style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
  text-align: left;
}
.code-box {
  border: 1px solid black;
  overflow-x: auto;
  padding: 10px;
  white-space: pre-wrap;
}
</style>
</head>
<body>
<h1>Workload Clusters</h1>
<ul>
EOT
  #
  #
  #
  javascript_count=0
  for cluster in $(echo ${tkc_clusters} | jq -c -r .[])
  do
    namespace=$(echo ${cluster} | jq -c -r .namespace_ref)
    tkc_name=$(echo ${cluster} | jq -c -r .name)
    #
    # html /home/ubuntu/tkc/tkgs-workload.html
    #
    tee -a /home/ubuntu/tkc/tkgs-workload.html> /dev/null <<EOT
    <li>${tkc_name}</li>
    <br>
    <table>
        <tr>
            <th>vSphere Namespaces</th>
            <td>${namespace}</td>
        </tr>
        <tr>
            <th>Antrea Config Yaml manifest</th>
            <td><a href="${tkc_name}-antrea-package.yml" target="_blank">Antrea Config Yaml manifest</a></td>
        </tr>
        <tr>
            <th>Cluster Yaml manifest</th>
            <td><a href="${tkc_name}.yml" target="_blank">Cluster Yaml manifest</a></td>
        </tr>
        <tr>
            <th>Commands from the external gw to create cluster1</th>
            <td class="code-box">
    <pre><code>
/home/ubuntu/tkc/${tkc_name}_create.sh
    </code></pre>
<button onclick="copyToClipboard(${javascript_count})">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Authenticate to the cluster</th>
            <td class="code-box">
    <pre><code>
/home/ubuntu/tkc/auth_${tkc_name}.sh
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+1)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Create namespaces and docker account</th>
            <td class="code-box">
    <pre><code>
/home/ubuntu/tkc/auth_${tkc_name}.sh
/home/ubuntu/tkc/k8s-config.sh
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+2)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>AKO Gateway API enabled</th>
            <td>$(echo ${cluster} | jq -c -r .ako_api_gateway)</td>
        </tr>
        <tr>
            <th>AKO values Yaml</th>
            <td><a href="ako_${tkc_name}_values.yml" target="_blank">AKO values Yaml</a></td>
        </tr>
        <tr>
            <th>Install AKO via helm</th>
            <td class="code-box">
    <pre><code>
/home/ubuntu/tkc/auth_${tkc_name}.sh
helm install --generate-name oci://projects.registry.vmware.com/ako/helm-charts/ako  --version $(echo ${cluster} | jq -c -r .ako_version) \\
-f /home/ubuntu/tkc/ako_${tkc_name}_values.yml --namespace=avi-system
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+3)))">Copy Code</button>
            </td>
        </tr>
    </table>
    <br>
    <br>
EOT
    javascript_count=$((javascript_count+4))
    #
    #
    #
    # yaml antrea config map templating
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      sed -e "s/\${name}/${tkc_name}/" \
          -e "s/\${namespace_ref}/${namespace}/" /home/ubuntu/templates/vks/tkc_antrea.yml.template | tee /home/ubuntu/tkc/${tkc_name}-antrea-package.yml > /dev/null
    fi
    if [[ ${kind} == "vsphere-avi" ]]; then
      sed -e "s/\${name}/${tkc_name}/" \
          -e "s/\${namespace_ref}/${namespace}/" /home/ubuntu/templates/vks/tkc_antrea_wo_nsx.yml.template | tee /home/ubuntu/tkc/${tkc_name}-antrea-package.yml > /dev/null
    fi
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
        -e "s/\${vm_class}/$(echo ${cluster} | jq -c -r .vm_class)/" /home/ubuntu/templates/vks/tkc.yml.template | tee /home/ubuntu/tkc/${tkc_name}.yml > /dev/null
    sudo cp /home/ubuntu/tkc/${tkc_name}.yml /var/www/html/
    # bash cluster create templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s@\${yaml_antrea_path}@/home/ubuntu/tkc/${tkc_name}-antrea-package.yml@" \
        -e "s@\${yaml_path}@/home/ubuntu/tkc/${tkc_name}.yml@" \
        -e "s/\${cluster_name}/${tkc_name}/" /home/ubuntu/templates/vks/tkc_wo_antrea_wo_clusterbootstrap.sh.template | tee /home/ubuntu/tkc/${tkc_name}_create.sh > /dev/null
    chmod u+x /home/ubuntu/tkc/${tkc_name}_create.sh
    # bash cluster delete templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/vks/tkc_destroy.sh.template | tee /home/ubuntu/tkc/${tkc_name}_destroy.sh > /dev/null
    chmod u+x /home/ubuntu/tkc/${tkc_name}_destroy.sh
    # bash auth tkc templating
    sed -e "s/\${kubectl_password}/${GENERIC_PASSWORD}/" \
        -e "s/\${sso_domain_name}/${ssoDomain}/" \
        -e "s/\${api_server_cluster_endpoint}/${api_server_cluster_endpoint}/" \
        -e "s/\${namespace_ref}/${namespace}/" \
        -e "s/\${name}/${tkc_name}/" /home/ubuntu/templates/vks/tanzu_auth_tkc.sh.template | tee /home/ubuntu/tkc/auth_${tkc_name}.sh > /dev/null
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
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      if [[ $(echo ${cluster} | jq -c -r '.se_in_provider_context') == "true" ]]; then
        serviceEngineGroupName="${cluster_id}:$(jq -c -r '.about.instanceUuid' ${vcsa_about_json_file})"
      fi
      nsxtT1LR_name="t1-${cluster_id}:$(jq -c -r '.about.instanceUuid' ${vcsa_about_json_file})-${namespace}-rtr"
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
        echo "defaulting to AKO version $(echo ${cluster} | jq -c -r .ako_version) with gatewayApi for cluster ${tkc_name}"
        ako_template_file_name="values_api_gw.yml.$(echo ${cluster} | jq -c -r .ako_version).template"
      else
        echo "defaulting to AKO version $(echo ${cluster} | jq -c -r .ako_version) without gatewayApi for cluster ${tkc_name}"
        ako_template_file_name="values.yml.$(echo ${cluster} | jq -c -r .ako_version).template"
      fi
    else
      echo "defaulting to AKO version $(echo ${cluster} | jq -c -r .ako_version) without gatewayApi  for cluster ${tkc_name}"
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
        -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/ako/${ako_template_file_name} | tee /home/ubuntu/tkc/ako_${tkc_name}_values.yml > /dev/null
    sudo cp /home/ubuntu/tkc/ako_${tkc_name}_values.yml /var/www/html/
    ((cluster_count++))
  done
  #
  # html /home/ubuntu/tkc/tkgs-workload.html
  #
  tee -a /home/ubuntu/tkc/tkgs-workload.html> /dev/null <<EOT
</ul>
<script>
function copyToClipboard(boxIndex) {
  const codeBoxes = document.querySelectorAll('.code-box');
  const codeBox = codeBoxes[boxIndex];
  const codeElement = codeBox.querySelector('code');

  const tempTextarea = document.createElement('textarea');
  tempTextarea.value = codeElement.textContent;
  document.body.appendChild(tempTextarea);

  tempTextarea.select();
  document.execCommand('copy');

  document.body.removeChild(tempTextarea);

}
</script>
</body>
</html>
EOT
  #
  #
  #
  sudo cp /home/ubuntu/tkc/tkgs-workload.html /var/www/html/
fi