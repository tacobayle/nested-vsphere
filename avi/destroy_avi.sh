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
# avi ctrl deletion
#
list_vm=$(govc find -json vm -name "${avi_ctrl_name}")
if [[ ${list_vm} != "null" ]] ; then
  govc vm.power -off=true "${avi_ctrl_name}" >> /dev/null 2>&1
  govc vm.destroy "${avi_ctrl_name}" >> /dev/null 2>&1
else
  echo "ERROR: unable to delete VM ${avi_ctrl_name}: it does not exists"
fi
exit
#
# folder deletion
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Avi ctrl"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_avi}'")' >/dev/null ) ; then
  govc object.destroy /${vsphere_dc}/vm/${folder_avi} >> ${log_file} 2>&1
else
  echo "ERROR: unable to delete folder ${folder_avi}: it does not exist"
fi
