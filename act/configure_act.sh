#!/bin/bash
#
jsonFile="${1}"
resultFile="${2}"
rm -f ${resultFile}
source /home/ubuntu/bash/functions.sh
source /home/ubuntu/bash/log_message.sh
source /home/ubuntu/bash/variables.sh
log_message "${deployment_name}:------------------------------------------------------------" "" "" ""
log_message "${deployment_name}: Configure ACT" "" "${slack_webhook}" "${google_webhook}"
#
# Configure ACT account
#
#curl -k -X POST -H "Content-Type: application/json" -d '{"userName":"admin","password":"'$(echo ${GENERIC_PASSWORD} | base64)'","email":""}' https://${ip_act}/api/user/registerUser
#
# HTML doc update
#
tee /home/ubuntu/act/configure-act.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Configure ACT</title>
    <style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
  text-align: left;
}
.code-box {
  border: 1px solid black;
  overflow-x: auto;
  padding: 10px;
  white-space: pre-wrap;
}
</style>
</head>
<body>
<h1>Configure ACT</h1>
<ul>
    <br>
    <table>
EOT
echo ${segments_overlay} | jq -c -r .[] | while read item
do
  if $(echo ${item} | jq -e '.lb' > /dev/null) ; then
    if [[ $(echo ${item} | jq -c -r '.lb') == "true" ]] ; then
      tee -a /home/ubuntu/act/configure-act.html> /dev/null <<EOT
      <tr>
          <th>Update Avi Cloud Configuration</th>
          <td>add the following tier1 and network: $(echo $item | jq -c -r .tier1), $(echo $item | jq -c -r .display_name)</td>
      </tr>
      <tr>
          <th>Update Avi VRF $(echo $item | jq -c -r .tier1) static ip route</th>
          <td>0.0.0.0/0 via $(echo $item | jq -c -r .cidr_three_octets).1</td>
      </tr>
EOT
    fi
  fi
done
tee -a /home/ubuntu/act/configure-act.html> /dev/null <<EOT
    </table>
    <br>
    <br>
</ul>
<script>
</body>
</html>
EOT
sudo cp /home/ubuntu/act/configure-act.html /var/www/html/
#
#
#
tee /home/ubuntu/act/act.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Demo ACT</title>
    <style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
  text-align: left;
}
.code-box {
  border: 1px solid black;
  overflow-x: auto;
  padding: 10px;
  white-space: pre-wrap;
}
</style>
</head>
<body>
<h1>Demo ACT</h1>
<ul>
    <br>
    <table>
EOT
tee -a /home/ubuntu/act/act.html> /dev/null <<EOT
        <tr>
            <th>ACT Username</th>
            <td>admin</td>
        </tr>
        <tr>
            <th>ACT UI</th>
            <td><a href="https://${ip_act}" target="_blank">https://${ip_act}</a></td>
        </tr>
        <tr>
            <th>NSX Manager IP</th>
            <td>${ip_nsx}</td>
        </tr>
        <tr>
            <th>NSX username</th>
            <td>admin</td>
        </tr>
        <tr>
            <th>Avi Ctrl IP</th>
            <td>${ip_avi}</td>
        </tr>
        <tr>
            <th>Avi username</th>
            <td>admin</td>
        </tr>
    </table>
    <br>
    <br>
</ul>
</body>
</html>
EOT
sudo cp /home/ubuntu/act/act.html /var/www/html/
touch ${resultFile}
exit
