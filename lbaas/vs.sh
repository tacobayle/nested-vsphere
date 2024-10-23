#!/bin/bash
#
source /home/ubuntu/bash/functions.sh
jsonFile="${1}"
source /home/ubuntu/bash/variables.sh
source /home/ubuntu/avi/alb_api.sh
#
#
operation=$(jq -c -r .operation $jsonFile)
vs_name=$(jq -c -r .vs_name $jsonFile)
date_index=$(date '+%Y%m%d%H%M%S')
#
avi_cookie_file="/tmp/avi_$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${lbaas_username}\", \"password\": \"${GENERIC_PASSWORD}\"}" \
                                -c ${avi_cookie_file} https://${ip_avi}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
if [[ ${operation} == "apply" ]] ; then
  alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
  if [[ $(echo $response_body | jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).name] | length') -eq 1 ]]; then
    json_data='
    {
      "model_name": "VirtualService",
      "data": {
        "uuid": "'$(echo $response_body | jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).uuid')'"
      }
    }'
    alb_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "${json_data}" "${ip_avi}" "api/macro"
  fi
  alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
  if [[ $(echo $response_body | jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).name] | length') -eq 0 ]]; then
    app_profile=$(jq -c -r .app_profile $jsonFile)
    if [[ ${app_profile} != "public" && ${app_profile} != "private" ]] ; then echo "ERROR: Unsupported app_profile" ; exit 255 ; fi
    if [[ ${app_profile} == "public" ]] ; then
      avi_vip_cidr=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_public == "true").cidr')
      tier1_name=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_public == "true").tier1')
    fi
    if [[ ${app_profile} == "private" ]] ; then
      avi_vip_cidr=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == "true").cidr')
      tier1_name=$(echo ${segments_overlay} | jq -r -c '.[] | select(.lbaas_private == "true").tier1')
    fi
    json_data='
    {
      "host": "'${ip_nsx}'",
      "username": "admin",
      "password": "'${GENERIC_PASSWORD}'"
    }'
    alb_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "api/nsxt/tier1s?page_size=-1"
    tier1_id=$(echo $response_body | jq -c -r --arg arg ${tier1_name} '.resource.nsxt_tier1routers[] | select(.name == $arg).id' )
    alb_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "api/nsxt/groups?page_size=-1"
    group_id=$(echo $response_body | jq -c -r --arg arg ${vs_name} '.resource.nsxt_groups[] | select(.name == $arg).id' )
    json_data='
    {
      "model_name": "VirtualService",
      "data": {
        "name": "'${vs_name}'",
        "enabled": true,
        "cloud_ref": "/api/cloud/?name='${nsx_cloud_name}'",
        "application_profile_ref": "/api/applicationprofile/?name=System-Secure-HTTP",
        "ssl_profile_ref": "/api/sslprofile/?name=System-Standard",
        "analytics_policy": {
            "udf_log_throttle": 10,
            "metrics_realtime_update": {
                "duration": 0,
                "enabled": true
            },
            "significant_log_throttle": 0,
            "client_insights": "NO_INSIGHTS",
            "full_client_logs": {
                "duration": 0,
                "throttle": 10,
                "enabled": true
            }
        },
        "services": [
          {
            "enable_ssl": false,
            "port": 80
          },
          {
            "port": 443,
            "enable_ssl": true
          }
        ],
        "vsvip_ref_data": {
          "name": "vsvip-'${vs_name}'",
          "cloud_ref": "/api/cloud/?name='${nsx_cloud_name}'",
          "tier1_lr": "'${tier1_id}'",
          "vip":
            [
              {
                "auto_allocate_ip": true,
                "vip_id": "1",
                "ipam_network_subnet":
                {
                  "subnet":
                  {
                    "mask": "'$(echo ${avi_vip_cidr} | cut -d"/" -f2)'",
                    "ip_addr":
                    {
                      "type": "V4",
                      "addr": "'$(echo ${avi_vip_cidr} | cut -d"/" -f1)'"
                    }
                  }
                }
              }
            ],
          "dns_info": [
            {
              "fqdn": "'${vs_name}'.'${avi_subdomain}.${domain}'"
            }
          ]
        },
        "pool_ref_data": {
          "name": "'${vs_name}'-pool",
          "enabled": true,
          "tier1_lr": "'${tier1_id}'",
          "cloud_ref": "/api/cloud/?name='${nsx_cloud_name}'",
          "lb_algorithm": "LB_ALGORITHM_LEAST_CONNECTIONS",
          "nsx_securitygroup": ["'${group_id}'"],
          "default_server_port": 80
        }
      }
    }'
    if [[ $(jq -c -r .cert $jsonFile) == "self-signed" ]] ; then
