#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
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
      if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" && ${index} == 1 ]]; then
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
# NSX LB config
#
count=1
if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]] ; then
  echo ${segments_overlay} | jq -c -r .[] | while read item
  do
    if $(echo ${item} | jq -e '.lb' > /dev/null) ; then
      if [[ $(echo ${item} | jq -c -r '.lb') == "true" ]] ; then
        display_name="${nsx_lb_basename}-${count}"
        nsx_vip_ip="$(echo $item | jq -c -r .cidr_three_octets | cut -d'.' -f1-3).${nsx_vip_last_octet}"
        network_ref_app=$(echo ${segments_overlay} | jq -c -r '[.[] | select(.backend == true and keys[] | select(. != "server_preserve_ip"))] | first | .display_name')
        tier1_group_name=$(echo ${segments_overlay} | jq -c -r '[.[] | select(.backend == true and keys[] | select(. != "server_preserve_ip"))] | first | .tier1')
        nsx_lb_group_name="${nsx_group_app_name}_${network_ref_app}_${tier1_group_name}"
        # retrieve lb tier1_path
        file_json_output="/tmp/tier1_lb_path.json"
        json_key="t1_path"
        /bin/bash /home/ubuntu/nsx/retrieve_object_path.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                    "policy/api/v1/infra/tier-1s" \
                    "$(echo $item | jq -c -r .tier1)" \
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
                    "policy/api/v1/infra/certificates/${display_name}-${lb_app_cert}" \
                    "PATCH" \
                    "{\"display_name\": \"${display_name}-${lb_app_cert}\",
                      \"pem_encoded\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${lb_app_cert}.crt)\",
                      \"private_key\": \"$(awk '{printf "%s\\n", $0}' ${directory}/${lb_app_cert}.key)\",
                      \"passphrase\": \"$(cat ${directory}/ca_private_key_passphrase.txt)\"
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