# Integration With cert-manager

This README will indicate the entirely process on how the Istio can integrate with cert-manager for workloads and verify the network connectivity between these workload.

In this README:

- [Introduction](#introduction)
- [Process](#process)

## Introduction

[cert-manager](https://cert-manager.io/docs/) is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. User can use cert-manager to approve and sign CSR from workloads which are deployed in service mesh. It means that different workloads can hold different CA respectively. This is the highlight feature: multiple CA feature based on Istio.
In the following, this doc will introduce the integration process step by step from repos build to verification.

## Process

### Step 1: Retrieve images for Istio
  All necessary images for `Istio` can be located under the project of `istio-intel` in `registry.fi.intel.com`

- **Istio images**

  - staging/proxyv2-multica
  - staging/pilot-multica


> Note: All images' tags are latest. Make sure that `registry.fi.intel.com` is available for user

### Step 2: Install cert-manager(make sure to enable featureGate: `ExperimentalCertificateSigningRequestControllers`)

```bash
$ helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set featureGates="ExperimentalCertificateSigningRequestControllers=true" --set installCRDs=true
```
You can also follow other cert-manager installation option as listed in https://cert-manager.io/docs/installation/


### Step 3: Create Issuers of cert-manager
   There are 2 Issuer types can be supported: **CA Issuer** and **SelfSigned Issuer**, you need to generate key/cert before hand for the former one, and the lattter one will generate key/cert for you automatically. Choose one of them accoridng to your needs.

- **SelfSigned Issuer**

 Create 2 SelfSigned Issuers according to [selfsigned-issuer.yaml](multi-ca/selfsigned-issuer.yaml)

 ```bash
 $ kubectl apply -f multi-ca/selfsigned-issuer.yaml
 ```

- **CA Issuer**

 1) Create certificate for tenant
   User can create certificate for tenant via `Istio Cert Tools` which located under the directory `istio/tools/certs` of [Isito](https://github.com/istio/istio) project. 

> User need to change the ROOT CA information for every tenant in `common.mk`, then create its certificate according to the README.md file.

 2) Create 2 secrets with keys of `tls.key` and `tls.crt` respectively

 ```bash
 $ kubectl create secret generic foo-ca -n cert-manager \
         --from-file=foo/tls.crt \
         --from-file=foo/tls.key
 $ kubectl create secret generic bar-ca -n cert-manager \
         --from-file=bar/tls.crt \
         --from-file=bar/tls.key
 ```

 3) Create 2 cluster CA issuers according to [ca-issuer.yaml](multi-ca/ca-issuer.yaml)

 ```bash
 $ kubectl apply -f multi-ca/ca-issuer.yaml
 $ kubectl get clusterissuer -o wide
 ```

### Step 4: Create istio operator file to install Istio

 1) Save root certs for your cluster issuers into file:

  ```bash
 $ kubectl get clusterissuers istio-system -o jsonpath='{.spec.ca.secretName}' | xargs kubectl get secret -n cert-manager -o jsonpath='{.data.ca\.crt}' |base64 -d >istio.ca

 $ kubectl get clusterissuers foo -o jsonpath='{.spec.ca.secretName}' | xargs kubectl get secret -n cert-manager -o jsonpath='{.data.ca\.crt}' |base64 -d >foo.ca

 $ kubectl get clusterissuers bar -o jsonpath='{.spec.ca.secretName}' | xargs kubectl get secret -n cert-manager -o jsonpath='{.data.ca\.crt}' |base64 -d >bar.ca
 ```
 
 2) Edit [istio-certs.yaml](multi-ca/istio-certs.yaml)  to replace root-cert for each of the signers. 

 |  cluster issuer Name   | root-cert  |
|  ----  | ----  |
| clusterissuers.cert-manager.io/istio-system  | content of istio.ca |
| clusterissuers.cert-manager.io/bar  | content of bar.ca  |
| clusterissuers.cert-manager.io/foo  | content of foo.ca  |


### Step 5: Install Istio with cert-signer-domain specified according to [istio-certs.yaml](multi-ca/istio-certs.yaml)

```bash
$ istioctl install -f istio-certs.yaml -y
```

### Step 6: Deploy  Istio proxyconfig Custom resource to specify cert-signers for workloads under `foo` and `bar` namespace.
```bash
$ kubectl create ns bar
$ kubectl apply -f proxyconfig-bar.yaml
$ kubectl create ns foo
$ kubectl apply -f proxyconfig-foo.yaml
```


### Step 7: Deploy workloads in namespaces `foo` and `bar`

```bash
$ kubectl apply -f <(istioctl kube-inject -f samples/httpbin/httpbin.yaml) -n foo
$ kubectl apply -f <(istioctl kube-inject -f samples/sleep/sleep.yaml) -n foo
$ kubectl apply -f <(istioctl kube-inject -f samples/httpbin/httpbin.yaml) -n bar
$ kubectl apply -f <(istioctl kube-inject -f samples/sleep/sleep.yaml) -n bar
```

### Step 8: Verify the network connectivity

- **inside namespace**

Check network connectivity between service sleep and httpbin in `foo`

```bash
$ export SLEEP_POD_FOO=$(kubectl get pod -n foo -l app=sleep -o jsonpath={.items..metadata.name})
$ kubectl exec -it $SLEEP_POD_FOO -n foo -c sleep curl http://httpbin.foo:8000/html
```

