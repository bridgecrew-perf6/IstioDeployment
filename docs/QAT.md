# Istio acceleration and compression with QAT2.0

In this guide you will install Istio with the following Intel acceleration features enabled:

- QAT2.0 crypto acceleration for TLS handshakes
- QAT2.0 compression acceleration for HTTP(s) connections

## Prerequisites

The kubernetes hos requires the folowing preparations

- Install Linux kernel 5.17 or similar (TBD)
- Add QAT firmware (TBD)
- Enable IOMMU
- Enable QAT VF devices
- Enhance the container runtime memory lock limit

To enable IOMMU, add the following change and commands:

```console
/etc/default/grub:GRUB_CMDLINE_LINUX="intel_iommu=on vfio-pci.ids=8086:4941"
update-grub
reboot
````

To enable QAT VF devices, issue the following script (on every boot)

```console
for i in `lspci -D -d :4940| awk '{print $1}'`; do echo 16|sudo tee /sys/bus/pci/devices/$i/sriov_numvfs; done
```

To Enhance the container runtime memory lock limit, add the following file (for containerd, CRIO has similar configuration):

```console
cat /etc/systemd/system/containerd.service.d/memlock.conf
[Service]
LimitMEMLOCK=16777216
```

Restart the container runtime (for containerd, CRIO has similar concept)

```console
systemctl daemon-reload
systemctl restart containerd
```

## Install Istio with QAT2.0 support

## Prerequisites

The kubernetes hos requires the folowing preparations

- Install Linux kernel 5.17 or similar (TBD)
- Add QAT firmware (TBD)
- Enable IOMMU
- Enable QAT VF devices
- Enhance the container runtime memory lock limit

To enable IOMMU, add the following change and commands:

```console
/etc/default/grub:GRUB_CMDLINE_LINUX="intel_iommu=on vfio-pci.ids=8086:4941"
update-grub
reboot
````

To enable QAT VF devices, issue the following script (on every boot)

```console
for i in `lspci -D -d :4940| awk '{print $1}'`; do echo 16|sudo tee /sys/bus/pci/devices/$i/sriov_numvfs; done
```

To Enhance the container runtime memory lock limit, add the following file (for containerd, CRIO has similar configuration):

```console
cat /etc/systemd/system/containerd.service.d/memlock.conf
[Service]
LimitMEMLOCK=16777216
```

Restart the container runtime (for containerd, CRIO has similar concept)

```console
systemctl daemon-reload
systemctl restart containerd
```

## Install

Use the following command for the installation:

```bash
kubectl apply -f qat/qatdeviceplugin.yaml
istioctl install -y -f istio/istio-intel-qat-hw.yaml
```

### QAT2.0 crypto acceleration for TLS handshakes

QAT2.0 crypto accelerartion is enabled by default for `istio-ingress-gateway`.

Enable QAT2.0 crypto accelerartion for `istio-proxy` sidecars by adding the following annotation to pod/deployment:

```console
inject.istio.io/templates: sidecar,qathw
```

### QAT2.0 compression acceleration for HTTP(s) connections

Enable QAT2.0 compression acceleration for `istio-ingress-gateway`:

```console
kubectl apply -f qat/qat-compression-envoy-filter.yaml
```

Enable QAT2.0 compression acceleration for `istio-proxy` sidecars:

```console
kubectl apply -f  qat/compression-decompression-sidecar-envoy-filter.yaml
```