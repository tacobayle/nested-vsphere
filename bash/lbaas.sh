
lbaas_username=$(jq -c -r '.avi.lbaas_username' $jsonFile)
GENERIC_PASSWORD=$(jq -c -r .spec.generic_password $jsonFile)
cidr_mgmt=$(jq -c -r --arg arg "MANAGEMENT" '.spec.networks[] | select( .type == $arg).cidr' $jsonFile | cut -d"/" -f1)
if [[ ${cidr_mgmt} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ; then
  cidr_mgmt_three_octets="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
fi
ip_avi="${cidr_mgmt_three_octets}.$(jq -c -r .avi.ip_controller $jsonFile)"
avi_version=$(jq -c -r .spec.avi.version $jsonFile)
lbaas_tenant=$(jq -c -r '.avi.lbaas_tenant' $jsonFile)
ip_nsx="${cidr_mgmt_three_octets}.$(jq -c -r .nsx.ip_manager $jsonFile)"