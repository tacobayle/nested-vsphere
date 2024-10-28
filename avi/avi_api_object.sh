#!/bin/bash
#
source /home/ubuntu/avi/avi_api.sh
#
username=${1}
password=${2}
ip_avi=${3}
api_endpoint=${4}
http_method=${5}
avi_version=${6}
avi_tenant=${7}
json_data=${8}
output_json_file=${9}
#
date_index=$(date '+%Y%m%d%H%M%S')
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
rm -f ${avi_cookie_file}
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${ip_avi}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
avi_api 2 2 "${http_method}" "${avi_cookie_file}" "${csrftoken}" "${avi_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "${api_endpoint}"
echo ${response_body} | jq -c -r '.' > ${output_json_file}