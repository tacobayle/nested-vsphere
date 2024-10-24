#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# ansible collection install vmware.alb
#
/home/ubuntu/.local/bin/ansible-galaxy collection install vmware.alb
#
# creating a content library and folder for seg
#
load_govc_env_with_cluster "${cluster_basename}1"
content_library_id=$(govc library.create ${avi_content_library_name})
for item in $(echo ${service_engine_groups} | jq -c -r .[].vcenter_folder)
do
  govc folder.create /${dc}/vm/${item}
done
#
# Avi HTTPS check
#
count=1
until $(curl --output /dev/null --silent --head -k https://${ip_avi})
do
  echo "  +++ Attempt ${count}: Waiting for Avi ctrl at https://${ip_avi} to be reachable..."
  sleep 10
  count=$((count+1))
    if [[ "${count}" -eq 60 ]]; then
      echo "  +++ ERROR: Unable to connect to Avi ctrl at https://${ip_avi}"
      exit
    fi
done
echo "Avi ctrl reachable at https://${ip_avi}"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl reachable at https://'${ip_avi}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# templating python control script
#
sed -e "s@\${webhook_url}@${SLACK_WEBHOOK_URL_AVI}@" /home/ubuntu/templates/avi_slack_cs.py.template | tee $(jq -c -r .avi_slack.path $jsonFile)
#
#
#
if [[ ${kind} == "vsphere-avi" ]]; then
  #
  # templating yaml file
  #
  sed -e "s/\${controllerPrivateIp}/${ip_avi}/" \
      -e "s/\${ntp}/${ip_gw_mgmt}/" \
      -e "s/\${dns}/${ip_gw_mgmt}/" \
      -e "s/\${avi_username}/${avi_username}/" \
      -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
      -e "s/\${avi_old_password}/${AVI_OLD_PASSWORD}/" \
      -e "s/\${avi_version}/${avi_version}/" \
      -e "s/\${vsphere_username}/${vsphere_nested_username}@${ssoDomain}/" \
      -e "s/\${vsphere_password}/${vsphere_nested_password}/" \
      -e "s/\${vsphere_server}/${api_host}/" \
      -e "s/\${external_gw_ip}/${ip_gw_mgmt}/" \
      -e "s@\${static_routes}@$(echo ${avi_static_routes} | jq -c -r .)@" \
      -e "s@\${import_sslkeyandcertificate_ca}@$(echo ${import_sslkeyandcertificate_ca} | jq -c -r '.')@" \
      -e "s@\${certificatemanagementprofile}@$(echo ${certificatemanagementprofile} | jq -c -r '.')@" \
      -e "s@\${alertscriptconfig}@$(echo ${alertscriptconfig} | jq -c -r '.')@" \
      -e "s@\${actiongroupconfig}@$(echo ${actiongroupconfig} | jq -c -r '.')@" \
      -e "s@\${alertconfig}@$(echo ${alertconfig} | jq -c -r '.')@" \
      -e "s@\${sslkeyandcertificate}@$(echo ${sslkeyandcertificate} | jq -c -r '.')@" \
      -e "s@\${sslkeyandcertificate_ref}@${tanzu_cert_name}@" \
      -e "s@\${applicationprofile}@$(echo ${applicationprofile} | jq -c -r '.')@" \
      -e "s@\${httppolicyset}@$(echo ${httppolicyset} | jq -c -r '.')@" \
      -e "s@\${roles}@$(echo ${roles} | jq -c -r '.')@" \
      -e "s@\${tenants}@$(echo ${tenants} | jq -c -r '.')@" \
      -e "s@\${users}@$(echo ${users} | jq -c -r '.')@" \
      -e "s@\${domain}@${avi_subdomain}.${domain}@" \
      -e "s@\${ipam}@$(echo ${ipam} | jq -c -r '.')@" \
      -e "s@\${dc}@${dc}@" \
      -e "s@\${content_library_id}@${content_library_id}@" \
      -e "s@\${content_library_name}@${avi_content_library_name}@" \
      -e "s@\${networks}@$(echo ${networks_avi} | jq -c -r '.')@" \
      -e "s@\${contexts}@$(echo ${contexts} | jq -c -r '.')@" \
      -e "s@\${additional_subnets}@$(echo ${additional_subnets} | jq -c -r '.')@" \
      -e "s@\${service_engine_groups}@$(echo ${service_engine_groups} | jq -c -r '.')@" \
      -e "s@\${pools}@$(echo ${pools} | jq -c -r '.')@" \
      -e "s@\${pool_groups}@$(echo ${pool_groups} | jq -c -r '.')@" \
      -e "s@\${virtual_services}@$(echo ${virtual_services} | jq -c -r '.')@" /home/ubuntu/templates/values_vcenter.yml.template | tee /home/ubuntu/avi/avi_values.yml
fi
if [[ ${kind} == "vsphere-nsx-avi" ]]; then
  #
  # patching certificatemanagementprofile with vault token
  #
  certificatemanagementprofile=$(echo ${certificatemanagementprofile} | jq '.[0].script_params[2] += {"value": "'$(jq -c -r '.root_token' ${vault_secret_file_path})'"}')
  #
  # Network mgmt
  #
  network_management=$(echo ${segments_overlay} | jq -c -r '.[] | select( .avi_mgmt == true)')
  #
  # templating yaml file
  #
  sed -e "s/\${controllerPrivateIp}/${ip_avi}/" \
      -e "s/\${ntp}/${ip_gw_mgmt}/" \
      -e "s/\${dns}/${ip_gw_mgmt}/" \
      -e "s/\${avi_username}/${avi_username}/" \
      -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
      -e "s/\${avi_old_password}/${AVI_OLD_PASSWORD}/" \
      -e "s/\${avi_version}/${avi_version}/" \
      -e "s/\${nsx_username}/${nsx_username}/" \
      -e "s/\${nsx_password}/${GENERIC_PASSWORD}/" \
      -e "s/\${nsx_server}/${ip_nsx}/" \
      -e "s/\${vsphere_username}/${vsphere_nested_username}@${ssoDomain}/" \
      -e "s/\${vsphere_password}/${vsphere_nested_password}/" \
      -e "s/\${vsphere_server}/${api_host}/" \
      -e "s/\${external_gw_ip}/${ip_gw_mgmt}/" \
      -e "s@\${import_sslkeyandcertificate_ca}@$(echo ${import_sslkeyandcertificate_ca} | jq -c -r '.')@" \
      -e "s@\${certificatemanagementprofile}@$(echo ${certificatemanagementprofile} | jq -c -r '.')@" \
      -e "s@\${alertscriptconfig}@$(echo ${alertscriptconfig} | jq -c -r '.')@" \
      -e "s@\${actiongroupconfig}@$(echo ${actiongroupconfig} | jq -c -r '.')@" \
      -e "s@\${alertconfig}@$(echo ${alertconfig} | jq -c -r '.')@" \
      -e "s@\${sslkeyandcertificate}@$(echo ${sslkeyandcertificate} | jq -c -r '.')@" \
      -e "s@\${sslkeyandcertificate_ref}@${tanzu_cert_name}@" \
      -e "s@\${applicationprofile}@$(echo ${applicationprofile} | jq -c -r '.')@" \
      -e "s@\${httppolicyset}@$(echo ${httppolicyset} | jq -c -r '.')@" \
      -e "s@\${roles}@$(echo "${roles}" | jq -c -r '.')@" \
      -e "s@\${tenants}@$(echo "${tenants}" | jq -c -r '.')@" \
      -e "s@\${users}@$(echo "${users}" | jq -c -r '.')@" \
      -e "s@\${cloud_name}@${nsx_cloud_name}@" \
      -e "s@\${cloud_obj_name_prefix}@${cloud_obj_name_prefix}@" \
      -e "s@\${domain}@${avi_subdomain}.${domain}@" \
      -e "s@\${transport_zone_name}@$(echo ${transport_zones} | jq -c -r '.[] | select(.transport_type == "OVERLAY").display_name')@" \
      -e "s@\${network_management}@${network_management}@" \
      -e "s@\${networks_data}@$(echo ${net_client_list} | jq -c -r '.')@" \
      -e "s@\${content_library_name}@${avi_content_library_name}@" \
      -e "s@\${service_engine_groups}@$(echo "${service_engine_groups}" | jq -c -r '.')@" \
      -e "s@\${pools}@$(echo ${pools} | jq -c -r '.')@" \
      -e "s@\${pool_groups}@$(echo ${pool_groups} | jq -c -r '.')@" \
      -e "s@\${virtual_services}@$(echo ${virtual_services} | jq -c -r '.')@" /home/ubuntu/templates/values_nsx.yml.template | tee /home/ubuntu/avi/avi_values.yml
fi
#
# starting ansible configuration
#
cd avi
git clone ${avi_config_repo} --branch ${tag}
cd $(basename ${avi_config_repo})
echo '---' | tee hosts_avi
echo 'all:' | tee -a hosts_avi
echo '  children:' | tee -a hosts_avi
echo '    controller:' | tee -a hosts_avi
echo '      hosts:' | tee -a hosts_avi
echo '        '${ip_avi}':' | tee -a hosts_avi
/home/ubuntu/.local/bin/ansible-playbook -i hosts_avi ${playbook} --extra-vars @/home/ubuntu/avi/avi_values.yml
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl '${ip_app}' has been configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# traffic gen from gw
#
sed -e "s/\${controllerPrivateIp}/${ip_avi}/" \
    -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
    -e "s/\${avi_username}/admin/" /home/ubuntu/templates/traffic_gen_gw.sh.template | tee /home/ubuntu/avi/traffic_gen_gw.sh
chmod u+x /home/ubuntu/avi/traffic_gen_gw.sh
crontab -l 2>/dev/null; echo "* * * * * /home/ubuntu/avi/traffic_gen_gw.sh" | crontab -
#
# traffic gen from clients
#
sed -e "s/\${controllerPrivateIp}/${ip_avi}/" \
    -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
    -e "s/\${avi_username}/admin/" /home/ubuntu/templates/traffic_gen_client.sh.template | tee /home/ubuntu/avi/traffic_gen_client.sh
chmod u+x /home/ubuntu/avi/traffic_gen_client.sh
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    for net in $(seq 0 $(($(echo ${net_client_list} | jq -c -r '. | length')-1)))
    do
      ip_client="$(echo ${net_client_list} | jq -r -c '.['${net}'].cidr_three_octets').$(echo ${ips_clients} | jq -c -r .[$(expr ${index} - 1)])"
      scp -o StrictHostKeyChecking=no /home/ubuntu/json/loopback_ips.json ubuntu@${ip_client}:/home/ubuntu/loopback_ips.json
      scp -o StrictHostKeyChecking=no /home/ubuntu/json/user_agents.json ubuntu@${ip_client}:/home/ubuntu/user_agents.json
      ssh -o StrictHostKeyChecking=no ubuntu@${ip_client} "jq -c -r '.[]' /home/ubuntu/loopback_ips.json | while read ip ; do sudo ip a add \$ip dev lo: ; done"
      scp -o StrictHostKeyChecking=no /home/ubuntu/avi/traffic_gen_client.sh ubuntu@${ip_client}:/home/ubuntu/traffic_gen_client.sh
      ssh -o StrictHostKeyChecking=no ubuntu@${ip_client} 'crontab -l 2>/dev/null; echo "* * * * * /home/ubuntu/traffic_gen_client.sh" | crontab -'
    done
  done
fi