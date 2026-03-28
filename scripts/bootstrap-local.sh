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
    - 172.23.199.200-172.23.199.250
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

#Install the cert manager
echo "Okay, now we're going to install cert manager."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true \
    --wait
kubectl apply -f security/cert-manager/cluster-issuers.yaml
echo "Cert manager has been installed."

#Installing ArgoCD
echo "Next thing is installing ArgoCD."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/MANIFESTS/install.yaml"
echo "Almost there..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s 

kubectl patch configmap argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  --patch '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD installed — admin password: ${ARGOCD_PASSWORD}"

#Installing Kyverno
echo "Oh you think we're done? No, we're installing Kyverno next."
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set admissionController.replicas=1 \
  --wait
kubectl apply -f security/kyverno/cluster-policies.yaml
echo "Kyverno has been installed"

#Install Sealed Secrets
echo "Install the Sealed Secrets controller."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets --force-update
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --wait
echo "Sealed Secrets has been installed"

#Install Prometheus
echo "We're still not done yet...It's time to install the prometheus stack"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.additionalRuleFiles[0]=alert-rules.yaml \
  --wait
kubectl apply -f observability/prometheus/alert-rules.yaml
echo "Prometheus stack installed"

#Install Loki
echo "Loki."
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm upgrade --install loki grafana/loki-stack \
  --namespace observability \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=20Gi
echo "Loki installed"

#Install KEDA
echo "help. KEDA."
helm repo add kedacore https://kedacore.github.io/charts --force-update
helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --wait
echo "KEDA installed"

#Creating Namespaces
echo "Ok almost done, We're making the namespaces now."
for ns in dev staging production; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace $ns environment=$ns --overwrite
  kubectl apply -f k8s/network-policies/production-policies.yaml -n $ns 2>/dev/null || true
done
kubectl apply -f k8s/rbac/roles.yaml
echo "Namespaces and RBAC have been configured"

#Bootstrap ArgoCD app of apps
echo "LAST THING LETS GOOOOOO. Bootstrapping the GitOps App of Apps"
kubectl apply -f gitops/apps/root-app.yaml
echo "App of Apps deployed — ArgoCD will do the rest"

#Summary
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo ""  
echo "Bootstrap complete! Here's a summary of what was installed:"
echo ""
echo "  ArgoCD:      https://argocd.platform.local"
echo "  Grafana:     https://grafana.platform.local  (admin/admin)"
echo "  Harbor:      https://registry.platform.local"
echo "  Ingress IP:  ${INGRESS_IP}"
echo ""
echo "  ArgoCD admin password: ${ARGOCD_PASSWORD}"
echo ""
echo "  Add to /etc/hosts:"
echo "  ${INGRESS_IP}  argocd.platform.local grafana.platform.local registry.platform.local"
echo ""
