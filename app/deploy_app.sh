#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# k8s templating k8s script config
#
sed -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
    -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
    -e "s@\${jsonFile}@${jsonFile}@" \
    -e "s/\${docker_registry_email}/${DOCKER_REGISTRY_EMAIL}/" /home/ubuntu/templates/k8s-config.sh.template | tee "/home/ubuntu/k8s/k8s-config.sh" >/dev/null 2>&1
chmod u+x /home/ubuntu/k8s/k8s-config.sh
cp /home/ubuntu/k8s/k8s-config.sh /home/ubuntu/tkc/k8s-config.sh
#
# ako values templating
#
serviceEngineGroupName="Default-Group"
shardVSSize="SMALL"
serviceType="ClusterIP"
disableStaticRouteSync="false" # needs to be true if NodePortLocal is enabled
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version="$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')"
    ako_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].ako_version')
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    if [[ ${cni} == "antrea" ]]; then
      disableStaticRouteSync="true"
      serviceType="NodePortLocal"
    fi
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    if [[ ${kind} == "vsphere-avi" ]]; then
      nsxtT1LR="''"
      avi_cloud_name="Default-Cloud"
    fi
    if [[ ${kind} == "vsphere-nsx-avi" ]]; then
      file_json_output="/home/ubuntu/nsx/tier-1s.json"
      /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/tier-1s" \
                  "${file_json_output}"
      connectivity_path=$(jq -c -r --arg arg1 "$(echo ${segments_overlay} | jq -r -c '.[] | select(.display_name == "segment-vip-1").tier1')" '.results[] | select(.display_name == $arg1).path' ${file_json_output})
      nsxtT1LR="${connectivity_path}"
      avi_cloud_name="${nsx_cloud_name}"
      network_ref_vip=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == true).display_name')
      cidr_vip_full=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == true).cidr')
    fi
    sed -e "s/\${disableStaticRouteSync}/${disableStaticRouteSync}/" \
        -e "s/\${clusterName}/${k8s_basename}${index}/" \
        -e "s/\${cniPlugin}/${cni}/" \
        -e "s@\${nsxtT1LR}@${nsxtT1LR}@" \
        -e "s/\${networkName}/${network_ref_vip}/" \
        -e "s@\${cidr}@${cidr_vip_full}@" \
        -e "s/\${serviceType}/${serviceType}/" \
        -e "s/\${shardVSSize}/${shardVSSize}/" \
        -e "s/\${serviceEngineGroupName}/${serviceEngineGroupName}/" \
        -e "s/\${controllerVersion}/${avi_version}/" \
        -e "s/\${cloudName}/${avi_cloud_name}/" \
        -e "s/\${controllerHost}/${ip_avi}/" \
        -e "s/\${tenant}/${k8s_basename}${index}/" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/values_api_gw.yml.${ako_version}.template | tee /home/ubuntu/k8s/ako_${k8s_basename}${index}_values.yml > /dev/null
        sudo cp /home/ubuntu/k8s/ako_${k8s_basename}${index}_values.yml /var/www/html/
  done
fi
#
# Ubuntu download
#
#download_file_from_url_to_location "${ubuntu_ova_url}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})" "Ubuntu OVA"
#if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Ubuntu OVA downloaded"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "ERROR: unable to connect to vCenter"
  exit
fi
#
# content library creation
#
govc library.create ${content_library_name}
govc library.import ${content_library_name} "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
#
# folder creation for app
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Apps"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_app}'")' >/dev/null ) ; then
  echo "ERROR: unable to create folder ${folder_app}: it already exists"
else
  govc folder.create /${dc}/vm/${folder_app}
  echo "Ending timestamp: $(date)"
fi
#
# folder creation for k8s cluster
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for k8s clusters"
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${k8s_basename}${index}'")' >/dev/null ) ; then
      echo "ERROR: unable to create folder ${k8s_basename}${index}: it already exists"
    else
      govc folder.create /${dc}/vm/${k8s_basename}${index}
      echo "Ending timestamp: $(date)"
    fi
  done
