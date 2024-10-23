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
avi_cookie_file="/tmp/avi_$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${lbaas_username}\", \"password\": \"${GENERIC_PASSWORD}\"}" \
                                -c ${avi_cookie_file} https://${ip_avi}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
while true
do
  alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
  if [[ $(echo ${response_body} | jq -c -r '.results | length') -gt 0 && $(echo ${response_body} | jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).name] | length') -eq 1 ]]; then
    cert_ref=$(echo ${response_body} | jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).ssl_key_and_certificate_refs[0]')
    alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/sslkeyandcertificate/$(basename ${cert_ref})"
    cert_name=$(echo ${response_body} | jq -c -r '.name')
    cert_type=$(echo ${response_body} | jq -c -r '.certificate.self_signed')
    issuer_name=$(echo ${response_body} | jq -c -r '.certificate.issuer.common_name')
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
rm -f ${avi_cookie_file}