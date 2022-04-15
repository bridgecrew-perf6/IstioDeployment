# Documentation for SGX-based cert-manager

## Prerequisites

1. Deploy the Kubernetes cluster.
2. Deploy the SGX device plugin and the SGX admission webhook.
   * Note: If installing the SGX admission webhook with cert-manager dependency, suggest to install
     cert-manager v1.4.2 to avoid compatibility issues.

## Installation

1. (Delete upstream cert-manager deployment that's only used for deploying SGX admission webhook).
   * `kubectl delete deployment cert-manager --namespace cert-manager`
2. Deploy cert-manager using SGX: `kubectl apply -f cert-manager-sgx/`.
   * Note that it is derived from [cert-manager v1.4.2 deployment YAML](https://github.com/jetstack/cert-manager/releases/download/v1.4.2/cert-manager.yaml).
   * To use customized image or configuration, please kindly directly refer to the YAML for changes.

## Usage

1. The administrator is responsible for creating a `HardwareSecurityModuleConfig` with the pkcs11
   library path, token name and pin specified.
   * This should be the first step to setup a SGX-based cert-manager and it does not support update.
     In other words, the admin is only able to create/delete a `hsmconfig` and he/she should
     guarantee that the HSM config is securely provisioned and managed.
   * An example is shown below:
   ```
   apiVersion: experimental.cert-manager.io/v1alpha3
   kind: HardwareSecurityModuleConfig
   metadata:
     name: hsmconfig
     namespace: default
   spec:
     pkcs11LibPath: /usr/local/lib/libp11sgx.so
     pkcs11Token: ctk
     pkcs11Pin: "12345678"
   ```
2. The tenant user is then able to create his/her `HardwareSecurityModule` containing one or
   multiple issuers using SGX with explicit types.
   * The currently supported issuer type are `SelfSigned` and `CA`.
   * For self-signed issuers, the algorithm and size for the generated key can be explicitly defined
     by the user and the root cert's lifecycle will be managed by cert-manager.
     If `privateKeyAlgorithm` is set to `RSA`, valid `privateKeySize` values are `2048`, `4096` or
     `8192`, and will default to `2048` if not specified. If `privateKeyAlgorithm` is set to
     `ECDSA`, valid `privateKeySize` values are `256`, `384` or `521`, and will default to `256` if
     not specified.
     No other values are allowed. And if none is input, the default is RSA 2048.
   * For CA issuers, the key and cert will be onboarded from an external KMS (Key Management Service)
     and the lifecycle is managed by the KMS with cert-manager giving notifications.
   * An example is shown below:
   ```
   apiVersion: experimental.cert-manager.io/v1alpha3
   kind: HardwareSecurityModule
   metadata:
     name: hsm-mix-1
     namespace: default
   spec:
     issuers:
       clusterissuers.cert-manager.io/intel:
         issuerType: SelfSigned
         privateKeyAlgorithm: RSA
         privateKeySize: 2048
       issuers.cert-manager.io/default.ssintel:
         issuerType: SelfSigned
       issuers.cert-manager.io/default.caintel:
         issuerType: CA
   ```
