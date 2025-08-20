#!/bin/bash
#
echo "Starting timestamp: $(date)"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# GOVC check
#
load_govc_env_with_cluster "${cluster_basename}1"
govc about
if [ $? -ne 0 ] ; then
  echo "$(date): ERROR: unable to connect to vCenter"
  exit
fi
#
# vra deletion
#
echo "Deletion of the VRA"
list_vm=$(govc find -json -type m -name "${vra_name}")
if [[ ${list_vm} != "null" ]] ; then
  govc vm.power -off=true "${vra_name}" >> /dev/null 2>&1
  govc vm.destroy "${vra_name}" >> /dev/null 2>&1
  echo "$(date): VRA deleted"
else
  echo "$(date): ERROR: unable to delete VM ${vra_name}: it does not exists"
fi
#
# folder deletion
#
list_folder=$(govc find -json . -type f)
echo "Deletion of a folder for VRA"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_vra}'")' >/dev/null ) ; then
  govc object.destroy /${dc}/vm/${folder_vra} >> /dev/null 2>&1
  echo "$(date): Folder deleted"
else
  echo "$(date): ERROR: unable to delete folder ${folder_vra}: it does not exist"
fi
#
# ssh cleanup
#
ssh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R "${ip_vra}"