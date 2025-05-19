#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
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
#
#
if [[ ${k8s_clusters} != "null" ]]; then
  kube_increment_ip=0
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    #
    # VM deletion
    #
    for index_ip in $(seq 1 2)
    do
      if [[ ${kind} == "vsphere-nsx"* && ${kind} == *"-avi" ]]; then
        cidr=$(echo ${segments_overlay} | jq -r -c '.[] | select(.kube == "true").cidr')
        if [[ ${cidr} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
          cidr_vip_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        fi
      fi
      kube_last_octet=$((kube_starting_ip+kube_increment_ip))
      ip_k8s_node="${cidr_vip_three_octets}.${kube_last_octet}"
      ssh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R "${ip_k8s_node}"
      echo "Deletion of the VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}"
      list_vm=$(govc find -json -type m -name "${k8s_basename}${index}-${k8s_basename_vm}${index_ip}")
      if [[ ${list_vm} != "null" ]] ; then
        govc vm.power -off=true "${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" >> /dev/null 2>&1
        govc vm.destroy "$${k8s_basename}${index}-${k8s_basename_vm}${index_ip}" >> /dev/null 2>&1
        echo "$(date): VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip} deleted"
      else
        echo "$(date): ERROR: unable to delete VM ${k8s_basename}${index}-${k8s_basename_vm}${index_ip}: it does not exists"
      fi
      ((kube_increment_ip++))
    done
    #
    # Folder deletion
    #
    list_folder=$(govc find -json . -type f)
    if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${k8s_basename}${index}'")' >/dev/null ) ; then
      govc object.destroy /${dc}/vm/${k8s_basename}${index} >> /dev/null 2>&1
      echo "$(date): Folder ${k8s_basename}${index} deleted"
    else
      echo "$(date): ERROR: unable to delete folder ${k8s_basename}${index}: it does not exist"
    fi
  done
fi