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

#The Eventual Repo Structure

├── .github/                    # CI/CD workflows
│   └── workflows/
│       ├── ci.yml              
│       ├── release.yml         
│       └── security-scan.yml   
├── terraform/                  # Infrastructure as Code
│   ├── modules/
│   │   ├── cluster/            
│   │   ├── networking/         
│   │   └── storage/            
│   └── envs/
│       ├── local/              
│       └── aws/               
├── ansible/                    # Node configuration
│   ├── roles/
│   │   ├── k8s-common/         
│   │   └── harbor/             
│   └── inventory/
├── helm/                       # Shared Helm charts
│   └── charts/
│       ├── app-template/       
│       └── base-ingress/       
├── gitops/                     # ArgoCD application definitions
│   ├── apps/                   
│   ├── projects/              
│   ├── applicationsets/        
│   └── envs/
│       ├── dev/
│       ├── staging/
│       └── production/
├── k8s/                        # Raw Kubernetes manifests
│   ├── namespaces/
│   ├── rbac/
│   ├── network-policies/
│   └── storage-classes/
├── security/                   # Security tooling configs
│   ├── kyverno/                
│   ├── falco/                  
│   ├── cert-manager/           
│   ├── sealed-secrets/         
│   └── vault/                  
├── observability/              # Monitoring stack
│   ├── prometheus/            
│   ├── grafana/               
│   ├── loki/                   
│   ├── tempo/                  
│   └── alertmanager/           
├── autoscaling/                # Scaling configurations
│   ├── hpa/                    
│   ├── keda/                  
│   └── vpa/                   
├── registry/                   # Harbor + image signing
├── apps/                       # Sample applications
│   └── sample-app/
├── scripts/                    # Bootstrap & utility scripts
└── docs/                       

# Environments
| Environment | Sync Policy | Approval | Scaling |
|-------------|-------------|----------|---------|
| Dev | Auto | None | Minimal |
| Stage | Auto | None | Medium |
| Prod | Manual | Required | Full HPA+KEDA |
