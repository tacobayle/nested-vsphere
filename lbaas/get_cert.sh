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
    cert_ref=$(jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).ssl_key_and_certificate_refs[0]' ${json_api_output})
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                         "api/sslkeyandcertificate/$(basename ${cert_ref})" \
                                         "GET" \
                                         "${avi_version}" \
                                         "${lbaas_tenant}" \
                                         "" \
                                         "${json_api_output}"
    cert_name=$(jq -c -r '.name' ${json_api_output})
    cert_type=$(jq -c -r '.certificate.self_signed' ${json_api_output})
    issuer_name=$(jq -c -r '.certificate.issuer.common_name' ${json_api_output})
    if [[ $(echo ${cert_type} | jq '.') == "true" ]] ; then
      cert_signed="self-signed"
    fi
    if [[ $(echo ${cert_type} | jq '.') == "false" ]] ; then
      cert_signed="signed"
    fi
    results_json=$(echo $results_json | jq '. += {"date": "'$(date)'", "vs_name": "'${vs_name}'", "cert_name": "'${cert_name}'", "cert_type": "'${cert_signed}'", "issuer_name": "'${issuer_name}'"}')
    break
  fi
done
#
echo ${results_json} | tee ${output_json_file} | jq .
#
rm -f ${jsonFile}
rm -f ${jsonFile1}