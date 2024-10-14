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
# content library deletion
#
govc library.rm ubuntu
#
# Client VMs client deletion // vsphere-avi use case)
#
if [[ ${ips_clients} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_clients} | jq -c -r '. | length'))
  do
    govc vm.power -off=true "${folder_client}/${client_basename}${index}"
    govc vm.destroy "${folder_client}/${client_basename}${index}"
  done
fi
#
# App VMs deletion first group // vsphere-avi use case)
#
if [[ ${ips_app} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app} | jq -c -r '. | length'))
  do
    govc vm.power -off=true "${folder_app}/${app_basename}${index}"
    govc vm.destroy "${folder_app}/${app_basename}${index}"
  done
fi
#
# App VMs deletion second group // vsphere-avi use case)
#
if [[ ${ips_app_second} != "null" ]]; then
  for index in $(seq 1 $(echo ${ips_app_second} | jq -c -r '. | length'))
  do
    govc vm.power -off=true "${folder_app}/${app_basename_second}${index}"
    govc vm.destroy "${folder_app}/${app_basename_second}${index}"
  done
fi
#
# VM k8s_clusters deletion
#
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    for index_ip in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '.['$(expr ${index} - 1)'].ips | length'))
    do
      govc vm.power -off=true "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}"
      govc vm.destroy "${k8s_basename}${index}/${k8s_basename}${index}-${k8s_basename_vm}${index_ip}"
    done
  done
fi
#
# folder deletion for app
#
govc object.destroy /${dc}/vm/${folder_app}
#
# folder deletion for client
#
govc object.destroy /${dc}/vm/${folder_client}
#
# folder deletion for k8s cluster
#
if [[ ${k8s_clusters} != "null" ]]; then
  for index in $(seq 1 $(echo ${k8s_clusters} | jq -c -r '. | length'))
  do
    govc object.destroy /${dc}/vm/${k8s_basename}${index}
  done
fi