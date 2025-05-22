#!/bin/bash
#
log_prefix="VRA-Configure"
echo "--- $(date): ${log_prefix} start ---"
source /home/ubuntu/bash/functions.sh
jsonFile=${1}
source /home/ubuntu/bash/variables.sh
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