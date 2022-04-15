# Istio deployments with Intel features

This repository contains Kubernetes (k8s) deployment files for Istio with Intel features enabled.

## 21.12 release

The main features are (click the link to get more info and deployment instructions)

* [Istio TLS handshake acceleration with ICX AVX512 crypto](docs/CRYPTOMB.md)
* [Istio acceleration and compression with QAT2.0](docs/QAT.md)
* [Istio CA private key protection with SGX and key management](docs/SGX.md)
* [Istio multi-tenancy with multiple CA certificates](multi-ca/README.md)
* [Cert manager with SGX support](cert-manager-sgx/README.md)
* [Istio modsecurity WASM plugin](docs/ENVOY-MODSECURITY-WASM-PLUGIN.md)
* [Istio splicing (without http connect)](docs/SPLICING-AND-BUMPING.md)
* [Bypass TCP/IP stack using eBPF](docs/TCPIP-BYPASS.md)
* Support for Kubernetes version 1.22 unless otherwise mentioned
* Support for Istio version 1.12.0 unless otherwise mentioned
* Support for cert-manager version 1.4.2 unless otherwise mentioned

## Install

For all the feature deployments the following steps are required.

Clone this repository:

```bash
git clone https://github.com/intel-innersource/applications.services.cloud.istio.deployment.git deployment
cd deployment
```

Install the prerequisites:

* [cert-manager](https://cert-manager.io/)
* [Intel device plugins for Kubernetes](https://github.com/intel/intel-device-plugins-for-kubernetes)

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.4.2 --create-namespace --set featureGates="ExperimentalCertificateSigningRequestControllers=true" --set installCRDs=true
kubectl apply -k https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/operator/default?ref=v0.23.0
```
