#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# creating a content library
#
load_govc_env_with_cluster "${cluster_basename}1"
content_library_id=$(govc library.create ${avi_content_library_name})
for item in $(echo ${service_engine_groups} | jq -c -r .[].vcenter_folder)
do
  govc folder.create /${dc}/vm/${item}
done
#
# templating python control script
#
sed -e "s@\${webhook_url}@${SLACK_WEBHOOK_URL_AVI}@" /home/ubuntu/templates/avi_slack_cs.py.template | tee $(jq -c -r .avi_slack.path $jsonFile)
#
# templating yaml file
#
sed -e "s/\${controllerPrivateIp}/${ip_avi}/" \
    -e "s/\${ntp}/${gw_avi}/" \
    -e "s/\${dns}/${gw_avi}/" \
    -e "s/\${avi_password}/${GENERIC_PASSWORD}/" \
    -e "s/\${avi_old_password}/${AVI_OLD_PASSWORD}/" \
    -e "s/\${avi_version}/${avi_version}/" \
    -e "s/\${vsphere_username}/${vsphere_nested_username}@${ssoDomain}/" \
    -e "s/\${vsphere_password}/${vsphere_nested_password}/" \
    -e "s/\${vsphere_server}/${api_host}/" \
    -e "s/\${external_gw_ip}/${gw_avi}/" \
    -e "s/\${external_gw_se_ip}/${gw_avi_se}/" \
    -e "s@\${import_sslkeyandcertificate_ca}@${import_sslkeyandcertificate_ca}@" \
    -e "s@\${certificatemanagementprofile}@${certificatemanagementprofile}@" \
    -e "s@\${alertscriptconfig}@${alertscriptconfig}@" \
    -e "s@\${actiongroupconfig}@${actiongroupconfig}@" \
    -e "s@\${alertconfig}@${alertconfig}@" \
    -e "s@\${sslkeyandcertificate}@${sslkeyandcertificate}@" \
    -e "s@\${sslkeyandcertificate_ref}@${tanzu_cert_name}@" \
    -e "s@\${tenants}@${tenants}@" \
    -e "s@\${users}@${users}@" \
    -e "s@\${domain}@${avi_subdomain}.${domain}@" \
    -e "s@\${ipam}@${ipam}@" \
    -e "s@\${dc}@${dc}@" \
    -e "s@\${content_library_id}@${content_library_id}@" \
    -e "s@\${content_library_name}@${avi_content_library_name}@" \
    -e "s@\${networks}@${networks_avi}@" \
    -e "s@\${contexts}@${contexts}@" \
    -e "s@\${additional_subnets}@${additional_subnets}@" \
    -e "s@\${service_engine_groups}@${service_engine_groups}@" \
    -e "s@\${pools}@${pools}@" \
    -e "s@\${virtual_services}@${virtual_services}@" /home/ubuntu/templates/values_vcenter.yml.template | tee /home/ubuntu/avi/values_vcenter.yml
#
# starting ansible configuration
#