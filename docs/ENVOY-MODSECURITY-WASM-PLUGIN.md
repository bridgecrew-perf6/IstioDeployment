# Envoy Modsecurity Wasm Plugin to implement a WAF in http filter chain

In this guide you will deploy a modsecurity wasm plugin into your istio ingress-gateway/sidecar http filter chain.

Use the following command for the installation:

```bash
kubectl apply -f istio-intel-envoy-wasm-modsecurity.yaml
```

If you want to maintain your own rule service to configure the modsecurity rules of the wasm filter inside istio mesh, you can use the following command to deploy a rules service and patch it to your istio.

```bash
kubectl apply -f rule-mod-svc.yaml
kubectl apply -f rule-patch-envoy.yaml
kubectl apply -f istio-intel-envoy-wasm-modsecurity-dynamic.yaml`
```