#      {"certificate":{"expiry_status":"SSL_CERTIFICATE_GOOD","days_until_expire":365,"self_signed":true,"issuer":{},"subject":{"common_name":"'${vs_name}'.'$(jq -c -r .avi_domain $jsonFile)'"}},"key_params":{"algorithm":"SSL_KEY_ALGORITHM_EC","ec_params":{"curve":"SSL_KEY_EC_CURVE_SECP256R1"}},"status":"SSL_CERTIFICATE_FINISHED","format":"SSL_PEM","certificate_base64":true,"key_base64":true,"enable_ocsp_stapling":false,"ocsp_config":{"ocsp_req_interval":86400,"url_action":"OCSP_RESPONDER_URL_FAILOVER","failed_ocsp_jobs_retry_interval":3600,"max_tries":10},"import_key_to_hsm":false,"is_federated":false,"type":"SSL_CERTIFICATE_TYPE_VIRTUALSERVICE","ocsp_response_info":{},"name":"'${vs_name}'-cert"}
      json_data=$(echo ${json_data} | jq -c -r '.data += {"ssl_key_and_certificate_refs": ["/api/sslkeyandcertificate/?name='${vs_name}'-cert"]}')
      json_data=$(echo ${json_data} | jq -c -r '.data += {"ssl_key_and_certificate_refs_data": [{"certificate":{"expiry_status":"SSL_CERTIFICATE_GOOD","days_until_expire":365,"self_signed":true,"issuer":{},"subject":{"common_name":"'${vs_name}'.'${avi_subdomain}.${domain}'"}},"key_params":{"algorithm":"SSL_KEY_ALGORITHM_EC","ec_params":{"curve":"SSL_KEY_EC_CURVE_SECP256R1"}},"status":"SSL_CERTIFICATE_FINISHED","format":"SSL_PEM","certificate_base64":true,"key_base64":true,"enable_ocsp_stapling":false,"ocsp_config":{"ocsp_req_interval":86400,"url_action":"OCSP_RESPONDER_URL_FAILOVER","failed_ocsp_jobs_retry_interval":3600,"max_tries":10},"import_key_to_hsm":false,"is_federated":false,"type":"SSL_CERTIFICATE_TYPE_VIRTUALSERVICE","ocsp_response_info":{},"name":"'${vs_name}'-cert"}]}')
#      json_data=$(echo ${json_data} | jq -c -r '.data += {"ssl_key_and_certificate_refs": ["/api/sslkeyandcertificate/?name=System-Default-Cert"]}')
    fi
    if [[ $(jq -c -r .cert $jsonFile) == "signed" ]] ; then
      # use case with cert automation
      json_data=$(echo ${json_data} | jq -c -r '.data += {"ssl_key_and_certificate_refs": ["/api/sslkeyandcertificate/?name='${vs_name}'-cert"]}')
      json_data=$(echo ${json_data} | jq -c -r '.data += {"ssl_key_and_certificate_refs_data": [{"certificate":{"expiry_status":"SSL_CERTIFICATE_GOOD","self_signed":false,"issuer":{},"subject":{"common_name":"'${vs_name}'.'${avi_subdomain}.${domain}'"}},"key_params":{"algorithm":"SSL_KEY_ALGORITHM_RSA","rsa_params":{"key_size":"SSL_KEY_2048_BITS","exponent":65537}},"status":"SSL_CERTIFICATE_FINISHED","format":"SSL_PEM","certificate_base64":true,"key_base64":true,"enable_ocsp_stapling":false,"ocsp_config":{"ocsp_req_interval":86400,"url_action":"OCSP_RESPONDER_URL_FAILOVER","failed_ocsp_jobs_retry_interval":3600,"max_tries":10},"import_key_to_hsm":false,"is_federated":false,"type":"SSL_CERTIFICATE_TYPE_VIRTUALSERVICE","ocsp_response_info":{},"name":"'${vs_name}'-cert","certificate_management_profile_ref":"/api/certificatemanagementprofile/?name='${vault_certificate_management_profile}'"}]}')
    fi
    if [[ ${app_profile} == "public" ]] ; then
      json_data=$(echo ${json_data} | jq -c -r '.data += {"waf_policy_ref": "/api/wafpolicy/?name=System-WAF-Policy"}')
      json_data=$(echo ${json_data} | jq -c -r '.data += {"se_group_ref": "/api/serviceenginegroup/?name=public"}')
    fi
    if [[ ${app_profile} == "private" ]] ; then
      json_data=$(echo ${json_data} | jq -c -r '.data += {"se_group_ref": "/api/serviceenginegroup/?name=private"}')
    fi
    alb_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "api/macro"
  fi
fi
#
if [[ ${operation} == "destroy" ]] ; then
  alb_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "" "${ip_avi}" "api/virtualservice?page_size=-1"
  if [[ $(echo $response_body | jq -c -r --arg arg "${vs_name}" '[.results[] | select(.name == $arg).name] | length') -eq 1 ]]; then
    json_data='
    {
      "model_name": "VirtualService",
      "data": {
        "uuid": "'$(echo $response_body | jq -c -r --arg arg "${vs_name}" '.results[] | select(.name == $arg).uuid')'"
      }
    }'
    alb_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${lbaas_tenant}" "${avi_version}" "${json_data}" "${ip_avi}" "api/macro"
  else
    echo "no VS ${vs_name}* to be deleted"
  fi
fi