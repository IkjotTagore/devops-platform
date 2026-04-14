# terraform/envs/local/main.tf
# Provision a local k3s cluster with all platform components
# using OpenTofu (free Terraform fork) + Helm provider

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # Local state for dev — use remote state (S3/MinIO) for shared envs
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ─────────────────────────────────────────
# Namespaces
# ─────────────────────────────────────────
resource "kubernetes_namespace" "envs" {
  for_each = toset(["dev", "staging", "production", "observability", "platform-system"])
  metadata {
    name = each.value
    labels = {
      environment  = each.value
      "managed-by" = "terraform"
    }
  }
}

# ─────────────────────────────────────────
# Cilium CNI
# ─────────────────────────────────────────
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = var.cilium_version

  set { name = "kubeProxyReplacement"; value = "true" }
  set { name = "hubble.enabled";       value = "true" }
  set { name = "hubble.ui.enabled";    value = "true" }
}

# ─────────────────────────────────────────
# ArgoCD
# ─────────────────────────────────────────
resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = var.argocd_chart_version

  depends_on = [kubernetes_namespace.argocd]

  values = [file("${path.module}/values/argocd.yaml")]

  set { name = "server.insecure"; value = "true" }
  set { name = "configs.cm.admin.enabled"; value = "true" }
}

# ─────────────────────────────────────────
# Kyverno
# ─────────────────────────────────────────
resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  namespace  = "kyverno"
  create_namespace = true
  version    = var.kyverno_version

  set { name = "admissionController.replicas"; value = "1" }
}

# ─────────────────────────────────────────
# Prometheus Stack
# ─────────────────────────────────────────
resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "observability"
  version    = var.prometheus_stack_version

  depends_on = [kubernetes_namespace.envs]

  values = [file("${path.module}/values/prometheus-stack.yaml")]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

# ─────────────────────────────────────────
# Loki
# ─────────────────────────────────────────
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = "observability"
  version    = var.loki_version

  set { name = "promtail.enabled"; value = "true" }
  set { name = "loki.persistence.enabled"; value = "true" }
  set { name = "loki.persistence.size";    value = "20Gi" }
}

# ─────────────────────────────────────────
# KEDA
# ─────────────────────────────────────────
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = var.keda_version
}

# ─────────────────────────────────────────
# App of Apps Bootstrap
# ─────────────────────────────────────────
resource "kubectl_manifest" "root_app" {
  yaml_body  = file("${path.root}/../../../gitops/apps/root-app.yaml")
  depends_on = [helm_release.argocd]
}
