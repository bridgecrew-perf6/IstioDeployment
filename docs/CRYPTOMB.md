# Istio acceleration ICX AVX512 crypto

In this guide you will install Istio with the following Intel acceleration features enabled:

- AVX-512 crypto acceleration for TLS connections
- AVX-512 vector AES for symmetric data encryption

You have two options for the Istio Envoy SSL engine:

- BoringSSL
- OpenSSL

The following sections discuss bot options and how to install them

## BoringSSL

Use the following command for the installation:

```bash
istioctl install -y -f istio/istio-intel-cryptomb.yaml
```

The crypto accelerartion is used both in `istio-ingress-gateway` and `istio-proxy` sidecar containers.

## OpenSSL

Use the following command for the installation:

```bash
istioctl install -y -f istio/istio-intel-qat-sw.yaml
```

The crypto accelerartion is used both in `istio-ingress-gateway` and `istio-proxy` sidecar containers.

**NOTE**: requires Istio version 1.9 or older

