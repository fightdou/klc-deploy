#!/bin/bash
generate_configmap() {
    # your server name goes here
server=https://kubernetes.default.svc
name=$(kubectl -n default get sa kubesphere -o json | jq -r .secrets[].name)

ca=$(kubectl -n default get secret/$name -o jsonpath='{.data.ca\.crt}')
token=$(kubectl -n default get secret/$name -o jsonpath='{.data.token}' | base64 -d)
namespace=default

cat << EOF
apiVersion: v1
data:
  config: |
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: ${ca}
        server: ${server}
      name: kubernetes
    contexts:
    - context:
        cluster: kubernetes
        user: admin
        namespace: default
      name: admin@kubernetes
    current-context: admin@kubernetes
    kind: Config
    preferences: {}
    users:
    - name: admin
      user:
        token: ${token}
kind: ConfigMap
metadata:
  name: kubeconfig-admin
  namespace: default
EOF
}

generate_kubeconfig_admin() {
    kubectl -n default get cm kubeconfig-admin > /dev/null 2>&1

    if [ $? -ne 0 ];then
      echo "kubeconfig-admin not exist, will be generated..."
      generate_configmap | kubectl create -f -
    fi
}

generate_kubeconfig_admin