#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas/lbaas.json)
source /home/ubuntu/bash/variables.sh
source /home/ubuntu/avi/alb_api.sh
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "ERROR: unable to connect to vCenter"
  exit
fi
#
IFS=$'\n'
date_index=$(date '+%Y%m%d%H%M%S')
#
while true
do
  if [[ -z "$(ps -ef | grep backend.sh | grep -v grep)" && -z "$(ps -ef | grep vs.sh | grep -v grep)" && -z "$(ps -ef | grep nsx_group.sh | grep -v grep)" ]]; then
    echo "VM is not creating"
    avi_cookie_file="/tmp/avi_$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
    curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                    -d "{\"username\": \"${lbaas_username}\", \"password\": \"${GENERIC_PASSWORD}\"}" \
                                    -c ${avi_cookie_file} https://${ip_avi}/login)
    csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
    for vs in $(echo ${response_body} | jq -c -r '.results[]')
    do
      # Avi
      vs_name=$(echo ${vs} | jq -c -r '.name')
      json_data='
      {
        "model_name": "VirtualService",
        "data": {
          "uuid": "'$(echo ${vs} | jq -c -r '.uuid')'"
        }
      }'
      echo "delete Avi vs name ${vs_name}"
      alb_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "api/macro"
      # NSX
      /bin/bash /home/ubuntu/nsx/set_object.sh "${ip_nsx}" "${GENERIC_PASSWORD}" \
                  "policy/api/v1/infra/domains/default/groups/${vs_name}" \
                  "DELETE" \
                  ""
      # vSphere
      list=$(govc find -json vm -name "${vs_name}*")
      if [[ ${list} != "null" ]] ; then
        echo $list | jq -c -r .[] | while read item
        do
           echo "delete vSphere VM name ${item}"
          govc vm.destroy ${item}
        done
      fi
    done
    list=$(govc find -json vm -name "unassigned*")
    if [[ ${list} != "null" && $(echo ${list} | jq -c -r '. | length') -eq 5 ]] ; then
      echo "clean-up done"
      break
    else
      backend=$(uuidgen)
      tier1=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_public == "true").tier1')
      lbaas_segment=$(echo ${segments_overlay} | jq -r -c --arg arg1 "${tier1}" '.[] | select(.backend == "true" and .tier1 == $arg1).display_name')
      sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s/\${hostname}/unassigned-${backend}/" \
          -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
          -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" /home/ubuntu/templates/userdata_lbaas_backend.yaml.template | tee /tmp/userdata_${backend}.yaml > /dev/null
      #
      sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
          -e "s@\${base64_userdata}@$(base64 /tmp/userdata_${backend}.yaml -w 0)@" \
          -e "s/\${password}/${GENERIC_PASSWORD}/" \
          -e "s@\${network_ref}@${lbaas_segment}@" \
          -e "s/\${vm_name}/unassigned-${backend}/" /home/ubuntu/templates/options-ubuntu.json.template | tee /tmp/${backend}.json
      govc library.deploy -options /tmp/${backend}.json /${content_library_name}/$(basename ${ubuntu_ova_url} .ova)
    fi
  else
    echo "waiting for on-going stuff"
    sleep 10
  fi
done