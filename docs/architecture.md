# Platform Architecture


- Kubernetes Clusters: 1 Server and 2 Agents
- Namespaces: Dev, Prod
- GitOps: ArgoCD auto-sync
- CI/CD: Github Actions with Trivy Scanning
- Autoscaling: HPA for CPU-based scaling 
- Observability: Prometheus + Grafana + Loki
- Security: Pod Security Standards + NetworkPolicies
- AWS-equivalent mapping for interview
