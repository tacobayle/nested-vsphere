#!/bin/bash
#
source /home/ubuntu/nsx/nsx_api.sh
#
nsx_nested_ip=${1}
nsx_password=${2}
license=${3}
#
cookies_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_cookie.txt"
headers_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_header.txt"
rm -f ${cookies_file} ${headers_file}
/bin/bash /home/ubuntu/nsx/create_nsx_api_session.sh admin ${nsx_password} ${nsx_nested_ip} ${cookies_file} ${headers_file}
json_data='
{
  "license_key": "'${license}'"
}'
nsx_api 2 2 "POST" ${cookies_file} ${headers_file} "${json_data}" ${nsx_nested_ip} "api/v1/licenses"
nsx_api 2 2 "POST" ${cookies_file} ${headers_file} "" ${nsx_nested_ip} "policy/api/v1/eula/accept"
rm -f ${cookies_file} ${headers_file}