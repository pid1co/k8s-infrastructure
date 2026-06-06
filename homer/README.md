# Talos Install

```
talosctl gen config pid1labs https://192.168.168.15:6443  --install-image=d4ed705ed680e200144df495701db951b85ec0361e2868456643ee721a497344 --install-disk /dev/nvme0n1 --config-patch @cni.yaml
```

```
helm install \
    cilium \
    cilium/cilium \
    --version 1.19.2 \
    --namespace kube-system \
    --set operator.replicas=1 \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set k8sServiceHost=localhost \
    --set k8sServicePort=7445
```

```
talosctl patch mc --nodes 192.168.168.15 --talosconfig=./talosconfig -e 192.168.168.15 --patch @nvidia-patch.yaml
talosctl patch mc --nodes 192.168.168.15 --talosconfig=./talosconfig -e 192.168.168.15 --patch @flux-extra-manifests.yaml
```
