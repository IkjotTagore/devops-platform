# devops-platform
A fully open-source, production-grade Kubernetes DevOps platform using GitOps, CI/CD, autoscaling, security, and observability; fully local and AWS-equivalent

# The Stack
| Domain | Tool | AWS Equivalent |
|--------|------|----------------|
| Orchestration | Kubernetes / k3s | EKS |
| CI/CD | GitHub Actions / Forgejo | CodePipeline |
| GitOps | ArgoCD + Argo Rollouts | CodeDeploy |
| Registry | Harbor | ECR |
| Image Security | Cosign + Trivy | ECR scanning |
| Policy Engine | Kyverno | Config Rules + IAM |
| Runtime Security | Falco | GuardDuty |
| Secrets | Sealed Secrets + OpenBao | Secrets Manager |
| Networking | Cilium + MetalLB + Nginx | VPC + ALB |
| TLS | Cert-Manager + Let's Encrypt | ACM |
| Autoscaling | HPA + KEDA + Karpenter | EKS Autoscaler |
| Metrics | Prometheus + Grafana | CloudWatch |
| Logs | Loki + Promtail | CloudWatch Logs |
| Tracing | Tempo + OpenTelemetry | X-Ray |
| IaC | OpenTofu + Ansible | CloudFormation |
| Object Storage | MinIO | S3 |
| Local AWS | LocalStack | AWS |

# Environments
| Environment | Sync Policy | Approval | Scaling |
|-------------|-------------|----------|---------|
| Dev | Auto | None | Minimal |
| Stage | Auto | None | Medium |
| Prod | Manual | Required | Full HPA+KEDA |
