vcenter_api () {
  # $1 is the amount of retry
  # $2 is the time to pause between each retry
  # $3 type of HTTP method (GET, POST, PUT, PATCH)
  # $4 vCenter token
  # $5 http data
  # $6 vCenter FQDN
  # $7 API endpoint
  retry=$1
  pause=$2
  attempt=0
  # echo "HTTP $3 API call to https://$6/$7"
  while true ; do
    response=$(curl -k -s -X $3 --write-out "\n%{http_code}" -H "vmware-api-session-id: $4" -H "Content-Type: application/json" -d "$5" https://$6/$7)
    response_body=$(sed '$ d' <<< "$response")
    response_code=$(tail -n1 <<< "$response")
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      echo "  HTTP $3 API call to https://$6/$7 was successful"
      break
    else
      echo "  Retrying HTTP $3 API call to https://$6/$7, http response code: $response_code, attempt: $attempt"
    fi
    if [ $attempt -eq $retry ]; then
      echo "  FAILED HTTP $3 API call to https://$6/$7, response code was: $response_code"
      echo "$response_body"
      exit 255
    fi
    sleep $pause
    ((attempt++))
  done
}

load_govc_env_wo_cluster () {
  export GOVC_USERNAME="${vsphere_nested_username}@${ssoDomain}"
  export GOVC_PASSWORD=${vsphere_nested_password}
  export GOVC_DATACENTER=${dc}
  export GOVC_INSECURE=true
  export GOVC_URL=${api_host}
  unset GOVC_CLUSTER
}

load_govc_env_with_cluster () {
  export GOVC_USERNAME="${vsphere_nested_username}@${ssoDomain}"
  export GOVC_PASSWORD=${vsphere_nested_password}
  export GOVC_DATACENTER=${dc}
  export GOVC_INSECURE=true
  export GOVC_URL=${api_host}
  export GOVC_CLUSTER=$1
}

load_govc_esxi () {
  export GOVC_USERNAME="root"
  export GOVC_PASSWORD=${esxi_nested_password}
  export GOVC_INSECURE=true
  unset GOVC_DATACENTER
  unset GOVC_CLUSTER
  unset GOVC_URL
}

function download_file_from_url_to_location () {
  # $1 is url
  # $2 is download location
  # $3 is description of content to download
  local url=$1
  local download_location=$2
  local description=$3
  echo ""
  echo "==> Checking ${description} file"
  if [ -s "${download_location}" ]; then
    echo "   +++ ${description} file ${download_location} is not empty"
  else
    echo "   +++ Downloading ${description} file"
    response=$(curl -k -s --write-out "\n%{http_code}" -o ${download_location} ${url})
    response_code=$(tail -n1 <<< "$response")
    if [[ $response_code != 200 ]] ; then
      echo "   +++ HTTP URI does not look valid: ${url}"
      rm -f "${download_location}"
      exit 255
    else
      if [ -s "${download_location}" ]; then
        echo "   ++++++ ${description} file ${download_location} is not empty"
      else
        echo "   ++++++ ${description} file ${download_location} is empty"
        exit 255
      fi
    fi
  fi
}

ip_netmask_by_prefix () {
  # $1 prefix
  # $2 indentation message
  error_prefix=1
  if [[ $1 == "32" ]] ; then echo "255.255.255.255" ; error_prefix=0 ; fi
  if [[ $1 == "31" ]] ; then echo "255.255.255.254" ; error_prefix=0 ; fi
  if [[ $1 == "30" ]] ; then echo "255.255.255.252" ; error_prefix=0 ; fi
  if [[ $1 == "29" ]] ; then echo "255.255.255.248" ; error_prefix=0 ; fi
  if [[ $1 == "28" ]] ; then echo "255.255.255.240" ; error_prefix=0 ; fi
  if [[ $1 == "27" ]] ; then echo "255.255.255.224" ; error_prefix=0 ; fi
  if [[ $1 == "26" ]] ; then echo "255.255.255.192" ; error_prefix=0 ; fi
  if [[ $1 == "25" ]] ; then echo "255.255.255.128" ; error_prefix=0 ; fi
  if [[ $1 == "24" ]] ; then echo "255.255.255.0"   ; error_prefix=0 ; fi
  if [[ $1 == "23" ]] ; then echo "255.255.254.0"   ; error_prefix=0 ; fi
  if [[ $1 == "22" ]] ; then echo "255.255.252.0"   ; error_prefix=0 ; fi
  if [[ $1 == "21" ]] ; then echo "255.255.248.0"   ; error_prefix=0 ; fi
  if [[ $1 == "20" ]] ; then echo "255.255.240.0"   ; error_prefix=0 ; fi
  if [[ $1 == "19" ]] ; then echo "255.255.224.0"   ; error_prefix=0 ; fi
  if [[ $1 == "18" ]] ; then echo "255.255.192.0"   ; error_prefix=0 ; fi
  if [[ $1 == "17" ]] ; then echo "255.255.128.0"   ; error_prefix=0 ; fi
  if [[ $1 == "16" ]] ; then echo "255.255.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "15" ]] ; then echo "255.254.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "14" ]] ; then echo "255.252.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "13" ]] ; then echo "255.248.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "12" ]] ; then echo "255.240.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "11" ]] ; then echo "255.224.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "10" ]] ; then echo "255.192.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "9" ]] ; then echo  "255.128.0.0"     ; error_prefix=0 ; fi
  if [[ $1 == "8" ]] ; then echo  "255.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "7" ]] ; then echo  "254.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "6" ]] ; then echo  "252.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "5" ]] ; then echo  "248.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "4" ]] ; then echo  "240.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "3" ]] ; then echo  "224.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "2" ]] ; then echo  "192.0.0.0"       ; error_prefix=0 ; fi
  if [[ $1 == "1" ]] ; then echo  "128.0.0.0"       ; error_prefix=0 ; fi
  if [[ error_prefix -eq 1 ]] ; then echo "$2+++ $1 does not seem to be a proper netmask" ; fi
}
