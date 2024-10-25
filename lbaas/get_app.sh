#!/bin/bash
#
jsonFile=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas.json)
source /home/ubuntu/bash/variables.sh
output_json_file="${1}"
#
IFS=$'\n'
json_api_output="/home/ubuntu/avi/response_body.json"
#
while true
do
  if [[ -z "$(ps -ef | grep vs.sh | grep -v grep)" ]]; then
    echo "VS is not creating"
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                       "api/virtualservice?page_size=-1" \
                                       "GET" \
                                       "${avi_version}" \
                                       "${lbaas_tenant}" \
                                       "" \
                                       "${json_api_output}"
    vs_count=$(jq -c -r '.count' ${json_api_output})
    results_json='{"count": "'${vs_count}'", "results": []}'
    for vs in $(jq -c -r '.results[]' ${json_api_output})
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