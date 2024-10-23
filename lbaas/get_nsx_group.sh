#!/bin/bash
#
results_json="{}"
output_json_file="${2}"
rm -f ${output_json_file}
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
jsonFile2=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas/lbaas.json)
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
while true
do
  if [ -z "$(ps -ef | grep ${vs_name} | grep backend.sh | grep -v grep)" ]; then
    file_json_output="/home/ubuntu/nsx/groups.json"
    /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/domains/default/groups" \
                "${file_json_output}"
    if [[ $(jq -c -r --arg arg "${vs_name}" '[.results[] | select(.display_name == $arg).display_name] | length' ${file_json_output}) -eq 1 ]]; then
      echo "NSX group ${vs_name} already exist"
      sleep 5
      echo "VM is not creating"
      vm_count=0
      ip_count=1
      while [[ ${vm_count} != ${ip_count} ]] ; do
        file_json_output="/home/ubuntu/nsx/virtual-machines.json"
        /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                   "policy/api/v1/infra/domains/default/groups/${vs_name}/members/virtual-machines" \
                   "${file_json_output}"
        vm_count=$(jq -c -r '.results | length' ${file_json_output})
        /bin/bash /home/ubuntu/nsx/get_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                   "policy/api/v1/infra/domains/default/groups/${vs_name}/members/ip-addresses" \
                   "${file_json_output}"
        ip_count=$(jq -c -r '.results | length' ${file_json_output})
        vm_ips=$(jq -c -r '.results' ${file_json_output})
        sleep 10
      done
      results_json=$(echo ${results_json} | jq '. += {"date": "'$(date)'", "vs_name": "'${vs_name}'", "vm_count": "'${vm_count}'", "vm_ips": '${vm_ips}'}')
      echo $results_json | tee ${output_json_file} | jq .
      break
    else
      echo "NSX group ${vs_name} does not exist"
    fi
  else
    echo "VM is creating"
  fi
  sleep 10
done
#
rm -f ${jsonFile}
rm -f ${jsonFile1}