#!/bin/bash
#
source /nested-vsphere/bash/govc/govc_init.sh
#
vsphere_host="$(jq -r .spec.vsphere_underlay.vcsa $jsonFile)"
vsphere_username=$(jq -c -r '.spec.vsphere_underlay.username' $jsonFile)
vcenter_domain=""
vsphere_password=$(jq -c -r '.spec.vsphere_underlay.password' $jsonFile)
vsphere_dc="$(jq -r .spec.vsphere_underlay.datacenter $jsonFile)"
vsphere_cluster="$(jq -r .spec.vsphere_underlay.cluster $jsonFile)"
vsphere_datastore="$(jq -r .spec.vsphere_underlay.datastore $jsonFile)"
#
load_govc