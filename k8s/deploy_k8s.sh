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
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "ERROR: unable to connect to vCenter"
  exit
fi
#
#
#
if [[ ${k8s_clusters} != "null" ]]; then
  #
  kube_increment_ip=0
  list_folder=$(govc find -json . -type f)
  #
  gslb_members_json="{}"
  gslb_members_json=$(echo ${gslb_members_json} | jq '. += {"apiVersion": "v1"}')
  gslb_members_json=$(echo ${gslb_members_json} | jq '. += {"clusters": []}')
  gslb_members_json=$(echo ${gslb_members_json} | jq '. += {"contexts": []}')
  gslb_members_json=$(echo ${gslb_members_json} | jq '. += {"users": []}')
  #
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    #
    # folder creation for k8s cluster
    #
    if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${k8s_basename}${index}'")' >/dev/null ) ; then
      echo "ERROR: unable to create folder ${k8s_basename}${index}: it already exists"
    else
      govc folder.create /${dc}/vm/${k8s_basename}${index}
      echo "Ending timestamp: $(date)"
    fi
    #
    # VM k8s_clusters creation
    #
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
    #
    # ako values templating
    #
    serviceEngineGroupName="Default-Group"
    shardVSSize="SMALL"
    serviceType="ClusterIP"
    disableStaticRouteSync="false" # needs to be true if NodePortLocal is enabled
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
    #
    # amko_gslb_member_file
    #
    # clusters
    cluster_certificate_authority_data=$(/home/ubuntu/.local/bin/yq -c -r '.clusters[0].cluster."certificate-authority-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    cluster_server=$(/home/ubuntu/.local/bin/yq -c -r '.clusters[0].cluster.server' /home/ubuntu/k8s/config-${k8s_basename}${index})
    cluster_name=${k8s_basename}${index}
    gslb_members_json=$(echo $gslb_members_json | jq '.clusters += [{"cluster": {"certificate-authority-data": "'${cluster_certificate_authority_data}'", "server": "'${cluster_server}'"}, "name": "'${cluster_name}'"}]')
    # contexts
    context_user=user0${index}
    context_name=context0${index}
    gslb_members_json=$(echo $gslb_members_json | jq '.contexts += [{"context": {"cluster": "'${cluster_name}'", "user": "'${context_user}'"}, "name": "'${context_name}'"}]')
    # users
    user_name=user0${index}
    user_client_certificate_data=$(/home/ubuntu/.local/bin/yq -c -r '.users[0].user."client-certificate-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    user_client_key_data=$(/home/ubuntu/.local/bin/yq -c -r '.users[0].user."client-key-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
    gslb_members_json=$(echo $gslb_members_json | jq '.users += [{"user": {"client-certificate-data": "'${user_client_certificate_data}'", "client-key-data": "'${user_client_key_data}'"}, "name": "'${user_name}'"}]')
    #
    # values_amko.yml
    #
    values_amko="{}"
    values_amko=$(echo ${values_amko} | jq '. += {"replicaCount": 1}')
    values_amko=$(echo ${values_amko} | jq '. += {"image": {"repository": "'${image_repo_amko}'", "pullPolicy": "IfNotPresent"}}')
    values_amko=$(echo ${values_amko} | jq '. += {"federation": {"image": {"repository": "'${image_repo_amko_federator}'", "pullPolicy": "IfNotPresent"}}}')
    values_amko=$(echo ${values_amko} | jq '.federation += {"currentCluster": "context0'${index}'"}')
    if [[ ${index} -eq 1 ]] ; then currentClusterIsLeader=true ; else currentClusterIsLeader=false; fi
    values_amko=$(echo ${values_amko} | jq '.federation += {"currentClusterIsLeader": '$(echo $currentClusterIsLeader)'}')
    values_amko=$(echo ${values_amko} | jq '.federation += {"memberClusters": []}')
    #
    for index_member_clusters in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
    do
      values_amko=$(echo ${values_amko} | jq '.federation.memberClusters += [ "context0'${index_member_clusters}'"]')
    done
    values_amko=$(echo ${values_amko} | jq '. += {"serviceDiscovery": {"image": {"repository": "'${image_repo_amko_service_discovery}'", "pullPolicy": "IfNotPresent"}}}')
    values_amko=$(echo ${values_amko} | jq '. += {"multiClusterIngress": {"enable": false}}')
    values_amko=$(echo ${values_amko} | jq '. += {"replicaCount": 1}')
    # .configs
    values_amko=$(echo ${values_amko} | jq '. += {"configs": {"gslbLeaderController": "'${ip_avi}'"}}')
    values_amko=$(echo ${values_amko} | jq '.configs += {"controllerVersion": "'${avi_version}'"}')
    values_amko=$(echo ${values_amko} | jq '.configs += {"memberClusters": []}')
    for index_member_clusters in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
    do
      values_amko=$(echo ${values_amko} | jq '.configs.memberClusters += [ {"clusterContext": "context0'${index_member_clusters}'"}]')
    done
    values_amko=$(echo ${values_amko} | jq '.configs += {"refreshInterval": 1800}')
    values_amko=$(echo ${values_amko} | jq '.configs += {"logLevel": "INFO"}')
    values_amko=$(echo ${values_amko} | jq '.configs += {"logLevel": "INFO"}')
    values_amko=$(echo ${values_amko} | jq '.configs += {"useCustomGlobalFqdn": true}')
    # .gslbLeaderCredentials
    values_amko=$(echo ${values_amko} | jq '. += {"gslbLeaderCredentials": {"username": "admin"}}')
    values_amko=$(echo ${values_amko} | jq '.gslbLeaderCredentials += {"password": "'${GENERIC_PASSWORD}'"}')
    # .globalDeploymentPolicy
    values_amko=$(echo ${values_amko} | jq '. += {"globalDeploymentPolicy": {"appSelector": {"label": {"app": "'${amko_app_selector}'"}}}}')
    values_amko=$(echo ${values_amko} | jq '.globalDeploymentPolicy += {"matchClusters": []}')
    for index_member_clusters in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
    do
      values_amko=$(echo ${values_amko} | jq '.globalDeploymentPolicy.matchClusters += [ {"cluster": "context0'${index_member_clusters}'"}]')
    done
    # .serviceAccount
    values_amko=$(echo ${values_amko} | jq '. += {"serviceAccount": {"create": true}}')
    values_amko=$(echo ${values_amko} | jq '.serviceAccount += {"annotations": {}}')
    values_amko=$(echo ${values_amko} | jq '.serviceAccount += {"name": ""}')
    # .resources
    values_amko=$(echo ${values_amko} | jq '. += {"resources": {"limits": {"cpu": "250m", "memory": "300Mi"}}}')
    values_amko=$(echo ${values_amko} | jq '.resources += {"requests": {"cpu": "100m", "memory": "200Mi"}}')
    # .service
    values_amko=$(echo ${values_amko} | jq '. += {"service": {"type": "ClusterIP", "port": 80}}')
    # .rbac
    values_amko=$(echo ${values_amko} | jq '. += {"rbac": {"pspEnable": false}}')
    # .persistentVolumeClaim
    values_amko=$(echo ${values_amko} | jq '. += {"persistentVolumeClaim": ""}')
    # .mountPath
    values_amko=$(echo ${values_amko} | jq '. += {"mountPath": "/log"}')
    # .logFile
    values_amko=$(echo ${values_amko} | jq '. += {"logFile": "amko.log"}')
    # .federatorLogFile
    values_amko=$(echo ${values_amko} | jq '. += {"federatorLogFile": "amko-federator.log"}')
    #
    echo ${values_amko} | /home/ubuntu/.local/bin/yq -y . | tee /home/ubuntu/k8s/values_amko_${k8s_basename}${index}.yml > /dev/null
    #
    # ingress
    #
    per_cluster_ingress='{"apiVersion":"networking.k8s.io/v1","kind":"Ingress","metadata":{"name":"ingress-'${k8s_basename}${index}'","labels":{"app":"'${amko_app_selector}'"}},"spec":{"rules":[{"host":"ingress-'${k8s_basename}${index}'.'${avi_subdomain}'.'${domain}'","http":{"paths":[{"pathType":"Prefix","path":"/","backend":{"service":{"name":"svc-v1","port":{"number":80}}}}]}}]}}'
    echo ${per_cluster_ingress} | /home/ubuntu/.local/bin/yq -y . | tee /home/ubuntu/yaml-files/ingress-'${k8s_basename}${index}'.yml > /dev/null
    #
    # GSLB CRD
    #
    ingress_global_fqdn='{"apiVersion":"ako.vmware.com/v1alpha1","kind":"HostRule","metadata":{"name":"my-host-rule1","namespace":"default"},"spec":{"virtualhost":{"fqdn":"ingress-'${k8s_basename}${index}'.'${avi_subdomain}'.'${domain}'","enableVirtualHost":true,"wafPolicy":"System-WAF-Policy","tls":{"sslKeyCertificate":{"name":"System-Default-Cert-EC","type":"ref"}},"gslb":{"fqdn":"ingress.'${avi_gslb_subdomain}'.'${domain}'","includeAliases":false}}}}'
    echo ${ingress_global_fqdn} | /home/ubuntu/.local/bin/yq -y . | tee /home/ubuntu/yaml-files/ingress-global-fqdn.yml > /dev/null
  done
fi
echo ${gslb_members_json} | /home/ubuntu/.local/bin/yq -y . | tee ${amko_gslb_member_file_path} > /dev/null
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
k config use-context context${index}
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
k config use-context context${index}
helm install --generate-name ${helm_url}  --version ${ako_version} \\
-f /home/ubuntu/k8s/ako_${k8s_basename}${index}_values.yml --namespace=avi-system
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+3)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Install AMKO via helm</th>
            <td class="code-box">
    <pre><code>
# Make sure GSLB is enabled with ${avi_gslb_subdomain}.${domain}
k config use-context context${index}
k create secret generic gslb-config-secret --from-file ${amko_gslb_member_file_path} -n avi-system
helm install --generate-name ${helm_url_amko} --version 1.13.1 \\
-f /home/ubuntu/k8s/values_amko_${k8s_basename}${index}.yml  --namespace=avi-system
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+4)))">Copy Code</button>
            </td>
        </tr>
    </table>
    <br>
    <br>
