#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
#
#
if [[ ${openshift} != "null" ]]; then
  javascript_count=0
  tar -xvf /home/ubuntu/bin/$(basename ${openshift_installer_url}) -C /home/ubuntu/openshift
  sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
      -e "s/\${domain}/${domain}/" \
      -e "s/\${openshift_api_ip}/${openshift_api_ip}/" \
      -e "s/\${api_host}/${api_host}/" \
      -e "s/\${openshift_ingress_ip}/${openshift_ingress_ip}/" \
      -e "s/\${dc}/${dc}/" \
      -e "s/\${cluster_basename}/${cluster_basename}/" \
      -e "s@\${network_ref_vip}@${network_ref_vip}@" \
      -e "s@\${gw_client}@${gw_client}@" \
      -e "s@\${cidr_vip_full}@${cidr_vip_full}@" \
      -e "s@\${prefix_client}@${prefix_client}@" \
      -e "s@\${ip_node1}@${cidr_vip_three_octets}.${openshift_node_starting_ip_last_octet}@" \
      -e "s@\${ip_node2}@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1))@" \
      -e "s@\${ip_node3}@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2))@" \
      -e "s@\${ip_node4}@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3))@" \
      -e "s@\${ip_node5}@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+4))@" \
      -e "s@\${vsphere_nested_username}@${vsphere_nested_username}@" \
      -e "s@\${ssoDomain}@${ssoDomain}@" \
      -e "s/\${GENERIC_PASSWORD}/${GENERIC_PASSWORD}/" \
      -e "s#\${CLOUD_OPENSHIFT_COM_AUTH}#${CLOUD_OPENSHIFT_COM_AUTH}#" \
      -e "s#\${CLOUD_OPENSHIFT_COM_EMAIL}#${CLOUD_OPENSHIFT_COM_EMAIL}#" \
      -e "s#\${QUAY_IO_AUTH}#${QUAY_IO_AUTH}#" \
      -e "s#\${QUAY_IO_EMAIL}#${QUAY_IO_EMAIL}#" \
      -e "s#\${REGISTRY_CONNECT_REDHAT_COM_AUTH}#${REGISTRY_CONNECT_REDHAT_COM_AUTH}#" \
      -e "s#\${REGISTRY_CONNECT_REDHAT_COM_EMAIL}#${REGISTRY_CONNECT_REDHAT_COM_EMAIL}#" \
      -e "s#\${REGISTRY_REDHAT_IO_AUTH}#${REGISTRY_REDHAT_IO_AUTH}#" \
      -e "s#\${REGISTRY_REDHAT_IO_EMAIL}#${REGISTRY_REDHAT_IO_EMAIL}#" /home/ubuntu/templates/install-config.yaml.template | tee "/home/ubuntu/openshift/install-config.yaml"
  cp /home/ubuntu/openshift/install-config.yaml /home/ubuntu/openshift/install-config.yaml.archive
  /home/ubuntu/openshift/openshift-install create cluster --dir /home/ubuntu/openshift --log-level info
  echo "Updating /home/ubuntu/.profile"
  contents=$(cat /home/ubuntu/.profile | grep -v KUBECONFIG=)
  echo "${contents}" | tee /home/ubuntu/.profile > /dev/null
  contents="export KUBECONFIG=/home/ubuntu/.kube/config:/home/ubuntu/k8s/config:/home/ubuntu/openshift/auth/kubeconfig"
  echo "${contents}" | tee -a /home/ubuntu/.profile > /dev/null
  # copy kube config to the hosts
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "mkdir .kube"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)) "mkdir .kube"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)) "mkdir .kube"
  scp /home/ubuntu/openshift/auth/kubeconfig core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)):/var/home/core/.kube/config
  scp /home/ubuntu/openshift/auth/kubeconfig core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)):/var/home/core/.kube/config
  scp /home/ubuntu/openshift/auth/kubeconfig core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)):/var/home/core/.kube/config
  # copy yaml-files directory
  scp -r /home/ubuntu/${yaml_folder} core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)):/var/home/core
  scp -r /home/ubuntu/${yaml_folder} core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)):/var/home/core
  scp -r /home/ubuntu/${yaml_folder} core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)):/var/home/core
  # openshift credentials
  openshift_admin_username="kubeadmin"
  openshift_admin_password=$(cat /home/ubuntu/openshift/auth/kubeadmin-password)
  openshift_console_url=$(ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "oc get route console -n openshift-console -o json | /usr/bin/jq -c -r '.spec.host'")
  # patching ntp
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "sudo mv /etc/chrony.conf /etc/chrony.conf.old"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)) "sudo mv /etc/chrony.conf /etc/chrony.conf.old"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)) "sudo mv /etc/chrony.conf /etc/chrony.conf.old"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+4)) "sudo mv /etc/chrony.conf /etc/chrony.conf.old"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "cat /etc/chrony.conf.old | grep -v pool | sudo tee /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)) "cat /etc/chrony.conf.old | grep -v pool | sudo tee /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)) "cat /etc/chrony.conf.old | grep -v pool | sudo tee /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+4)) "cat /etc/chrony.conf.old | grep -v pool | sudo tee /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "echo pool ${gw_client} iburst | sudo tee -a /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)) "echo pool ${gw_client} iburst | sudo tee -a /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)) "echo pool ${gw_client} iburst | sudo tee -a /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+4)) "echo pool ${gw_client} iburst | sudo tee -a /etc/chrony.conf"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "sudo systemctl restart chronyd.service"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+2)) "sudo systemctl restart chronyd.service"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+3)) "sudo systemctl restart chronyd.service"
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+4)) "sudo systemctl restart chronyd.service"
  # patching OpenShift logging retention delay
  scp /home/ubuntu/yaml-files/logging.yaml core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)):/var/home/core/logging.yaml
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "oc apply -f /var/home/core/logging.yaml"
  #
  # AKO values
  #
  shardVSSize="SMALL"
  serviceType="ClusterIP"
  disableStaticRouteSync="false" # needs to be true if NodePortLocal is enabled
  if [[ ${kind} == "vsphere-avi" ]]; then
    nsxtT1LR="''"
    avi_cloud_name="Default-Cloud"
  fi
  sed -e "s/\${disableStaticRouteSync}/${disableStaticRouteSync}/" \
      -e "s/\${clusterName}/${openshift_cluster_name}/" \
      -e "s/\${cniPlugin}/${openshift_cni}/" \
      -e "s@\${nsxtT1LR}@${nsxtT1LR}@" \
      -e "s/\${networkName}/${network_ref_vip}/" \
      -e "s@\${cidr}@${cidr_vip_full}@" \
      -e "s/\${serviceType}/${serviceType}/" \
      -e "s/\${shardVSSize}/${shardVSSize}/" \
      -e "s/\${serviceEngineGroupName}/${openshift_seg_name}/" \
      -e "s/\${controllerVersion}/${avi_version}/" \
      -e "s/\${cloudName}/${avi_cloud_name}/" \
      -e "s/\${controllerHost}/${ip_avi}/" \
      -e "s/\${tenant}/${openshift_tenant_name}/" \
      -e "s/\${password}/${GENERIC_PASSWORD}/" /home/ubuntu/templates/values_api_gw.yml.${openshift_ako_version}.template | tee /home/ubuntu/openshift/ako_${openshift_cluster_name}_${openshift_ako_version}_values.yml > /dev/null
  sudo cp /home/ubuntu/openshift/ako_${openshift_cluster_name}_${openshift_ako_version}_values.yml /var/www/html/
  #
  # openshift config file
  #
  sed -e "s/\${openshift_cluster_name}/${openshift_cluster_name}/" \
      -e "s/\${avi_subdomain}/${avi_subdomain}/" \
      -e "s/\${domain}/${domain}/" \
      -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
      -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" \
      -e "s/\${docker_registry_email}/${DOCKER_REGISTRY_EMAIL}/" /home/ubuntu/templates/openshift-config.sh.template | tee /home/ubuntu/openshift/openshift-config.sh > /dev/null
  scp /home/ubuntu/openshift/openshift-config.sh core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)):/var/home/core/openshift-config.sh
  ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "chmod u+x /var/home/core/openshift-config.sh"
  #
  # html /home/ubuntu/openshift/openshift.html
  #
  if [[ ! ( -v openshift_admin_password && -n "${openshift_admin_password}" && -v openshift_console_url && -n "${openshift_console_url}" ) ]]; then
    echo "openshift vars undefined: openshift_admin_password, openshift_console_url"
  else
    curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': openshift is up - console url is '${openshift_console_url}'"}' ${SLACK_WEBHOOK_URL}
    tee /home/ubuntu/openshift/openshift.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Demo OpenShift</title>
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
<h1>Demo OpenShift</h1>
<ul>
    <li>${openshift_cluster_name}</li>
    <br>
    <table>
        <tr>
            <th>OpenShift Username</th>
            <td>${openshift_admin_username}</td>
        </tr>
        <tr>
            <th>OpenShift Password</th>
            <td>${openshift_admin_password}</td>
        </tr>
        <tr>
            <th>OpenShift Console url</th>
            <td>https://${openshift_console_url}</td>
        </tr>
        <tr>
            <th>Configure OpenShift Cluster with SSL and docker account</th>
            <td class="code-box">
    <pre><code>
ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "/var/home/core/openshift-config.sh"
    </code></pre>
<button onclick="copyToClipboard($((javascript_count)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>Enable cluster for gateway API</th>
            <td class="code-box">
    <pre><code>
ssh -o StrictHostKeyChecking=no core@${cidr_vip_three_octets}.$((openshift_node_starting_ip_last_octet+1)) "oc apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+1)))">Copy Code</button>
            </td>
        </tr>
        <tr>
            <th>AKO values Yaml</th>
            <td><a href="ako_${openshift_cluster_name}_values.yml" target="_blank">AKO values Yaml</a></td>
        </tr>
        <tr>
            <th>Install AKO via helm</th>
            <td class="code-box">
    <pre><code>
k config use-context admin
helm install --generate-name oci://projects.registry.vmware.com/ako/helm-charts/ako  --version ${openshift_ako_version} \\
-f /home/ubuntu/openshift/ako_${openshift_cluster_name}_values.yml --namespace=avi-system
    </code></pre>
<button onclick="copyToClipboard($((javascript_count+2)))">Copy Code</button>
            </td>
        </tr>
    </table>
    <br>
    <br>
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
  fi
  sudo cp /home/ubuntu/openshift/openshift.html /var/www/html/
fi