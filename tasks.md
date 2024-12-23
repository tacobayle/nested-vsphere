to be done:
- create readonly user for:
  - vSphere
  - NSX
  - Avi
- password will be configured statically in variables.json
- Avi SE folders
- logs in html page and/or in container logs
- progress in html page
- create the NSX egress infra config:

Antrea Egress config


ubuntu@nic-vsphere-nsx-avi-gw:~/tkc$ k get pod -A
NAMESPACE                      NAME                                                                   READY   STATUS    RESTARTS        AGE
kube-system                    antrea-agent-jdnrn                                                     2/2     Running   0               115s
kube-system                    antrea-agent-ms8tr                                                     2/2     Running   0               6m1s
kube-system                    antrea-controller-66b8f6f958-xjl5c                                     1/1     Running   0               6m1s
kube-system                    coredns-7f9465b548-wp8zb                                               1/1     Running   0               7m7s
kube-system                    coredns-7f9465b548-zxsjz                                               1/1     Running   0               5m15s
kube-system                    docker-registry-ns1-cluster-1-provider-4ltb6-nwqdg                     1/1     Running   0               7m7s
kube-system                    docker-registry-ns1-cluster-1-provider-node-pool-1-h6mg4-fk58s-psv59   1/1     Running   0               113s
kube-system                    etcd-ns1-cluster-1-provider-4ltb6-nwqdg                                1/1     Running   0               7m16s
kube-system                    kube-apiserver-ns1-cluster-1-provider-4ltb6-nwqdg                      1/1     Running   0               7m10s
kube-system                    kube-controller-manager-ns1-cluster-1-provider-4ltb6-nwqdg             1/1     Running   0               7m11s
kube-system                    kube-proxy-99prm                                                       1/1     Running   0               7m7s
kube-system                    kube-proxy-hhf87                                                       1/1     Running   0               115s
kube-system                    kube-scheduler-ns1-cluster-1-provider-4ltb6-nwqdg                      1/1     Running   0               7m12s
kube-system                    metrics-server-7554ddbbdf-gmmp9                                        1/1     Running   0               6m
kube-system                    snapshot-controller-6b4f54d54f-7qhxk                                   1/1     Running   0               6m4s
secretgen-controller           secretgen-controller-67bf8cb69c-cxz4b                                  1/1     Running   0               5m47s
tkg-system                     kapp-controller-54f8788594-7svbx                                       2/2     Running   0               6m27s
vmware-system-antrea           interworking-76d6c57f67-jmm8z                                          4/4     Running   4 (3m39s ago)   6m
vmware-system-antrea           register-55744b84f5-m8gv9                                              1/1     Running   0               6m
vmware-system-auth             guest-cluster-auth-svc-cn9q7                                           1/1     Running   0               5m40s
vmware-system-cloud-provider   guest-cluster-cloud-provider-64c9986777-9ndlf                          1/1     Running   0               6m9s
vmware-system-csi              vsphere-csi-controller-5bb889c658-lfz9t                                7/7     Running   0               6m5s
vmware-system-csi              vsphere-csi-node-bg8pb                                                 3/3     Running   0               115s
vmware-system-csi              vsphere-csi-node-jjsp7                                                 3/3     Running   2 (4m50s ago)   6m5s
ubuntu@nic-vsphere-nsx-avi-gw:~/tkc$
ubuntu@nic-vsphere-nsx-avi-gw:~/tkc$

k exec -it interworking-76d6c57f67-jmm8z -n vmware-system-antrea -c election-runner -- /bin/bash

copy the path of the segment of the guest cluster: /infra/segments/vnet_72650c98-1f37-4474-85fd-bd96009c040f_0



