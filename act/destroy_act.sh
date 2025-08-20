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
# act deletion
#
echo "Deletion of the act"
list_vm=$(govc find -json -type m -name "${act_name}")
if [[ ${list_vm} != "null" ]] ; then
  govc vm.power -off=true "${act_name}" >> /dev/null 2>&1
  govc vm.destroy "${act_name}" >> /dev/null 2>&1
  echo "$(date): act deleted"
else
  echo "$(date): ERROR: unable to delete VM ${act_name}: it does not exists"
fi
#
# folder deletion
#
list_folder=$(govc find -json . -type f)
echo "Deletion of a folder for act"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_act}'")' >/dev/null ) ; then
  govc object.destroy /${dc}/vm/${folder_act} >> /dev/null 2>&1
  echo "$(date): Folder deleted"
else
  echo "$(date): ERROR: unable to delete folder ${folder_act}: it does not exist"
fi