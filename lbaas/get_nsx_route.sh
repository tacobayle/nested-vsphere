#!/bin/bash
#

source /home/ubuntu/lbaas/avi/alb_api.sh
#
results_json="{}"
output_json_file="${2}"
IFS=$'\n'
date_index=$(date '+%Y%m%d%H%M%S')
jsonFile="/tmp/$(basename "$0" | cut -f1 -d'.')_${date_index}.json"
jsonFile1="${1}"
if [ -s "${jsonFile1}" ]; then
  jq . $jsonFile1 > /dev/null
else
  echo "ERROR: jsonFile1 file is not present"
  exit 255
fi
#
jsonFile2=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas.json)
if [ -s "${jsonFile2}" ]; then
  jq . $jsonFile2 > /dev/null
else
  echo "ERROR: jsonFile2 file is not present"
  exit 255
fi
#
jq -s '.[0] * .[1]' ${jsonFile1} ${jsonFile2} | tee ${jsonFile}
source /home/ubuntu/bash/variables.sh
#
if $(jq -e '. | has("vs_name")' $jsonFile) ; then
  vs_name=$(jq -c -r .vs_name $jsonFile)
else
  "ERROR: vs_name should be defined"
  exit 255
fi
#
json_api_output="/home/ubuntu/avi/response_body.json"#
while true
do
  /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                       "api/virtualservice?page_size=-1" \
                                       "GET" \
                                       "${avi_version}" \
                                       "${lbaas_tenant}" \
                                       "" \
                                       "${json_api_output}"
  if [[ $(jq -c -r '.results | length' ${json_api_output}) -gt 0 && $(jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).name] | length' ${json_api_output}) -eq 1 ]]; then
    vsvip_ref=$(jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).vsvip_ref' ${json_api_output})
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                         "api/vsvip/$(basename ${vsvip_ref})" \
                                         "GET" \
                                         "${avi_version}" \
                                         "${lbaas_tenant}" \
                                         "" \
                                         "${json_api_output}"
    ip_vip=$(jq -c -r .vip[0].ip_address.addr ${json_api_output})
    tier1_name=$(jq -c -r .tier1_lr ${json_api_output})
    if [[ -z "${ip_vip}" || -z "${tier1_name}" ]]; then
      echo "retrying..."
    else
      break
    fi
  else
    echo "retrying..."
  fi
done
#
while true
do
  file_json_output="/home/ubuntu/nsx/static-routes.json"
  /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
             "olicy/api/v1/infra/tier-1s/$(basename ${tier1_name})/static-routes" \
             "${file_json_output}"
  next_hops=$(jq -c -r --arg arg1 "${ip_vip}/32" '[.results[] | select(.network == $arg1) | .next_hops[].ip_address]' ${file_json_output})
  if [ -z "${next_hops}" ]; then
    echo "retrying..."
  else
    results_json=$(echo $results_json | jq '. += {"date": "'$(date)'", "vs_name": "'${vs_name}'", "vsvip": "'${ip_vip}'/32", "next_hops": '${next_hops}'}')
    echo $results_json | jq -c -r '.' > ${output_json_file}
    break
  fi
  sleep 10
done
#
rm -f ${jsonFile}
rm -f ${jsonFile1}