root@ns1-cluster-1-provider-4ltb6-nwqdg:/#
root@ns1-cluster-1-provider-4ltb6-nwqdg:/# antreansxctl --nsx-managers=nsx-manager-01.avi.com --user=admin --password 'sGN#FBiN@UKY1!67' child-segment-create --cidr="192.168.50.0/24" --gateway="192.168.50.1" --parent="/infra/segments/vnet_72650c98-1f37-4474-85fd-bd96009c040f_0" --vlan=10 segment-staging-egress
I1101 10:51:09.790217      36 cluster.go:278] Configure NSX client for manager IP nsx-manager-01.avi.com
I1101 10:51:09.904438      36 cluster.go:132] Selected endpoint index: 0, ip: nsx-manager-01.avi.com
----- Create CHILD segment result -----
CIDR                 Gateway              VLAN     BindingMap                     Segment-Path
192.168.50.0/24      192.168.50.1         10       bindingmap-10-qqr7pj4w         /infra/segments/segment-staging-egress-hn64972j
root@ns1-cluster-1-provider-4ltb6-nwqdg:/#



root@ns1-cluster-1-provider-4ltb6-nwqdg:/# antreansxctl --nsx-managers=nsx-manager-01.avi.com --user=admin --password 'sGN#FBiN@UKY1!67' child-segment-create --cidr="192.168.51.0/24" --gateway="192.168.51.1" --parent="/infra/segments/vnet_72650c98-1f37-4474-85fd-bd96009c040f_0" --vlan=20 segment-production-egress
I1101 10:52:20.747271      41 cluster.go:278] Configure NSX client for manager IP nsx-manager-01.avi.com
I1101 10:52:20.871364      41 cluster.go:132] Selected endpoint index: 0, ip: nsx-manager-01.avi.com
----- Create CHILD segment result -----
CIDR                 Gateway              VLAN     BindingMap                     Segment-Path
192.168.51.0/24      192.168.51.1         20       bindingmap-20-mnmhrk8h         /infra/segments/segment-production-egress-6dxlxghp
root@ns1-cluster-1-provider-4ltb6-nwqdg:/#



ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ more external-ip-pool-production.yaml
apiVersion: crd.antrea.io/v1beta1
kind: ExternalIPPool
metadata:
name: external-ip-pool-production
spec:
ipRanges:
- start: 192.168.51.10
  end: 192.168.51.20
  subnetInfo:
  gateway: 192.168.51.1
  prefixLength: 24
  vlan: 20
  nodeSelector: {}
  ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$



ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ more external-ip-pool-staging.yaml
apiVersion: crd.antrea.io/v1beta1
kind: ExternalIPPool
metadata:
name: external-ip-pool-staging
spec:
ipRanges:
- start: 192.168.50.10
  end: 192.168.50.20
  subnetInfo:
  gateway: 192.168.50.1
  prefixLength: 24
  vlan: 10
  nodeSelector: {}
  ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$



ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ k apply -f external-ip-pool-production.yaml
externalippool.crd.antrea.io/external-ip-pool-production created
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$



ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ k apply -f external-ip-pool-staging.yaml
externalippool.crd.antrea.io/external-ip-pool-staging created
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ k get eip
NAME                          TOTAL   USED   AGE
external-ip-pool-production   11      0      65s
external-ip-pool-staging      11      0      11s
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$



ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$ more egress-staging-web.yaml
apiVersion: crd.antrea.io/v1beta1
kind: Egress
metadata:
name: egress-staging-web
spec:
appliedTo:
namespaceSelector:
matchLabels:
kubernetes.io/metadata.name: staging
podSelector:
matchLabels:
app: web
externalIPPool: external-ip-pool-staging
ubuntu@nic-vsphere-nsx-avi-gw:~/yaml-files$




done:
- allow the capability to change AKO config for each k8s/tkg cluster
- deploy gw and esxi simultaneously
- wait before templating workload clusters and yaml ako values files 
- add the pod for egress demo
- update vault token in the html page
- http web server disable http



validated:
- create details.html and other documentation pages
- asynchronous download of the binaries
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



