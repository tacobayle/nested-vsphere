#!/bin/bash
#
# $1 is url
# $2 is download location
# $3 is description of content to download
url=${1}
download_location=${2}
description=${3}
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