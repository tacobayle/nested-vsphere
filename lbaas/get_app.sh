#!/bin/bash
#
jsonFile=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas/lbaas.json)
source /home/ubuntu/bash/variables.sh
source /home/ubuntu/avi/alb_api.sh
output_json_file="${1}"
#
IFS=$'\n'
date_index=$(date '+%Y%m%d%H%M%S')
#
while true
do
  if [[ -z "$(ps -ef | grep vs.sh | grep -v grep)" ]]; then
    echo "VS is not creating"
    avi_cookie_file="/tmp/avi_$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
    curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                    -d "{\"username\": \"${lbaas_username}\", \"password\": \"${GENERIC_PASSWORD}\"}" \
                                    -c ${avi_cookie_file} https://${ip_avi}/login)
    csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
    alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
    vs_count=$(echo ${response_body} | jq -c -r '.count')
    results_json='{"count": "'${vs_count}'", "results": []}'
    for vs in $(echo ${response_body} | jq -c -r '.results[]')
    do
      results_json=$(echo ${results_json} | jq -c -r '.results += ["'$(echo ${vs} | jq -c -r '.name')'"]')
    done
    echo ${results_json} | tee ${output_json_file} | jq .
    break
  else
    echo "waiting for on-going stuff"
    sleep 10
  fi
done