Check network connectivity between service sleep and httpbin in `bar`

```bash
$ export SLEEP_POD_BAR=$(kubectl get pod -n bar -l app=sleep -o jsonpath={.items..metadata.name})
$ kubectl exec -it $SLEEP_POD_BAR -n bar -c sleep curl http://httpbin.bar:8000/html
```

The network connectivity should be available and the output looks like below:

```text
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
      <h1>Herman Melville - Moby-Dick</h1>

      <div>
        <p>
          Availing himself of the mild, summer-cool weather that now reigned in these latitudes, and in preparation for the peculiarly active pursuits shortly to be anticipated, Perth, the begrimed, blistered old blacksmith, had not removed his portable forge to the hold again, after concluding his contributory work for Ahab's leg, but still retained it on deck, fast lashed to ringbolts by the foremast; being now almost incessantly invoked by the headsmen, and harpooneers, and bowsmen to do some little job for them; altering, or repairing, or new shaping their various weapons and boat furniture. Often he would be surrounded by an eager circle, all waiting to be served; holding boat-spades, pike-heads, harpoons, and lances, and jealously watching his every sooty movement, as he toiled. Nevertheless, this old man's was a patient hammer wielded by a patient arm. No murmur, no impatience, no petulance did come from him. Silent, slow, and solemn; bowing over still further his chronically broken back, he toiled away, as if toil were life itself, and the heavy beating of his hammer the heavy beating of his heart. And so it was.—Most miserable! A peculiar walk in this old man, a certain slight but painful appearing yawing in his gait, had at an early period of the voyage excited the curiosity of the mariners. And to the importunity of their persisted questionings he had finally given in; and so it came to pass that every one now knew the shameful story of his wretched fate. Belated, and not innocently, one bitter winter's midnight, on the road running between two country towns, the blacksmith half-stupidly felt the deadly numbness stealing over him, and sought refuge in a leaning, dilapidated barn. The issue was, the loss of the extremities of both feet. Out of this revelation, part by part, at last came out the four acts of the gladness, and the one long, and as yet uncatastrophied fifth act of the grief of his life's drama. He was an old man, who, at the age of nearly sixty, had postponedly encountered that thing in sorrow's technicals called ruin. He had been an artisan of famed excellence, and with plenty to do; owned a house and garden; embraced a youthful, daughter-like, loving wife, and three blithe, ruddy children; every Sunday went to a cheerful-looking church, planted in a grove. But one night, under cover of darkness, and further concealed in a most cunning disguisement, a desperate burglar slid into his happy home, and robbed them all of everything. And darker yet to tell, the blacksmith himself did ignorantly conduct this burglar into his family's heart. It was the Bottle Conjuror! Upon the opening of that fatal cork, forth flew the fiend, and shrivelled up his home. Now, for prudent, most wise, and economic reasons, the blacksmith's shop was in the basement of his dwelling, but with a separate entrance to it; so that always had the young and loving healthy wife listened with no unhappy nervousness, but with vigorous pleasure, to the stout ringing of her young-armed old husband's hammer; whose reverberations, muffled by passing through the floors and walls, came up to her, not unsweetly, in her nursery; and so, to stout Labor's iron lullaby, the blacksmith's infants were rocked to slumber. Oh, woe on woe! Oh, Death, why canst thou not sometimes be timely? Hadst thou taken this old blacksmith to thyself ere his full ruin came upon him, then had the young widow had a delicious grief, and her orphans a truly venerable, legendary sire to dream of in their after years; and all of them a care-killing competency.
        </p>
      </div>
  </body>
```

User can also use command line to check the network connectivity via `istioctl`, below is the command and output as an example:

```console
$ istioctl proxy-config rootca-compare httpbin-5f76c56644-5x7tt.foo sleep-7bbcb459d8-57j2w.foo
Both [httpbin-5f76c56644-5x7tt.foo] and [sleep-7bbcb459d8-57j2w.foo] have the identical ROOTCA, theoretically the connectivity between them is available
```

- **across namespaces**

Check network connectivity between service sleep in `foo` and httpbin in `bar`

```bash
$ export SLEEP_POD_FOO=$(kubectl get pod -n foo -l app=sleep -o jsonpath={.items..metadata.name})
$ kubectl exec -it $SLEEP_POD_FOO -n foo -c sleep curl http://httpbin.bar:8000/html
```

Check network connectivity between service sleep in `bar` and httpbin in `foo`

```bash
$ export SLEEP_POD_BAR=$(kubectl get pod -n bar -l app=sleep -o jsonpath={.items..metadata.name})
$ kubectl exec -it $SLEEP_POD_BAR -n bar -c sleep curl http://httpbin.foo:8000/html
```

> Note: In general, services in the same namespace can be available and services across different namespaces can be unavilable.

The network connectivity should be unavailable and the output looks like below:

```text
upstream connect error or disconnect/reset before headers. reset reason: connection failure, transport failure reason: TLS error: 268435581:SSL routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED
```

User can also use command line to check the network connectivity via `istioctl`, below is the command and output as an example:

```console
$ istioctl proxy-config rootca-compare httpbin-5f76c56644-5x7tt.foo httpbin-5f76c56644-qfwkm.bar
Error: Both [httpbin-5f76c56644-5x7tt.foo] and [httpbin-5f76c56644-qfwkm.bar] have the non identical ROOTCA, theoretically the connectivity between them is unavailable
```
