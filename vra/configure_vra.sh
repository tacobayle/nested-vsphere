#!/bin/bash
#
log_prefix="VRA-Configure"
echo "--- $(date): ${log_prefix} start ---"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
#
# create avi template yaml
#
sed -e "s/\${vra_avi_cloud_account}/${vra_avi_cloud_account}/" \
    -e "s/\${vra_vrf_context_ref}/$(echo ${net_client_list} | jq -r -c '[.[] | select(.vip_preserve_ip == false )][0].tier1')/" \
    -e "s/\${${network_ref}}/$(echo ${net_client_list} | jq -r -c '[.[] | select(.vip_preserve_ip == false )][0].display_name')/" \
    -e "s/\${domain}/${domain}/" \
    -e "s/\${avi_subdomain}/${avi_subdomain}/" /home/ubuntu/templates/vra/vra_avi_template.yml.template | tee /home/ubuntu/vra/vra_avi_template.yml
sudo cp /home/ubuntu/vra/vra_avi_template.yml /var/www/html/
#
# HTML doc update
#
tee /home/ubuntu/vra/vra.html> /dev/null <<EOT
<!DOCTYPE html>
<html>
<head>
    <title>Demo vRA</title>
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
<h1>Demo vRA</h1>
<ul>
    <br>
    <table>
        <tr>
            <th>vRA Deployment type</th>
            <td>single node - officially unsupported</td>
        </tr>
        <tr>
            <th>vRA Username</th>
            <td>admin</td>
        </tr>
        <tr>
            <th>vRA Password</th>
            <td>${GENERIC_PASSWORD}</td>
        </tr>
        <tr>
            <th>vRA UI</th>
            <td><a href="https://${ip_vra}" target="_blank">https://${ip_vra}</a></td>
        </tr>
        <tr>
            <th>yaml Avi template</th>
            <td><a href="vra_avi_template.yml" target="_blank">yaml Avi template</a></td>
        </tr>
        <tr>
            <th>Create a Cloud Account</th>
            <td>Go to Assembler / Infrastructure and on the left side create a Cloud Account - Avi button
            <br>Avi IP: ${ip_avi}
            <br>Tenant: ${lbaas_tenant}
            <br>Cloud Name: ${avi_cloud_name}
            </td>
        </tr>
        <tr>
            <th>Create an Avi Template</th>
            <td>Go to Design / Templates and select new from Blank Canvas and drag and drop the following
            <br>Avi VS
            <br>Avi pool
            <br>Avi vip
            <br>Link the VS with the pool and the vip
            <br>Copy/paste this file in the code box: <a href="vra_avi_template.yml" target="_blank">yaml Avi template</a>
            </td>
        </tr>
        <tr>
            <th>Version the Avi Template</th>
            <td>Click the Version button on the bottom left</td>
        </tr>
        <tr>
            <th>Create an Avi Template</th>
            <td>Go to Service Broker / Content and Policies / New content source / Template
            <br>name: ${vra_avi_template}
            <br>Select the source project: ${vra_project}
            <br>Validate
            <br>Create & Import
            </td>
        </tr>
        <tr>
            <th>Create an Avi Template</th>
            <td>Go to Service Broker / Content and Policies / Policies / Definitions / New Policy / Content sharing policy
            <br>name: ${vra_avi_policy}
            <br>Scope / Project / ${vra_project}
            <br>Content sharing / Add Items and select ${vra_avi_template} / add items
            <br>Share (content) with all users/groups in this project
            <br>Create
            </td>
        </tr>
        <tr>
            <th>Demo ${vra_avi_template}</th>
            <td>Go to Service Broker / Consume / Catalog / ${vra_avi_template} / request
            <br>Fill the form
            <br>Servers: $(echo ${ips_app_full} | jq -c -r .[])
            <br>Content sharing / Add Items and select ${vra_avi_template} / add items
            <br>Share (content) with all users/groups in this project
            <br>Create
            </td>
        </tr>
    </table>
    <br>
    <br>
</ul>
<script>
function copyToClipboard(boxIndex) {
  const codeBoxes = document.querySelectorAll('.code-box');
  const codeBox = codeBoxes[boxIndex];
  const codeElement = codeBox.querySelector('code');

  const tempTextarea = document.createElement('textarea');
  tempTextarea.value = codeElement.textContent;
  document.body.appendChild(tempTextarea);

  tempTextarea.select();
  document.execCommand('copy');

  document.body.removeChild(tempTextarea);

}
</script>
</body>
</html>
EOT
sudo cp /home/ubuntu/vra/vra.html /var/www/html/
#
# API token
#
api_token=$(curl -X POST -s -k "https://${vra_name}.${domain}/csp/gateway/am/api/login?access_token" -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{"username": "admin", "password": "'${GENERIC_PASSWORD}'"}' | jq -r .refresh_token)
#
# Access Token
#
access_token=$(curl -X POST -s -k "https://${vra_name}.${domain}/iaas/api/login" -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{"refreshToken": "'${api_token}'"}' | jq -r .token)
#
# Create a project
#
curl -X POST -s -k "https://${vra_name}.${domain}/project-service/api/projects" -H 'Content-Type: application/json' -H "Authorization: Bearer $access_token" -d '{"name" : "'${vra_project}'"}'