fi
#
# App VMs creation first group // vsphere-avi use case)
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_app_list} | jq -c -r '. | length')-1)))
    do
      ip_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
      prefix_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].cidr' | cut -d"/" -f2)"
      gw_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].gw')"
      network_ref_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].display_name')"
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/${network_ref_app}-${app_basename}${index}/" \
          -e "s/\${ip_app}/${ip_app}/" \
          -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
          -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
          -e "s/\${app_tcp_default}/${app_tcp_default}/" \
          -e "s/\${app_tcp_waf}/${app_tcp_waf}/" \
          -e "s@\${docker_registry_repo_default_app}@${docker_registry_repo_default_app}@" \
          -e "s@\${docker_registry_repo_waf}@${docker_registry_repo_waf}@" \
          -e "s/\${prefix}/${prefix_app}/" \
          -e "s/\${packages}/${app_apt_packages}/" \
          -e "s/\${default_gw}/${gw_app}/" \
          -e "s/\${forwarders_netplan}/${ip_gw}/" /home/ubuntu/templates/userdata_app.yaml.template | tee /home/ubuntu/app/userdata_app${index}.yaml
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app${index}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${network_ref_app}@" \
          -e "s/\${vm_name}/${network_ref_app}-${app_basename}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-${index}.json"
      #
  #    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
      govc library.deploy -options "/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
      govc vm.change -vm "${folder_app}/${network_ref_app}-${app_basename}${index}" -c ${app_cpu} -m ${app_memory}
      govc vm.power -on=true "${folder_app}/${network_ref_app}-${app_basename}${index}"
      if [[ ${kind} == "vsphere-nsx-avi" && ${index} == 1 ]]; then
        for net_vip in $(seq 0 $(($(echo ${net_client_list} | jq -c -r '. | length')-1)))
        do
          if [[ $(echo ${net_app_list} | jq -r -c '.['${net}'].server_preserve_ip') == $(echo ${net_client_list} | jq -r -c '.['${net_vip}'].vip_preserve_ip') ]]; then
            tier1_name="$(echo ${net_client_list} | jq -r -c '.['${net_vip}'].tier1')"
            # create nsx group with tag criteria
            /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                        "policy/api/v1/infra/domains/default/groups/${nsx_group_app_name}_${network_ref_app}_${tier1_name}" \
                        "PUT" \
                        "{\"display_name\": \"${nsx_group_app_name}_${network_ref_app}_${tier1_name}\",
                          \"expression\": [
                            {
                              \"member_type\": \"VirtualMachine\",
                              \"value\": \"${nsx_group_app_tag}_${network_ref_app}_${tier1_name}\",
                              \"key\": \"Tag\",
                              \"operator\": \"EQUALS\",
                              \"resource_type\": \"Condition\"
                            }
                          ]
                        }"
            echo "waiting for 60 seconds"
            sleep 60
            # retrieve the external_id of the first VM
            file_json_output="/home/ubuntu/nsx/vms.json"
            /bin/bash /home/ubuntu/nsx/get_object.sh \ "${ip_nsx}" "${GENERIC_PASSWORD}" \
                        "api/v1/fabric/virtual-machines" \
                        "${file_json_output}"
            external_id=$(jq -c -r --arg arg1 "${network_ref_app}-${app_basename}${index}" '.results[] | select(.display_name == $arg1).external_id' ${file_json_output})
            # tag the first vm
            /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                        "policy/api/v1/infra/tags/tag-operations/${nsx_group_app_tag}_${network_ref_app}_${tier1_name}" \
                        "PUT" \
                        "{\"tag\": {
                             \"tag\": \"${nsx_group_app_tag}_${network_ref_app}_${tier1_name}\"
                           },
                          \"apply_to\": [
                            {
                              \"resource_type\": \"VirtualMachine\",
                              \"resource_ids\": [\"${external_id}\"]
                            }
                          ]
                        }"
          fi
        done
      fi
    done
  done
