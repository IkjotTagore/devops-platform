#it's so much easier to do this in bash script form than manually one by one
set -euo pipefail

#Configs
K3S_VERSION="v1.29.2+k3s1"
ARGOCD_VERSION="v2.10.0"
HARBOR_VERSION="1.14.0"
NAMESPACE_PLATFORM="platform-system"
REGISTRY_HOST="registry.local"

#Check for prerequisites
echo "Checking for prerequisites >:)"
for cmd in curl kubect helm docker; do
    if command -v $cmd &>dev/null;then
        echo "All of the $cmd have been found ($(cmd -v $cmd))"
    else
        echo "Yo. You need $cmd installed. Do it." && exit 1
    fi
done

#Install K3S
echo "Time to install k3s. The version is ${K3S_VERSION}"
if kubectl cluster-info &>/dev/null 2>&1; then
    echo "Warning: It looks like the cluster is already running, I'm just going to skip a step."
else
    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_VERSION=${K3S_VERSION} \
        K3S_KUBECONFIG_MODE="644" \
        sh -s - server \
          --disable traefik \
          --disable servicelb \
          --flannel-backend=none \
          --disable-network-policy \
          --cluster-init
    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config
    echo "Cool. k3s is installed and I set up your kubeconfig too."
fi

#Installing Cilium CNI
echo "Next is installing Cilium CNI."
helm repo add cilium https://helm.cilium.io/ --force-update 
helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=127.0.0.1 \
    --set k8sServicePort=6443 \
    --set hubble.enabled = true \
    --set hubble.ui.enabled = true \
    --wait
echo "I'm done installing Cilium."

#Installing MetalLB
echo "Next we're going to be installing MetalLB."
helm repo add metallb https://metallb.github.io/metallb --force-update
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --wait

# Configure IP address pool (adjust range for your local network)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.200-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
echo "MetalLB has been installed"

#Install Nginx Ingress Controller
echo "Next up is installing the Nginx Ingress Controller."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait
echo "Nginx Ingress installed"
