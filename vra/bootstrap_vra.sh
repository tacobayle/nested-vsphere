#!/bin/bash
#
jsonFile="${1}"
resultFile="${2}"
rm -f ${resultFile}
source /home/ubuntu/bash/functions.sh
source /home/ubuntu/bash/log_message.sh
source /home/ubuntu/bash/variables.sh
log_message "${deployment_name}:------------------------------------------------------------" "" "" ""
log_message "${deployment_name}: Bootstrap VRA  - This should take about 20 minutes" "" "${slack_webhook}" "${google_webhook}"
#
# VRA ssh check
#
retry=60 ; pause=10 ; attempt=1
while true ; do
  log_message "${deployment_name}: $(date): attempt $attempt to verify VRA ${vra_name} is ready" "" "" ""
  sshpass -p "${GENERIC_PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip_vra}" -q "exit" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    log_message "${deployment_name}: ${log_prefix}: $(date) VRA ${vra_name} is reachable." "" "" ""
    wait=600
    log_message "${deployment_name}: $(date): waiting ${wait} seconds for VRA to be ready" "" "" ""
    sleep ${wait}
    break
  fi
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    log_message "${deployment_name}: $(date): VRA ${vra_name} is unreachable after ${attempt} attempt" "" "" ""
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
touch ${resultFile}
log_message "${deployment_name}: VRA bootstrapped" "" "${slack_webhook}" "${google_webhook}"
exit