fi
#
# App VMs creation second group // vsphere-avi use case)
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    ip_app="$(echo ${net_app_list} | jq -r -c '.[0].cidr_three_octets').$(echo ${ips_app_second} | jq -c -r .[$(expr ${index} - 1)])"
    prefix_app="$(echo ${net_app_list} | jq -r -c '.[0].cidr' | cut -d"/" -f2)"
    gw_app="$(echo ${net_app_list} | jq -r -c '.[0].gw')"
    network_ref_app="$(echo ${net_app_list} | jq -r -c '.[0].display_name')"
    sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s/\${hostname}/${network_ref_app}-${app_basename_second}${index}/" \
        -e "s/\${ip_app}/${ip_app}/" \
        -e "s/\${prefix}/${prefix_app}/" \
        -e "s/\${packages}/${app_apt_packages}/" \
        -e "s/\${default_gw}/${gw_app}/" \
        -e "s/\${forwarders_netplan}/${ip_gw}/" /home/ubuntu/templates/userdata_app_second.yaml.template | tee /home/ubuntu/app/userdata_app_second${index}.yaml
    #
    sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
        -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_app_second${index}.yaml -w 0)@" \
        -e "s/\${password}/${GENERIC_PASSWORD}/" \
        -e "s@\${network_ref}@${network_ref_app}@" \
        -e "s/\${vm_name}/${network_ref_app}-${app_basename_second}${index}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/options-app-second-${index}.json"
    #
#    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
    govc library.deploy -options "/home/ubuntu/app/options-app-second-${index}.json" -folder "${folder_app}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
    govc vm.change -vm "${folder_app}/${network_ref_app}-${app_basename_second}${index}" -c ${app_cpu} -m ${app_memory}
    govc vm.power -on=true "${folder_app}/${network_ref_app}-${app_basename_second}${index}"
  done
fi
#
# VM k8s_clusters creation
#
if [[ ${k8s_clusters} != "null" ]]; then
  kube_increment_ip=0
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version="$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')"
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    for index_ip in $(seq 1 2)
    do
      if [[ ${kind} == "vsphere-nsx-avi" ]]; then
        cidr=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").cidr')
        if [[ ${cidr} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
          cidr_vip_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        fi
        prefix_client=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").cidr' | cut -d"/" -f2)
        gw_client=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").gateway_address' | cut -d"/" -f1)
        network_ref_vip=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").display_name')
      fi
      kube_last_octet=$((kube_starting_ip+kube_increment_ip))
      ip_k8s_node="${cidr_vip_three_octets}.${kube_last_octet}"
      if [[ ${index_ip} -eq 1 ]]; then
        node_type="master"
      else
        node_type="worker"
      fi
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}/" \
          -e "s/\${ip}/${ip_k8s_node}/" \
          -e "s/\${prefix}/${prefix_client}/" \
          -e "s/\${packages}/${k8s_apt_packages}/" \
          -e "s/\${default_gw}/${gw_client}/" \
          -e "s/\${forwarders_netplan}/${ip_gw}/" \
          -e "s/\${docker_version}/${docker_version}/" \
          -e "s/\${node_type}/${node_type}/" \
          -e "s@\${pod_cidr}@${pod_cidr}@" \
          -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
          -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
          -e "s/\${cni}/${cni}/" \
          -e "s/\${cni_version}/${cni_version}/" \
          -e "s/\${K8s_version}/${K8s_version}/" /home/ubuntu/templates/userdata_k8s_node.yaml.template | tee /home/ubuntu/app/userdata_${k8s_basename}${index}_node${index_ip}.yaml
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /home/ubuntu/app/userdata_${k8s_basename}${index}_node${index_ip}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${network_ref_vip}@" \
          -e "s/\${vm_name}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}/" /home/ubuntu/templates/options-ubuntu.json.template | tee "/home/ubuntu/app/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}.json"
      #
  #    govc import.ova --options="/home/ubuntu/app/options-app-${index}.json" -folder "${folder_app}" "/home/ubuntu/bin/$(basename ${ubuntu_ova_url})"
      govc library.deploy -options "/home/ubuntu/app/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}.json" -folder "${k8s_basename}${index}" /ubuntu/$(basename ${ubuntu_ova_url} .ova)
      govc vm.change -vm "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" -c ${k8s_node_cpu} -m ${k8s_node_memory}
      govc vm.disk.change -vm "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" -size ${k8s_node_disk}
      govc vm.power -on=true "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}"
      ((kube_increment_ip++))
    done
  done
