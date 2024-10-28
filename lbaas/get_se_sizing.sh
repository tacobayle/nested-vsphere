#!/bin/bash
#
source /home/ubuntu/avi/alb_api.sh
#
jsonFile1="${1}"
output_json_file="${2}"
results_json="{}"
IFS=$'\n'
date_index=$(date '+%Y%m%d%H%M%S')
jsonFile="/tmp/$(basename "$0" | cut -f1 -d'.')_${date_index}.json"
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
json_api_output="/home/ubuntu/avi/response_body.json"
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
    se_group_ref=$(jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).se_group_ref' ${json_api_output})
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                         "api/serviceenginegroup/$(basename ${se_group_ref})" \
                                         "GET" \
                                         "${avi_version}" \
                                         "${lbaas_tenant}" \
                                         "" \
                                         "${json_api_output}"
    vcpus_per_se=$(jq -c -r '.vcpus_per_se' ${json_api_output})
    memory_per_se=$(jq -c -r '.memory_per_se' ${json_api_output})
    disk_per_se=$(jq -c -r '.disk_per_se' ${json_api_output})
    results_json=$(echo ${results_json} | jq '. += {"date": "'$(date)'", "vs_name": "'${vs_name}'", "vcpu_per_se": "'${vcpus_per_se}'", "memory_per_se": "'${memory_per_se}'MB", "disk_per_se": "'${disk_per_se}'G"}')
    break
  fi
done
#
echo $results_json | jq -c -r '.' > ${output_json_file}
#
rm -f ${jsonFile}
rm -f ${jsonFile1}