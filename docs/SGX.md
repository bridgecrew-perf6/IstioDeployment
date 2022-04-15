# Istio service mesh and SGX key protection

In this guide, you will install Istio with SGX key protection into your kubernetes cluster. The first option is to install with SGX remote attestation which requires working [SGX DCAP environment](https://github.com/intel/SGXDataCenterAttestationPrimitives). The second option is to install without SGX remote attestation where the DCAP is not required.

In both options, Istio service mesh is configured to [use custom CA](https://istio.io/latest/docs/tasks/security/cert-management/custom-ca-k8s/#part-2-using-custom-ca) which is external component to the service mesh.

Prerequisites

- Kubernetes cluster with one or more nodes with Intel® [SGX](https://software.intel.com/content/www/us/en/develop/topics/software-guard-extensions.html) supported hardware

The following deployments are required for both options.

- Certificate Manager
- Node Feature Discovery
- [Intel kubernetes device plugin](https://github.com/intel/intel-device-plugins-for-kubernetes) operator
- SGX device plugin

Use the following commands to deploy the prerequisites:

```bash
kubectl apply -k https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/sgx_nfd\?ref\=v0.23.0
kubectl apply -k https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/operator/default\?ref\=v0.23.0
kubectl apply -f sgx/sgxdeviceplugin.yaml
```

## Istio CA key protection with SGX and remote attestation

*NOTE:* This feature is not yet ready for the 21.12 release.
### SGX attestation and key management

This installation option requires working DCAP environment.

Start with deploying the required SGX components:

```bash
kubectl apply -f sgx/
```

Verify that the SGX quote attestation custom resource (CR) is created:

```bash
kubectl get quoteattestations.sgx.intel.com -n sgx-operator sgx.quote.attestation.deliver
NAME                            AGE
sgx.quote.attestation.deliver   6m53s
```

Next, the private key needs to be delivered to the kubernetes cluster SGX enclave from an external key management system. The following external command line tools are required. The tools are part of the [KMRA project](https://01.org/key-management-reference-application-kmra).

- km-attest
- km-wrap

Extract the public key and quote from the `sgx.quote.attestation.deliver` CR with the following commands:

```bash
kubectl get quoteattestations.sgx.intel.com -n sgx-operator sgx.quote.attestation.deliver -o jsonpath='{.spec.publicKey}' | base64 -d > /tmp/public.key
kubectl get quoteattestations.sgx.intel.com -n sgx-operator sgx.quote.attestation.deliver -o jsonpath='{.spec.quote}' | base64 -d > /tmp/quote.data
```

The next command (`km-attest`) needs to be executed on a machine with SGX in order to succseed. Use `km-attest` tool to do the SGX quote attestation using the public key and quote from the previous step:

```bash
km-attest --pubkey /tmp/public.key --quote /tmp/quote.data
Public key hash verification successful
SGX_QL_QV_RESULT_OK
Quote is correct, platform contains latest TCB.
Quote verification successful
```

In case you don't have the private key you can generate one with the following command:

```bash
openssl genrsa -out /tmp/ca-private.key 3072
```

Use the `km-wrap` tool to wrap the private key and store it in `WRAPPED_KEY` environment variable:

```bash
WRAPPED_KEY=$(km-wrap --pubkey /tmp/public.key --privkey /tmp/ca-private.key --pin 1234 --token SgxOperator)
```

Next, you need to create kubernetes secret, in the correct namespace, which contains the wrapped private key:

```bash
kubectl create secret generic -n sgx-operator wrapped-key --from-literal=wrappedKey=${WRAPPED_KEY}
```

Finally, you need to update (patch) `sgx.quote.attestation.deliver` CR. This step will trigger the SGX operator reconcile loop to process the updated CR, unwrap the key and store the key into SGX enclave.

```bash
kubectl proxy --port=9091 &
PROXY_PID=$!
trap 'kill "$PROXY_PID"' EXIT
#wait for proxy to open
sleep 2
curl --header "Content-Type: application/json-patch+json" --request PATCH \
--data '[{"op": "add", "path": "/status/secrets", "value": {"intel.com/sgx": {"secretName": "wrapped-key", "secretType": "KMRA"}}}, {"op": "add", "path": "/status/condition", "value": {"message": "Quote verification success", "type": "Success"}}]' \
http://localhost:9091/apis/sgx.intel.com/v1alpha1/namespaces/sgx-operator/quoteattestations/sgx.quote.attestation.deliver/status
```

NOTE: in the next release, the automatic key management will handle this step.

You can can verify that the SGX operator unwrapped the key sucessfully and stored the private key in the SGX from the logs:

```bash
kubectl logs -n sgx-operator -l control-plane=sgx-operator -f
...
2021-10-05T14:35:46.457Z	INFO	setup	Unwrapped SWK Key successfully
2021-10-05T14:35:46.530Z	INFO	setup	Unwrapped PWK Key successfully
2021-10-05T14:35:46.580Z	INFO	setup	Unwrapped Public Key successfully
```

### Installing Istio

Before installing Istio you need to export the SGX operator root certificate to Istio so it can trust the certificate.

```bash
kubectl create namespace istio-system || true
cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: external-ca-cert
  namespace: istio-system
data:
  root-cert.pem: $(kubectl get secret -n sgx-operator sgx-ca-signer -o jsonpath='{.data.tls\.crt}')
EOF
```

Install Istio with the custom CA configuration using the following command:

```bash
istioctl install -f istio/istio-intel-custom-ca.yaml
```

Now your cluster is using the private key inside the SGX enclave and is ready to start signing the Istio service mesh workload certificates.

### Verify that the system is working

In order to verify that the system is working, you need to enable Istio on a namespace. We will use the `default`namespace:

```bash
kubectl label namespace default istio-injection=enabled
```

Next, deploy a sample (sleep) workload to the `default` namespace:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
```

Verify that the pod's trusted certificate and SGX operator certificate are the same. First, get the certificate chain and CA root certificate used by the Istio proxies for mTLS:

```bash
istioctl pc secret <sleep-pod-name> -o json > proxy_secret
```

The proxy_secret json file contains the CA root certificate for mTLS in the trustedCA field. Note that this certificate is base64 encoded.

Compare the CA root certificate obtained in the step above with SGX operator CA cert.

```bash
kubectl get secret -n sgx-operator sgx-ca-signer -o jsonpath='{.data.tls\.crt}'
```

These two certificates should be the same.

## Istio CA key protection with SGX

This installation option does not require DCAP environment.

Befor deploying the SGX operator the key management needs to be (manually) disabled in the `sgx/sgx-operator.yaml`. Add the `--use-key-manager=false` to the deployment (`spec.template.spec.containers.args`). **NOTE**: this will be automated in the future releases.

Deploy the SGX operator:

```bash
kubectl apply -f sgx/sgx-operator.yaml
```

The default configuration comes with the following signer name(s):
- sgx.intel.com/istio-system

Check the `istio/istio-intel-custom-ca.yaml` and `sgx/sgx-operator.yaml` how to add more signers. Each namescape requires its own signer. *NOTE*: this will be fixed to be more flexible in the next release.

Get the root certificate:

```console
kubectl get secrets -n sgx-operator sgx.intel.com.istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d
```

Edit the `istio/istio-intel-custom-ca.yaml` and replace the certificate in there with the output of the previous command.

Deploy istio with custom CA (SGX operator)

```bash
istioctl install -f ./istio-intel-custom-ca.yaml
```

Now your cluster is using the private key inside the SGX enclave and is used to sign the workload certificates.

The verification of the system is the same as in the other option.
