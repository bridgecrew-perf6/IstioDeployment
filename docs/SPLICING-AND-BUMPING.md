# TLS splicing config in Istio

In this guide, you will configure Istio to apply TLS splicing strategy for the following scenarios:
- Splicing without HTTP CONNECT

In TLS splicing scenario, after TCP connection is established between client and Envoy, any subsequent TLS traffic is forwarded to upstream server as raw TCP data. This is required for client to access some external services where connection data should not be decoded by Envoy. For more info about TLS splicing please refer to [SSL peek and slice][1].

Prerequisites
- Kubernetes installed
- Istio installed

Use the following command to load splicing without HTTP CONNECT config:

```bash
kubectl apply -f tls_splicing_bumping/splicing-without-connect.yaml
```

The config creates a ingress gateway to act as a forward proxy, registers virtual service rule and external service entry to implement TLS passthrough for external service.

Client outside the mesh could use cluster ingress gateway to access external services with TLS splicing:
```bash
source tls_splicing_bumping/ingress_env
curl -s -v  --resolve www.bankofamerica.com:$SECURE_INGRESS_PORT:$INGRESS_HOST https://www.bankofamerica.com:$SECURE_INGRESS_PORT
```

[1]: <https://wiki.squid-cache.org/Features/SslPeekAndSplice> "SSL peek and slice"