fi
#
# NSX LB config
#
count=1
if [[ ${kind} == "vsphere-nsx-avi" ]] ; then
  echo ${tier1s} | jq -c -r .[] | while read item
  do
    if $(echo ${item} | jq -e '.lb' > /dev/null) ; then
      if [[ $(echo ${item} | jq -c -r '.lb') == "true" ]] ; then
        display_name="${nsx_lb_basename}-${count}"
        nsx_vip_ip="$(echo $item | jq -c -r .nsx_vip_cidr | cut -d'.' -f1-3).${nsx_vip_last_octet}"
        network_ref_app=$(echo ${segments_overlay} | jq -c -r '[.[] | select(.backend == true and keys[] | select(. != "server_preserve_ip"))] | first | .display_name')
        tier1_group_name=$(echo ${segments_overlay} | jq -c -r '[.[] | select(.backend == true and keys[] | select(. != "server_preserve_ip"))] | first | .tier1')
        nsx_lb_group_name="${nsx_group_app_name}_${network_ref_app}_${tier1_group_name}"
        # retrieve lb tier1_path
        file_json_output="/tmp/tier1_lb_path.json"
        json_key="t1_path"
        /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/tier-1s" \
                    "$(echo $item | jq -c -r .display_name)" \
                    "${file_json_output}" \
                    "${json_key}"
        tier1_lb_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
        # create lb
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/lb-services/${display_name}" \
                    "PUT" \
                    "{\"display_name\": \"${display_name}\",
                      \"connectivity_path\": \"${tier1_lb_path}\",
                      \"size\": \"${nsx_lb_size}\"
                    }"
        # retrieve lb_path
        file_json_output="/tmp/lb_path.json"
        json_key="lb_path"
        /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/lb-services/" \
                    "${display_name}" \
                    "${file_json_output}" \
                    "${json_key}"
        lb_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
        # retrieve group_path
        file_json_output="/tmp/group_path.json"
        json_key="group_path"
        /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/domains/default/groups" \
                    "${nsx_lb_group_name}" \
                    "${file_json_output}" \
                    "${json_key}"
        group_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
        # pool creation
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/lb-pools/${display_name}-pool" \
                    "PUT" \
                    "{\"display_name\": \"${display_name}-pool\",
                      \"snat_translation\": {\"type\": \"LBSnatAutoMap\"},
                      \"member_group\": {
                        \"group_path\": \"${group_path}\",
                        \"port\": 80,
                        \"ip_revision_filter\": \"IPV4\"
                      }
                    }"
        # retrieve pool_path
        file_json_output="/tmp/pool_path.json"
        json_key="pool_path"
        /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/lb-pools" \
                    "${display_name}-pool" \
                    "${file_json_output}" \
                    "${json_key}"
        pool_path=$(jq -c -r '.'${json_key}'' ${file_json_output})
        # cert ca creation
        directory="/home/ubuntu/nsx"
        ca_name="My-Root-CA"
        CN="My Root CA"
        C="FR"
        ST="Paris"
        L="Paris"
        O="MyOrganisation"
        key_size=4096
        ca_cert_days=1826
        ca_private_key_passphrase=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12) >/dev/null 2>&1
        echo ${ca_private_key_passphrase} | tee ${directory}/ca_private_key_passphrase.txt >/dev/null 2>&1
        openssl genrsa -aes256 -passout pass:${ca_private_key_passphrase} -out ${directory}/${ca_name}.key ${key_size} >/dev/null 2>&1
        openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -passin pass:${ca_private_key_passphrase} -in ${directory}/${ca_name}.key -out ${directory}/${ca_name}.pkcs8.key
        openssl req -x509 -new -nodes -passin pass:${ca_private_key_passphrase} -key ${directory}/${ca_name}.key -sha256 -days ${ca_cert_days} -out ${directory}/${ca_name}.crt -subj "/CN=${CN}/C=${C}/ST=${ST}/L=${L}/O=${O}" >/dev/null 2>&1
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "api/v1/trust-management/certificates/${display_name}-cert-ca?action=import_trusted_ca" \
                    "POST" \
                    "{\"display_name\": \"${display_name}-cert-ca\",
                      \"pem_encoded\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.crt)\",
                      \"private_key\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.key)\",
                      \"purpose\": \"signing-ca\",
                      \"passphrase\": \"$(cat ${directory}/ca_private_key_passphrase.txt)\"
                    }"
        # cert app creation
        cn="My App"
        c="FR"
        st="Paris"
        l="Paris"
        org="MyOrganisation"
        dns="myserver1.local"
        openssl req -new -nodes -out ${directory}/${lb_app_cert}.csr -newkey rsa:4096 -keyout ${directory}/${lb_app_cert}.key -subj "/CN=${cn}/C=${c}/ST=${st}/L=${l}/O=${org}" >/dev/null 2>&1
        echo 'authorityKeyIdentifier=keyid,issuer
        basicConstraints=CA:FALSE
        keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
        extendedKeyUsage=serverAuth, clientAuth
        subjectAltName = @alt_names
        [alt_names]
        ' | tee ${directory}/${lb_app_cert}.v3.ext >/dev/null 2>&1
        echo "DNS.1 = ${dns}" | tee -a ${directory}/${lb_app_cert}.v3.ext >/dev/null 2>&1
        echo "IP.1 = ${nsx_vip_ip}" | tee -a ${directory}/${lb_app_cert}.v3.ext >/dev/null 2>&1
        openssl x509 -req -in ${directory}/${lb_app_cert}.csr -CA ${directory}/${ca_name}.crt -passin pass:${ca_private_key_passphrase} -CAkey ${directory}/${ca_name}.key -CAcreateserial -out ${directory}/${lb_app_cert}.crt -days 730 -sha256 -extfile ${directory}/${lb_app_cert}.v3.ext >/dev/null 2>&1
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "api/v1/trust-management/certificates?action=import" \
                    "POST" \
                    "{\"display_name\": \"${display_name}-${lb_app_cert}\",
                      \"pem_encoded\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${lb_app_cert}.crt)\",
                      \"private_key\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${lb_app_cert}.key)\"
                    }"
        # vs creation
        /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/lb-virtual-servers/${display_name}-vs" \
                    "PUT" \
                    "{\"enabled\": true,
                      \"ip_address\": \"${nsx_vip_ip}\",
                      \"ports\": ${lb_vip_ports},
                      \"lb_persistence_profile_path\": \"${lb_persistence_profile_path}\",
                      \"lb_service_path\": \"${lb_path}\",
                      \"pool_path\": \"${pool_path}\",
                      \"application_profile_path\": \"${lb_application_profile_path}\",
                      \"client_ssl_profile_binding\": {
                        \"ssl_profile_path\": \"${lb_ssl_profile_path}\",
                        \"default_certificate_path\": \"/infra/certificates/${display_name}-${lb_app_cert}\",
                        \"client_auth\": \"IGNORE\",
                        \"certificate_chain_depth\": 3
                      },
                      \"resource_type\": \"LBVirtualServer\",
                      \"display_name\": \"${display_name}-vs\"
                    }"
        count=$((count+1))
      fi
    fi
  done
