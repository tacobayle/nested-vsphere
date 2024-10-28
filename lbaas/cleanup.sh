#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=$(jq -c -r '.jsonFile' /home/ubuntu/lbaas.json)
source /home/ubuntu/bash/variables.sh
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
json_api_output="/home/ubuntu/avi/response_body.json"
#
while true
do
  if [[ -z "$(ps -ef | grep backend.sh | grep -v grep)" && -z "$(ps -ef | grep vs.sh | grep -v grep)" && -z "$(ps -ef | grep nsx_group.sh | grep -v grep)" ]]; then
    echo "VM is not creating"
    /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                   "api/virtualservice?page_size=-1" \
                                   "GET" \
                                   "${avi_version}" \
                                   "${lbaas_tenant}" \
                                   "" \
                                   "${json_api_output}"
    for vs in $(jq -c -r '.results[]' ${json_api_output})
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
      /home/ubuntu/avi/avi_api_object.sh "${lbaas_username}" "${GENERIC_PASSWORD}" "${ip_avi}" \
                                     "api/macro" \
                                     "DELETE" \
                                     "${avi_version}" \
                                     "${lbaas_tenant}" \
                                     "$(echo ${json_data} | jq -c -r .)" \
                                     "${json_api_output}"
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
          govc vm.destroy ${item} > /dev/null 2>&1
        done
      fi
    done
    list=$(govc find -json vm -name "unassigned*")
    if [[ ${list} != "null" && $(echo ${list} | jq -c -r '. | length') -eq 5 ]] ; then
      echo "clean-up done"
      break
    else
      backend=$(uuidgen)
      tier1=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_public == true).tier1')
      lbaas_segment=$(echo ${segments_overlay} | jq -r -c --arg arg1 "${tier1}" '.[] | select(.backend == true and .tier1 == $arg1).display_name')
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
      govc library.deploy -options /tmp/${backend}.json /${content_library_name}/$(basename ${ubuntu_ova_url} .ova) > /dev/null 2>&1
    fi
  else
    echo "waiting for on-going stuff"
    sleep 10
  fi
done