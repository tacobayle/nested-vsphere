#!/bin/bash
#
jsonFile="${1}"
resultFile="${2}"
rm -f ${resultFile}
source /home/ubuntu/bash/log_message.sh
source /home/ubuntu/bash/variables.sh
export GOVC_PASSWORD=${GENERIC_PASSWORD}
export GOVC_INSECURE=true
export GOVC_USERNAME=root
for esxi in $(seq 1 $(echo ${ips_esxi} | jq -c -r '. | length'))
do
  ip_esxi=$(echo ${ips_esxi} | jq -r .[$(expr ${esxi} - 1)])
  name_esxi="${esxi_basename}${esxi}"
  export GOVC_URL=${cidr_mgmt_three_octets}.${ip_esxi}
  # https check
  count=1
  until $(curl --output /dev/null --silent --head -k https://${cidr_mgmt_three_octets}.${ip_esxi})
  do
    log_message "${deployment_name}: Attempt ${count}: Waiting for ESXi host at https://${cidr_mgmt_three_octets}.${ip_esxi} to be reachable..." "" "" ""
    sleep 10
    count=$((count+1))
    if [[ "${count}" -eq 60 ]]; then
      log_message "${deployment_name}: ERROR: Unable to connect to ESXi host at https://${cidr_mgmt_three_octets}.${ip_esxi}" "" "${slack_webhook}" "${google_webhook}"
      exit
    fi
  done
  #
  # the following sleep should be replaced by an API call to monitor the ESXi API status
  #
  sleep 90
  govc host.storage.info -json -rescan | jq -c -r '.storageDeviceInfo.scsiLun[] | select( .deviceType == "disk" ) | .deviceName' | while read item
  do
    govc host.storage.mark -ssd ${item} > /dev/null
    log_message "${deployment_name}: nested ESXi ${name_esxi} disks ${item} marked as SSD" "" "${slack_webhook}" "${google_webhook}"
  done
done
touch ${resultFile}
exit