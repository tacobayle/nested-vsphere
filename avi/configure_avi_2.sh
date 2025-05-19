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
content_library_id=$(govc library.create ${avi_content_library_name_2})
for item in $(echo ${service_engine_groups} | jq -c -r .[].vcenter_folder)
do
  govc folder.create /${dc}/vm/${item}
done
#
# Avi HTTPS check
#
count=1
until $(curl --output /dev/null --silent --head -k https://${ip_avi_2})
do
  echo "  +++ Attempt ${count}: Waiting for Avi ctrl2 at https://${ip_avi_2} to be reachable..."
  sleep 10
  count=$((count+1))
    if [[ "${count}" -eq 60 ]]; then
      echo "  +++ ERROR: Unable to connect to Avi ctrl2 at https://${ip_avi_2}"
      exit
    fi
done
echo "Avi ctrl2 reachable at https://${ip_avi_2}"
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl2 reachable at https://'${ip_avi_2}'"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
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
  sed -e "s/\${controllerPrivateIp}/${ip_avi_2}/" \
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
      -e "s@\${vsdatascriptset}@$(echo ${vsdatascriptset} | jq -c -r '.')@" \
      -e "s@\${httppolicyset}@$(echo ${httppolicyset} | jq -c -r '.')@" \
      -e "s@\${roles}@$(echo ${roles} | jq -c -r '.')@" \
      -e "s@\${tenants}@$(echo ${tenants} | jq -c -r '.')@" \
      -e "s@\${users}@$(echo ${users} | jq -c -r '.')@" \
      -e "s@\${domain}@${avi_subdomain}.${domain}@" \
      -e "s@\${ipam}@$(echo ${ipam} | jq -c -r '.')@" \
      -e "s@\${dc}@${dc}@" \
      -e "s@\${content_library_id}@${content_library_id}@" \
      -e "s@\${content_library_name}@${avi_content_library_name_2}@" \
      -e "s@\${networks}@$(echo ${networks_avi} | jq -c -r '.')@" \
      -e "s@\${contexts}@$(echo ${contexts} | jq -c -r '.')@" \
      -e "s@\${additional_subnets}@$(echo ${additional_subnets} | jq -c -r '.')@" \
      -e "s@\${service_engine_groups}@$(echo ${service_engine_groups} | jq -c -r '.')@" \
      -e "s@\${pools}@$(echo ${pools} | jq -c -r '.')@" \
      -e "s@\${pool_groups}@$(echo ${pool_groups} | jq -c -r '.')@" \
      -e "s@\${virtual_services}@$(echo ${virtual_services} | jq -c -r '.')@" /home/ubuntu/templates/values_vcenter.yml.template | tee /home/ubuntu/avi/avi_values.yml
fi
#
# starting ansible configuration
#
cd avi
git clone ${avi_config_repo} --branch ${tag}
cd $(basename ${avi_config_repo})
echo '---' | tee hosts_avi_2
echo 'all:' | tee -a hosts_avi_2
echo '  children:' | tee -a hosts_avi_2
echo '    controller:' | tee -a hosts_avi_2
echo '      hosts:' | tee -a hosts_avi_2
echo '        '${ip_avi_2}':' | tee -a hosts_avi_2
/home/ubuntu/.local/bin/ansible-playbook -i hosts_avi_2 ${playbook} --extra-vars @/home/ubuntu/avi/avi_values.yml
if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', '${deployment_name}': Avi ctrl2 '${ip_avi_2}' has been configured"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
#
# traffic gen from gw
#
sed -e "s/\${controllerPrivateIp}/${ip_avi_2}/" \
    -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
    -e "s/\${avi_username}/admin/" /home/ubuntu/templates/traffic_gen_client.sh.template | tee /home/ubuntu/avi/traffic_gen_client.sh
chmod u+x /home/ubuntu/avi/traffic_gen_client.sh
jq -c -r '.[]' /home/ubuntu/json/loopback_ips.json | while read ip ; do sudo ip a add ${ip} dev lo: ; done
crontab -l 2>/dev/null; echo "* * * * * /home/ubuntu/avi/traffic_gen_client.sh" | crontab -