to be done:
- create readonly user for:
  - vSphere
  - NSX
  - Avi
- password will be configured statically in variables.json
- Avi SE folders
- logs in html page and/or in container logs
- progress in html page



done:
- add openshift capabilities for vsphere-avi deployment
- update k8s config script to generate a cert and import it into a k8s secret
- update unmanged k8s version to 1.32
- update cni version (antrea, cilium, calico)
- create doc for vanilla k8s clusters
- add self service portal demo link in details.html for vsphere-nsx-avi use kind
- create an auth script for ns
- generate dynamically tkgs-workload.html
- manage AKO 1.13.1
- configure tanzu using tanzu.supernet_namespace and tanzu.supernet_vip
- create a NSX-T LB for migration scenario:
  - create a new dedicated tier1 with "lb: true"
  - rewrite tier1s if "lb: true" by adding "nsx_vip_cidr" coming from ".spec.nsx.supernet_vip"
  - create routes in the gw for the tier1 that have "lb: true"
  - create NSX lb
  - create NSX pool lb
  - create NSX cert ca
  - create NSX app ca
  - create NSX VS
- create a Tanzu ns for VM service:
  - create the ns4
  - associate the policies and content library specific for vms
- allow the capability to change AKO config for each k8s/tkg cluster from variables.json
- add the pod for egress demo




validated:
- ESXi boots on cdrom based on SATA controller
- LBaaS: use vrf_ref (for pool) and vrf_context_ref (for vs_vip) instead of tier1_lr
- create a scenario for preserve client ip:
  - create a new dedicated tier1
  - create a new segment with urpf_mode disabled (for the VIP)
  - create a new segment for servers
  - create a new NSX group for backend pool
  - create a dedicated seg with HA active standby
  - create a new network service linked with proper SEG, VRF and floating IP
  - create a new application profile with preserve_ip enabled
  - create a new VS with the application profile
- update tkgs-workload.html with copied capability
- update vault token in the html page
- http web server disable http
- deploy gw and esxi simultaneously
- create details.html and other documentation pages
- asynchronous download of the binaries
- wait before templating workload clusters and yaml ako values files
- create a readonly shell user in the external-gw
- tkc template for class: builtin-generic-v3.2.0
- LBaaS: "Load Balancer Created Successfully!" replaced by "Application Created Successfully!"
- remove folder client VMs
- Antrea NSX integration
- datascript creation (ansible)
- create multiple ns in k8s
- fix the ptr of the VCSA appliance
- remove traffic_gen_gw.sh.template
- create yaml file for ingress-regex
- remove client VMs (only use external gw for traffic)
- issue traffic from gw (vsphere-nsx-avi use case)