#!/bin/bash
#
source /home/ubuntu/nsx/nsx_api.sh
#
nsx_nested_ip=${1}
nsx_password=${2}
vcenter_username=${3}
vcenter_domain=${4}
vcenter_fqdn=${5}
vcenter_password=${6}
#
cookies_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_cookie.txt"
headers_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_header.txt"
/bin/bash /home/ubuntu/nsx/create_nsx_api_session.sh admin ${nsx_password} ${nsx_nested_ip} ${cookies_file} ${headers_file}
ValidCmThumbPrint=$(openssl s_client -connect $vcenter_fqdn:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout -in /dev/stdin | awk -F'Fingerprint=' '{print $2}')
nsx_api 2 2 "POST" ${cookies_file} ${headers_file} '{"display_name": "'${vcenter_fqdn}'", "server": "'${vcenter_fqdn}'", "create_service_account": true, "access_level_for_oidc": "FULL", "origin_type": "vCenter", "set_as_oidc_provider" : true, "credential": {"credential_type": "UsernamePasswordLoginCredential", "username": "'${vcenter_username}'@'${vcenter_domain}'", "password": "'${vcenter_password}'", "thumbprint": "'${ValidCmThumbPrint}'"}}' ${nsx_nested_ip} "api/v1/fabric/compute-managers"
compute_manager_id=$(echo $response_body | jq -r .id)
#
#
#
retry=6
pause=10
attempt=0
echo "Waiting for compute manager to be UP and REGISTERED"
while true ; do
  nsx_api 2 2 "GET" ${cookies_file} ${headers_file} "" ${nsx_nested_ip} "api/v1/fabric/compute-managers/$compute_manager_id/status"
  if [[ $(echo ${response_body} | jq -r .connection_status) == "UP" && $(echo ${response_body} | jq -r .registration_status) == "REGISTERED" ]] ; then
    echo "compute manager UP and REGISTERED"
    break
  fi
  if [ ${attempt} -eq ${retry} ]; then
    echo "FAILED to get compute manager UP and REGISTERED after ${retry} retries of ${pause} seconds"
    exit 255
  fi
  sleep ${pause}
  ((attempt++))
done
#
#
#
rm -f $cookies_file $headers_file