EOT
    javascript_count=$((javascript_count+5))
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
        echo "check file"
        ls /home/ubuntu/k8s/config-${k8s_basename}${index}
        # clusters
        cluster_certificate_authority_data=$(/home/ubuntu/.local/bin/yq -c -r '.clusters[0].cluster."certificate-authority-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        cluster_server=$(/home/ubuntu/.local/bin/yq -c -r '.clusters[0].cluster.server' /home/ubuntu/k8s/config-${k8s_basename}${index})
        name=${k8s_basename}${index}
        kube_config_json=$(echo ${kube_config_json} | jq '.clusters += [{"cluster": {"certificate-authority-data": "'${cluster_certificate_authority_data}'", "server": "'${cluster_server}'"}, "name": "'${name}'"}]')
        echo "check clusters"
        echo ${cluster_certificate_authority_data}
        echo ${cluster_server}
        echo ${name}
        echo ${kube_config_json}
        # contexts
        context_cluster=${k8s_basename}${index}
        context_user=user${index}
        name=context${index}
        kube_config_json=$(echo ${kube_config_json} | jq '.contexts += [{"context": {"cluster": "'${context_cluster}'", "user": "'${context_user}'"}, "name": "'${name}'"}]')
        echo "check contexts"
        echo ${context_cluster}
        echo ${context_user}
        echo ${name}
        echo ${kube_config_json}
        # users
        name=user${index}
        user_client_certificate_data=$(/home/ubuntu/.local/bin/yq -c -r '.users[0].user."client-certificate-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        user_client_key_data=$(/home/ubuntu/.local/bin/yq -c -r '.users[0].user."client-key-data"' /home/ubuntu/k8s/config-${k8s_basename}${index})
        kube_config_json=$(echo ${kube_config_json} | jq '.users += [{"user": {"client-certificate-data": "'${user_client_certificate_data}'", "client-key-data": "'${user_client_key_data}'"}, "name": "'${name}'"}]')
        echo "check users"
        echo ${user_client_certificate_data}
        echo ${user_client_key_data}
        echo ${name}
        echo ${kube_config_json}
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
  echo ${kube_config_json}
  echo ${kube_config_json} | /home/ubuntu/.local/bin/yq -y . | tee /home/ubuntu/k8s/config
  chmod 600 /home/ubuntu/k8s/config
  echo "Updating /home/ubuntu/.profile"
  contents=$(cat /home/ubuntu/.profile | grep -v KUBECONFIG=)
  echo "${contents}" | tee /home/ubuntu/.profile > /dev/null
  contents="export KUBECONFIG=/home/ubuntu/.kube/config:/home/ubuntu/k8s/config"
  echo "${contents}" | tee -a /home/ubuntu/.profile > /dev/null
fi