#!/bin/bash
jsonFile="${1}"
source /home/ubuntu/bash/variables.sh
#
domain="${avi_subdomain}.${domain}"
# ingress - update host
ingress=$(yq . /home/ubuntu/yaml-files/demo-http-ingress.yml)
ingress=$(echo $ingress | jq '. | del (.spec.rules[0].host)')
ingress=$(echo $ingress | jq '.spec.rules[0] += {"host": "v1.'${domain}'"}')
ingress=$(echo $ingress | jq '. | del (.spec.rules[1].host)')
ingress=$(echo $ingress | jq '.spec.rules[1] += {"host": "v2.'${domain}'"}')
ingress=$(echo $ingress | jq '. | del (.spec.rules[2].host)')
ingress=$(echo $ingress | jq '.spec.rules[2] += {"host": "v3.'${domain}'"}')
echo $ingress | yq -y . | tee /home/ubuntu/yaml-files/demo-http-ingress.yml > /dev/null
# ingress-np - update host
ingress=$(yq . /home/ubuntu/yaml-files/demo-http-ingress-np.yml)
ingress=$(echo $ingress | jq '. | del (.spec.rules[0].host)')
ingress=$(echo $ingress | jq '.spec.rules[0] += {"host": "v1.'${domain}'"}')
ingress=$(echo $ingress | jq '. | del (.spec.rules[1].host)')
ingress=$(echo $ingress | jq '.spec.rules[1] += {"host": "v2.'${domain}'"}')
ingress=$(echo $ingress | jq '. | del (.spec.rules[2].host)')
ingress=$(echo $ingress | jq '.spec.rules[2] += {"host": "v3.'${domain}'"}')
echo $ingress | yq -y . | tee /home/ubuntu/yaml-files/demo-http-ingress-np.yml > /dev/null
# ingress-regex - update host
ingress=$(yq . /home/ubuntu/yaml-files/demo-http-ingress-regex.yml)
ingress=$(echo $ingress | jq '. | del (.spec.rules[0].host)')
ingress=$(echo $ingress | jq '.spec.rules[0] += {"host": "ingress-regex.'${domain}'"}')
echo $ingress | yq -y . | tee /home/ubuntu/yaml-files/demo-http-ingress-regex.yml > /dev/null
#
# crd - update fqdn
#
crd=$(yq . /home/ubuntu/yaml-files/demo-http-ingress-regex-crd.yml)
crd=$(echo $crd | jq '. | del (.spec.virtualhost.fqdn)')
crd=$(echo $crd | jq '.spec.virtualhost += {"fqdn": "ingress-regex.'${domain}'"}')
echo $crd | yq -y . | tee /home/ubuntu/yaml-files/demo-http-ingress-regex-crd.yml > /dev/null
#
crd=$(yq . /home/ubuntu/yaml-files/demo-http-crd-1.yml)
crd=$(echo $crd | jq '. | del (.spec.virtualhost.fqdn)')
crd=$(echo $crd | jq '.spec.virtualhost += {"fqdn": "v1.'${domain}'"}')
echo $crd | yq -y . | tee /home/ubuntu/yaml-files/demo-http-crd-1.yml > /dev/null
#
crd=$(yq . /home/ubuntu/yaml-files/demo-http-crd-2.yml)
crd=$(echo $crd | jq '. | del (.spec.virtualhost.fqdn)')
crd=$(echo $crd | jq '.spec.virtualhost += {"fqdn": "v2.'${domain}'"}')
echo $crd | yq -y . | tee /home/ubuntu/yaml-files/demo-http-crd-2.yml > /dev/null
#
crd=$(yq . /home/ubuntu/yaml-files/demo-http-crd-3.yml)
crd=$(echo $crd | jq '. | del (.spec.virtualhost.fqdn)')
crd=$(echo $crd | jq '.spec.virtualhost += {"fqdn": "v3.'${domain}'"}')
echo $crd | yq -y . | tee /home/ubuntu/yaml-files/demo-http-crd-3.yml > /dev/null
#
cat /home/ubuntu/yaml-files/demo-http-crd-1.yml | tee /home/ubuntu/yaml-files/demo-http-crds.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-http-crds.yml
cat /home/ubuntu/yaml-files/demo-http-crd-2.yml | tee -a /home/ubuntu/yaml-files/demo-http-crds.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-http-crds.yml
cat /home/ubuntu/yaml-files/demo-http-crd-3.yml | tee -a /home/ubuntu/yaml-files/demo-http-crds.yml
rm /home/ubuntu/yaml-files/demo-http-crd-1.yml > /dev/null
rm /home/ubuntu/yaml-files/demo-http-crd-2.yml > /dev/null
rm /home/ubuntu/yaml-files/demo-http-crd-3.yml > /dev/null
#
# gw - domain update and cert update
#
gw=$(yq . /home/ubuntu/yaml-files/demo-gw-multiple-listeners.yml)
gw=$(echo ${gw} | jq '. | del (.spec.listeners[0].hostname)')
gw=$(echo ${gw} | jq '. | del (.spec.listeners[1].hostname)')
gw=$(echo ${gw} | jq '.spec.listeners[0] += {"hostname": "*.'${domain}'"}')
gw=$(echo ${gw} | jq '.spec.listeners[1] += {"hostname": "*.'${domain}'"}')
echo ${gw} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-multiple-listeners.yml > /dev/null
#
gw=$(yq . /home/ubuntu/yaml-files/demo-gw-single-listener.yml)
gw=$(echo ${gw} | jq '. | del (.spec.listeners[0].hostname)')
gw=$(echo ${gw} | jq '.spec.listeners[0] += {"hostname": "*.'${domain}'"}')
echo ${gw} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-single-listener.yml > /dev/null
#
# gw http routes update
#
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-1.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v1.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-1.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-2.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v2.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-2.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-3.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v3.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-3.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-migration.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2.yml > /dev/null
#
cat /home/ubuntu/yaml-files/demo-gw-http-route-1.yml | tee /home/ubuntu/yaml-files/demo-gw-http-routes.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-2.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-3.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes.yml
#
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-1_based-on-np.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v1-np.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-1_based-on-np.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-2_based-on-np.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v2-np.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-2_based-on-np.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-3_based-on-np.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-v3-np.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-3_based-on-np.yml > /dev/null
route=$(yq . /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2_based-on-np.yml)
route=$(echo ${route} | jq '. | del (.spec.hostnames)')
route=$(echo ${route} | jq '.spec += {"hostnames": ["gw-migration-np.'"${domain}"'"]}')
echo ${route} | yq -y . | tee /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2_based-on-np.yml > /dev/null
#
cat /home/ubuntu/yaml-files/demo-gw-http-route-1_based-on-np.yml | tee /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-2_based-on-np.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-3_based-on-np.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
echo "---" | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml
cat /home/ubuntu/yaml-files/demo-gw-http-route-multiple-1-2_based-on-np.yml | tee -a /home/ubuntu/yaml-files/demo-gw-http-routes-np.yml