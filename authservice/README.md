# AuthService Deployment

This document and directory provides instructions how to deploy the following components to your kubernetes cluster.

- Certificate Manager and keycloak
- Authservice and authservice configurator
- Istio with external authz provider (authservice)

## Certificate Manager and keycloak

Use the following command to deploy:

```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.3/cert-manager.yaml
kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes-examples/keycloak.yaml
```

## Authservice and authservice configurator

Use the following command to deploy:

```bash
kubectl apply -f authservice.yaml
kubectl apply -f authservice-configurator.yaml
kubectl apply -f chain.yaml
```

## Istio

Use the following command to deploy:

```bash
istioctl install -f ../istio/istio-ext-authz-authservice.yaml
kubectl apply -f istio/
```
