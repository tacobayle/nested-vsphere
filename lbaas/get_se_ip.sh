#!/bin/bash
#
source /home/ubuntu/avi/alb_api.sh
#
jsonFile1="${1}"
output_json_file="${2}"
results_json="{}"
IFS=$'\n'
date_index=$(date '+%Y%m%d%H%M%S')
jsonFile="$(basename "$0" | cut -f1 -d'.')_${date_index}.json"
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
results_json=$(echo $results_json | jq '. += {"date": "'$(date)'", "vs_name": "'${vs_name}'", "se_list": []}')
#
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
    se_list_ref=$(jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).vip_runtime[0].se_list[].se_ref]' ${json_api_output})
    vsvip_ref=$(jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).vsvip_ref' ${json_api_output})
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                         "api/vsvip/$(basename ${vsvip_ref})" \
                                         "GET" \
                                         "${avi_version}" \
                                         "${lbaas_tenant}" \
                                         "" \
                                         "${json_api_output}"
    network_ref=$(jq -c -r .vip[0].ipam_network_subnet.network_ref ${json_api_output})
    if [ -z "${network_ref}" ]; then
      echo "retrying..."
    else
      /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                           "api/network/$(basename ${network_ref})" \
                                           "GET" \
                                           "${avi_version}" \
                                           "admin" \
                                           "" \
                                           "${json_api_output}"
      segment_name=$(jq -c -r .name ${json_api_output})
    fi
    for item in $(echo ${se_list_ref}| jq -c -r .[])
    do
      /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                           "api/serviceengine/$(basename ${item})" \
                                           "GET" \
                                           "${avi_version}" \
                                           "admin" \
                                           "" \
                                           "${json_api_output}"
      se_ip=$(jq -c -r --arg arg "${segment_name}" '.data_vnics[] | select(.network_name == $arg).vnic_networks[1].ip.ip_addr.addr' ${json_api_output})
      se_name=$(jq -c -r '.name' ${json_api_output})
      results_json=$(jq '.se_list += [{"name": "'${se_name}'", "ip": "'${se_ip}'"}]' ${json_api_output})
      echo $results_json | jq -c -r '.' > ${output_json_file}
    done
    break
  else
    echo "retrying..."
  fi
done
#
rm -f ${jsonFile}
rm -f ${jsonFile1}