fi
#
# VM app connectivity first group
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_app_list} | jq -c -r '. | length')-1)))
    do
      ip_app="$(echo ${net_app_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
      # ssh check
      retry=60 ; pause=10 ; attempt=1
      while true ; do
        echo "attempt $attempt to verify VM app ${ip_app} is ready"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q "exit" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
          echo "VM app ${ip_app} is reachable."
          if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VM app '${ip_app}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
          break
        else
          echo "VM app ${ip_app} is not reachable."
        fi
        ((attempt++))
        if [ $attempt -eq $retry ]; then
          echo "VM app ${ip_app} is not reachable after $attempt attempt"
          break
        fi
        sleep $pause
      done
      echo "Ending timestamp: $(date)"
    done
  done
fi
#
# VM app connectivity second group
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${net_app_list} | jq -c -r '. | length'))
  do
    ip_app="$(echo ${net_app_list} | jq -r -c '.[0].cidr_three_octets').$(echo ${ips_app} | jq -c -r .[$(expr ${index} - 1)])"
    # ssh check
    retry=60 ; pause=10 ; attempt=1
    while true ; do
      echo "attempt $attempt to verify VM app ${ip_app} is ready"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_app}" -q "exit" >/dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "VM app ${ip_app} is reachable."
        if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': VM app '${ip_app}' reachable"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
        break
      else
        echo "VM app ${ip_app} is not reachable."
      fi
      ((attempt++))
      if [ $attempt -eq $retry ]; then
        echo "VM app ${ip_app} is not reachable after $attempt attempt"
        break
      fi
      sleep $pause
    done
    echo "Ending timestamp: $(date)"
  done
