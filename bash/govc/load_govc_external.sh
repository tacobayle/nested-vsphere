#!/bin/bash
#
source /nested-vsphere/bash/govc/govc_init.sh
#
vsphere_host="$(jq -r .spec.vsphere_underlay.vcsa $jsonFile)"
vsphere_username=${VSPHERE_EXTERNAL_USERNAME}
vcenter_domain=""
vsphere_password=${VSPHERE_EXTERNAL_PASSWORD}
vsphere_dc="$(jq -r .spec.vsphere_underlay.datacenter $jsonFile)"
vsphere_cluster="$(jq -r .spec.vsphere_underlay.cluster $jsonFile)"
vsphere_datastore="$(jq -r .spec.vsphere_underlay.datastore $jsonFile)"
#
load_govc