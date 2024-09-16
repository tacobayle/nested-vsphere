#!/bin/bash
#
rm -f /root/govc.error
jsonFile="${1}"
if [ -s "${jsonFile}" ]; then
  jq . $jsonFile > /dev/null
else
  echo "ERROR: jsonFile file is not present"
  exit 255
fi
#
#
operation=$(jq -c -r .operation $jsonFile)
deployment_name=$(jq -c -r .metadata.name $jsonFile)
folder=$(jq -c -r .spec.folder $jsonFile)
#
if [[ ${operation} == "apply" || ${operation} == "destroy" ]] ; then log_file="/nested-vsphere/log/${deployment_name}_${operation}.stdout" ; fi
if [[ ${operation} != "apply" && ${operation} != "destroy" ]] ; then echo "ERROR: Unsupported operation" ; exit 255 ; fi
#
rm -f ${log_file}
#
#
echo "Starting timestamp: $(date)" | tee -a ${log_file}
source /nested-vsphere/bash/govc/load_govc_external.sh
govc about
if [ $? -ne 0 ] ; then touch /root/govc.error ; fi
list_folder=$(govc find -json . -type f)
echo '------------------------------------------------------------' | tee ${log_file}
#
if [[ ${operation} == "apply" ]] ; then
  echo "Creation of a folder on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    echo "ERROR: unable to create folder ${folder}: it already exists" | tee -a ${log_file}
  else
    govc folder.create /${vsphere_dc}/vm/${folder} | tee -a ${log_file}
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', nested-'${basename_sddc}': vsphere external folder '${folder}' created"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  fi
  #
  #
fi
#
#
#
if [[ ${operation} == "destroy" ]] ; then
  #
  #
  echo '------------------------------------------------------------' | tee -a ${log_file}
  echo "Deletion of a folder on the underlay infrastructure - This should take less than a minute" | tee -a ${log_file}
  if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder}'")' >/dev/null ) ; then
    govc object.destroy /${vsphere_dc}/vm/${folder} | tee -a ${log_file}
    if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data '{"text":"'$(date "+%Y-%m-%d,%H:%M:%S")', nested-'${basename_sddc}': vsphere external folder '${folder}' removed"}' ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
  else
    echo "ERROR: unable to delete folder ${folder}: it does not exist" | tee -a ${log_file}
  fi
fi