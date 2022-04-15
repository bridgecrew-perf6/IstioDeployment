# Bypass TCP/IP stack using eBPF

In this guide you will install kubernetes daemon sets which loads an eBPF program that accelerates the Istio TCP/IP trafic in the following scenarions:

- Service to service communication when the services are in the same pod
- Service to service communication when the services are in the same node

Use the following command for the installation:

```bash
kubectl apply -f istio-intel-tcpip-bypass-ebpf.yaml
```

Next, install Istio for example with the following command:

```bash
istioctl install
```