fi
#
# VM k8s_clusters check and config
#
if [[ ${k8s_clusters} != "null" ]]; then
  kube_increment_ip=0
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    total_node=2
    sed -e "s/\${total_node}/${total_node}/" \
        -e "s@\${SLACK_WEBHOOK_URL}@${SLACK_WEBHOOK_URL}@g" \
        -e "s@\${deployment_name}@${deployment_name}@" \
        -e "s/\${clusterName}/${k8s_basename}${index}/" /home/ubuntu/templates/K8s_check.sh.template | tee "/home/ubuntu/k8s/K8s_check_${k8s_basename}${index}.sh"
    for index_ip in $(seq 1 2)
    do
      kube_last_octet=$((kube_starting_ip+kube_increment_ip))
      ip_k8s_node="${cidr_vip_three_octets}.${kube_last_octet}"
      retry=60 ; pause=10 ; attempt=1
      while true ; do
        echo "attempt $attempt to verify VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} is ready"
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" -q "exit" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} is reachable."
          ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
          if [[ $? -eq 0 ]]; then
            echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} cloud init done."
            if [[ ${index_ip} -eq 1 ]]; then
              echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} is a master - transfer join command file to external gw /home/ubuntu/k8s/join-command-${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command" "/home/ubuntu/k8s/join-command-${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "/home/ubuntu/k8s/K8s_check_${k8s_basename}${index}.sh" ubuntu@${ip_k8s_node}:/home/ubuntu/K8s_check_${k8s_basename}${index}.sh
            else
              echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_k8s_node} is a worker - transfer join command file to worker and execute it to join the cluster ${k8s_basename}${index}"
              scp -o StrictHostKeyChecking=no "/home/ubuntu/k8s/join-command-${k8s_basename}${index}" "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command-${k8s_basename}${index}"
              ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo /bin/bash /home/ubuntu/join-command-${k8s_basename}${index}"
            fi
            break
          else
            echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}, ${ip_app}: cloud init is not finished."
          fi
        else
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip} is not reachable."
        fi
        ((attempt++))
        if [ $attempt -eq $retry ]; then
          echo "VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip} is not reachable after $attempt attempt"
          break
        fi
        sleep $pause
      done
      ((kube_increment_ip++))
    done
  done
fi
#
# VM k8s_clusters final check and k8s config file consolidation in the external gw
#
if [[ ${k8s_clusters} != "null" ]]; then
  #
  # html /home/ubuntu/k8s/vanilla-k8s.html
  #
  tee /home/ubuntu/k8s/vanilla-k8s.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Demo vanilla K8s</title>
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
<h1>Demo vanilla K8s</h1>
<ul>
EOT
  #
  #
  #
  kube_config_json="{\"apiVersion\": \"v1\"}"
  kube_increment_ip=0
  javascript_count=0
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    K8s_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].k8s_version')
    cni=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni')
    cni_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].cni_version')
    ako_version=$(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].ako_version')
    clusterName="${k8s_basename}${index}"
    #
    # html /home/ubuntu/k8s/vanilla-k8s.html
    #
    tee -a /home/ubuntu/k8s/vanilla-k8s.html> /dev/null <<EOT
    <li>${clusterName}</li>
    <br>
    <table>
        <tr>
            <th>K8s version</th>
            <td>${K8s_version}</td>
        </tr>
        <tr>
            <th>CNI</th>
            <td>${cni}</td>
        </tr>
        <tr>
            <th>CNI version</th>
            <td>${cni_version}</td>
        </tr>
        <tr>
            <th>Authenticate to the cluster</th>
            <td class="code-box">
    <pre><code>
k config use-context context${index}
    </code></pre>
<button onclick="copyToClipboard($((javascript_count)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Create namespaces and docker account</th>
            <td class="code-box">
    <pre><code>
