#!/bin/bash
#
log_prefix="VRA-Bootstrap"
echo "--- $(date): ${log_prefix} start ---"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# VRA ssh check
#
retry=60 ; pause=10 ; attempt=1
while true ; do
  echo "${log_prefix}: $(date): attempt $attempt to verify VRA ${vra_name} is ready"
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "exit" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "${log_prefix}: $(date) VRA ${vra_name} is reachable."
    wait=600
    echo "${log_prefix}: $(date): waiting ${wait} seconds for VRA to be ready"
    sleep ${wait}
    break
  fi
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "${log_prefix}: $(date): VRA ${vra_name} is unreachable after ${attempt} attempt"
    exit
  fi
  sleep $pause
done
#
# VRA config
#
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "vracli reset vidm --confirm"
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "echo ${GENERIC_PASSWORD} | tee password-file"
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "echo yes | vracli ldap set admin password-file"
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "rm password-file"
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "vracli license add ${vra_license}"
sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "/opt/scripts/deploy.sh"
#
#
#
echo "--- $(date): ${log_prefix} end ---"