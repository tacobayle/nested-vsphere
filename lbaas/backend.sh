#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile="${1}"
source /home/ubuntu/bash/variables.sh
#
operation=$(jq -c -r .operation $jsonFile)
vs_name=$(jq -c -r .vs_name $jsonFile)
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
if [[ ${operation} == "apply" ]] ; then
  list=$(govc find -json vm -name "${vs_name}*")
  if [[ ${list} != "null" ]] ; then
    echo $list | jq -c -r .[] | while read item
    do
      govc vm.destroy $item
    done
  fi
  list=$(govc find -json vm -name "${vs_name}*")
  if [[ ${list} == "null" ]] ; then
    count=$(jq -c -r .count $jsonFile)
    app_profile=$(jq -c -r .app_profile $jsonFile)
    if [[ ${app_profile} != "public" && ${app_profile} != "private" ]] ; then echo "ERROR: Unsupported app_profile" ; exit 255 ; fi
    if [[ ${app_profile} == "public" ]] ; then
      tier1=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_public == "true").tier1')
      lbaas_segment=$(echo ${segments_overlay} | jq -r -c --arg arg1 "${tier1}" '.[] | select(.backend == "true" and .tier1 == $arg1).display_name')
    fi
    if [[ ${app_profile} == "private" ]] ; then
      tier1=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == "true").tier1')
      lbaas_segment=$(echo ${segments_overlay} | jq -r -c --arg arg1 "${tier1}" '.[] | select(.backend == "true" and .tier1 == $arg1).display_name')
    fi
    for backend in $(seq 1 ${count})
    do
      list=$(govc find -json vm -name "unassigned*")
      if [[ ${list} != "null" && $(echo ${list} | jq -c -r '. | length') -gt 0 ]] ; then
        govc vm.change -vm $(echo ${list} | jq -c -r .[0]) -c 2 -m 2048 -e="disk.enableUUID=1"
        govc vm.disk.change -vm $(echo ${list} | jq -c -r .[0]) -disk.label "Hard disk 1" -size 10G
        govc object.rename $(echo ${list} | jq -c -r .[0]) "${app_profile}-${vs_name}-${backend}"
        govc vm.power -on=true "${app_profile}-${vs_name}-${backend}"
        govc vm.network.change -vm "${app_profile}-${vs_name}-${backend}" -net ${lbaas_segment} ethernet-0
      else
        #
        # Create VM
        #
        sed -e "s/\${password}/${GENERIC_PASSWORD}/" \
            -e "s/\${hostname}/${app_profile}-${vs_name}-${backend}/" \
            -e "s/\${docker_registry_username}/${DOCKER_REGISTRY_USERNAME}/" \
            -e "s/\${docker_registry_password}/${DOCKER_REGISTRY_PASSWORD}/" /home/ubuntu/templates/userdata_lbaas_backend.yaml.template | tee /tmp/${app_profile}-${vs_name}-${backend} > /dev/null
        #
        sed -e "s#\${public_key}#$(cat /home/ubuntu/.ssh/id_rsa.pub)#" \
            -e "s@\${base64_userdata}@$(base64 /tmp/${app_profile}-${vs_name}-${backend} -w 0)@" \
            -e "s/\${password}/${GENERIC_PASSWORD}/" \
            -e "s@\${network_ref}@${lbaas_segment}@" \
            -e "s/\${vm_name}/${app_profile}-${vs_name}-${backend}/" /home/ubuntu/templates/options-ubuntu.json.template | tee /tmp/${vs_name}${backend}.json
        govc library.deploy -options /tmp/${vs_name}${backend}.json /${content_library_name}/$(basename ${ubuntu_ova_url} .ova)
        govc vm.change -vm "${app_profile}-${vs_name}-${backend}" -c 2 -m 2048 -e="disk.enableUUID=1"
        govc vm.disk.change -vm "${app_profile}-${vs_name}-${backend}" -disk.label "Hard disk 1" -size 10G
        govc vm.power -on=true "${app_profile}-${vs_name}-${backend}"
      fi
    done
  else
    echo "backend VM ${vs_name}* already exist"
  fi
fi
#
if [[ ${operation} == "destroy" ]] ; then
  app_profile=$(jq -c -r .app_profile $jsonFile)
  list=$(govc find -json vm -name "${app_profile}-${vs_name}*")
  if [[ ${list} != "null" ]] ; then
    echo $list | jq -c -r .[] | while read item
    do
      govc vm.destroy ${item}
    done
  else
    echo "no backend VM ${app_profile}-${vs_name}* to be deleted"
  fi
fi