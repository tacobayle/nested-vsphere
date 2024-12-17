#!/bin/bash
#
# $1 is url
# $2 is download location
# $3 is description of content to download
# $4 is slack webhook url
url=${1}
download_location=${2}
description=${3}
SLACK_WEBHOOK_URL=${4}
echo ""
echo "==> Checking ${description} file"
if [ -s "${download_location}" ]; then
  echo "   +++ ${description} file ${download_location} is not empty"
  if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$(date "+%Y-%m-%d,%H:%M:%S"), ${description} already downloaded\"}" ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
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
      if [ -z "${SLACK_WEBHOOK_URL}" ] ; then echo "ignoring slack update" ; else curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$(date "+%Y-%m-%d,%H:%M:%S"), ${description} downloaded\"}" ${SLACK_WEBHOOK_URL} >/dev/null 2>&1; fi
    else
      echo "   ++++++ ${description} file ${download_location} is empty"
      exit 255
    fi
  fi
fi