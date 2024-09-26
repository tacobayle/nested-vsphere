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