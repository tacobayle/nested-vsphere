#!/bin/bash
#
source /home/ubuntu/nsx/nsx_api.sh
#
nsx_nested_ip=$1
nsx_password=$2
avi_password=$3
avi_nested_ip=$4
#
cookies_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_cookie.txt"
headers_file="/home/ubuntu/nsx/nsx_$(basename $0 | cut -d"." -f1)_header.txt"
rm -f $cookies_file $headers_file
/bin/bash /home/ubuntu/nsx/create_nsx_api_session.sh admin $nsx_password $nsx_nested_ip $cookies_file $headers_file
json_data='
{
  "owned_by": "LCM",
  "cluster_ip": "'${avi_nested_ip}'",
  "infra_admin_username" : "admin",
  "infra_admin_password" : "'${avi_password}'"
}'
nsx_api 2 2 "PUT" $cookies_file $headers_file "${json_data}" $nsx_nested_ip "policy/api/v1/infra/alb-onboarding-workflow"