#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile="${1}"
source /home/ubuntu/bash/variables.sh
#
operation=$(jq -c -r .operation $jsonFile)
vs_name=$(jq -c -r .vs_name $jsonFile)
app_profile=$(jq -c -r .app_profile $jsonFile)
#
if [[ ${operation} == "apply" ]] ; then
  file_json_output="/home/ubuntu/nsx/groups.json"
  /bin/bash /home/ubuntu/nsx/get_object.sh \
              "${ip_nsx}" \
              "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/domains/default/groups" \
              "${file_json_output}"
  if [[ $(jq -c -r --arg arg1 "${vs_name}" '[.results[] | select(.display_name == $arg1).display_name] | length' ${file_json_output}) -eq 1 ]]; then
    echo "NSX group ${vs_name} already exist"
  else
    #
    json_data='
    {
      "display_name" : "'${vs_name}'",
      "expression" : [ {
        "member_type" : "VirtualMachine",
        "key" : "Name",
        "operator" : "STARTSWITH",
        "value" : "'${app_profile}-${vs_name}'",
        "resource_type" : "Condition"
      } ]
    }'
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/domains/default/groups/${vs_name}" \
                "PUT" \
                "${json_data}"
  fi
fi
#
if [[ ${operation} == "destroy" ]] ; then
  file_json_output="/home/ubuntu/nsx/groups.json"
  /bin/bash /home/ubuntu/nsx/get_object.sh \
              "${ip_nsx}" \
              "${GENERIC_PASSWORD}" \
              "policy/api/v1/infra/domains/default/groups" \
              "${file_json_output}"
  if [[ $(jq -c -r --arg arg1 "${vs_name}" '[.results[] | select(.display_name == $arg1).display_name] | length' ${file_json_output}) -eq 1 ]]; then
    /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                "policy/api/v1/infra/domains/default/groups/${vs_name}" \
                "DELETE" \
                ""
  else
    echo "NSX group ${vs_name} does not exist"
  fi
fi