k config use-context context${index}
/home/ubuntu/k8s/k8s-config.sh
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+1)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Enable cluster for gateway API</th>
            <td class="code-box">
    <pre><code>
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+2)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>AKO values Yaml</th>
            <td><a href="ako_${k8s_basename}${index}_values.yml" target="_blank">AKO values Yaml</a></td>
        </tr>
        <tr>
            <th>Install AKO via helm</th>
            <td class="code-box">
    <pre><code>
helm install --generate-name oci://projects.registry.vmware.com/ako/helm-charts/ako  --version ${ako_version} \\
-f /home/ubuntu/k8s/ako_${k8s_basename}${index}_values.yml --namespace=avi-system
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
    echo "Cluster ${index} check and k8s client config"
    for index_ip in $(seq 1 2)
    do
      kube_last_octet=$((kube_starting_ip+kube_increment_ip))
      ip_k8s_node="${cidr_vip_three_octets}.${kube_last_octet}"
      if [[ ${index_ip} -eq 1 ]]; then
        retry_count=0
        RETRY_DELAY_SECONDS=10
        MAX_RETRIES=6
        # Loop until file is found or max retries reached
        while true; do
          retry_count=$((retry_count + 1))
          ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /home/ubuntu/.kube/config" > /dev/null 2>&1
          if [[ $? -eq 0 ]]; then
            echo "  File /home/ubuntu/.kube/config found on ${ip_k8s_node} after $retry_count retries."
            scp -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}:/home/ubuntu/.kube/config" "/home/ubuntu/k8s/config-${k8s_basename}${index}"
            chmod 600 /home/ubuntu/k8s/config-${k8s_basename}${index}
            break
          else
            echo "  File /home/ubuntu/.kube/config not found on ${ip_k8s_node} after $retry_count retries."
            if [[ $retry_count -ge $MAX_RETRIES ]]; then
              echo "  Maximum retries reached. Exiting."
              break
            fi
            sleep $RETRY_DELAY_SECONDS
          fi
        done
        ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "/bin/bash /home/ubuntu/K8s_check_${k8s_basename}${index}.sh"
        cluster_certificate_authority_data=$(yq -c -r '.clusters[0].cluster."certificate-authority-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        cluster_server=$(yq -c -r '.clusters[0].cluster.server' /home/ubuntu/k8s/config-${k8s_basename}${index})
        name=${k8s_basename}${index}
        kube_config_json=$(echo ${kube_config_json} | jq '.clusters += [{"cluster": {"certificate-authority-data": "'$(echo $cluster_certificate_authority_data)'", "server": "'$(echo $cluster_server)'"}, "name": "'$(echo $name)'"}]')
        # contexts
        context_cluster=${k8s_basename}${index}
        context_user=user${index}
        name=context${index}
        kube_config_json=$(echo ${kube_config_json} | jq '.contexts += [{"context": {"cluster": "'$(echo $context_cluster)'", "user": "'$(echo $context_user)'"}, "name": "'$(echo $name)'"}]')
        # users
        name=user${index}
        user_client_certificate_data=$(yq -c -r '.users[0].user."client-certificate-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        user_client_key_data=$(yq -c -r '.users[0].user."client-key-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        kube_config_json=$(echo ${kube_config_json} | jq '.users += [{"user": {"client-certificate-data": "'$(echo $user_client_certificate_data)'", "client-key-data": "'$(echo $user_client_key_data)'"}, "name": "'$(echo $name)'"}]')
      fi
      ((kube_increment_ip++))
    done
  done
  #
  # html /home/ubuntu/k8s/vanilla-k8s.html
  #
  tee -a /home/ubuntu/k8s/vanilla-k8s.html> /dev/null <<EOT
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
  sudo cp /home/ubuntu/k8s/vanilla-k8s.html /var/www/html/
  echo "test1"
  echo ${kube_config_json}
  echo ${kube_config_json} | yq -y . | tee /home/ubuntu/k8s/config
  echo "test2"
  chmod 600 /home/ubuntu/k8s/config
  echo "Updating /home/ubuntu/.profile"
  contents=$(cat /home/ubuntu/.profile | grep -v KUBECONFIG=)
  echo "${contents}" | tee /home/ubuntu/.profile > /dev/null
  contents="export KUBECONFIG=/home/ubuntu/.kube/config:/home/ubuntu/k8s/config"
  echo "${contents}" | tee -a /home/ubuntu/.profile > /dev/null
fi