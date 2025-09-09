# AWS Microservices E-Commerce Platform - Deployment Guide

## 🚀 Quick Start

This guide will help you deploy the complete AWS microservices e-commerce platform from scratch.

## 📋 Prerequisites

### Required Tools
- **AWS CLI** >= 2.0
- **Terraform** >= 1.0
- **Docker** >= 20.0
- **kubectl** >= 1.25
- **Helm** >= 3.10
- **Node.js** >= 18.0
- **Git**

### AWS Requirements
- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Sufficient service limits (VPC, EKS, RDS, etc.)

### Recommended AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "rds:*",
        "elasticache:*",
        "s3:*",
        "iam:*",
        "cloudwatch:*",
        "logs:*",
        "secretsmanager:*",
        "kms:*",
        "wafv2:*",
        "cloudtrail:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🏗️ Architecture Overview

The platform deploys the following components:

- **VPC**: Multi-AZ network with public/private/database subnets
- **EKS**: Managed Kubernetes cluster with multiple node groups
- **RDS**: PostgreSQL database with Multi-AZ and backup
- **ElastiCache**: Redis cluster for caching
- **ALB**: Application Load Balancer with WAF
- **S3**: Storage for assets, logs, and backups
- **Security**: IAM roles, Security Groups, Secrets Manager
- **Monitoring**: CloudWatch, Prometheus, Grafana

## 📦 Deployment Options

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script for a complete automated setup:

```bash
# Clone the repository
git clone <repository-url>
cd aws-microservices-ecommerce

# Run automated deployment
./infrastructure/scripts/deploy.sh -e dev

# For production deployment
./infrastructure/scripts/deploy.sh -e prod -r us-east-1
```

#### Deployment Script Options
```bash
./infrastructure/scripts/deploy.sh [OPTIONS]

OPTIONS:
  -e, --environment ENV     Environment (dev|staging|prod) [default: dev]
  -r, --region REGION      AWS region [default: us-west-2]
  --skip-terraform         Skip infrastructure deployment
  --skip-docker           Skip Docker build/push
  --skip-k8s              Skip Kubernetes deployment
  --dry-run               Preview changes without applying
  -v, --verbose           Enable verbose output
  -h, --help              Show help message
```

### Option 2: Manual Step-by-Step Deployment

For more control or learning purposes, follow these manual steps:

#### Step 1: Prepare Terraform State Backend

Create S3 bucket and DynamoDB table for Terraform state management:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket-unique-name --region us-west-2

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-west-2
```

#### Step 2: Configure Terraform Variables

Edit `infrastructure/environments/dev.tfvars`:

```hcl
# Update these values
terraform_state_bucket = "your-terraform-state-bucket-unique-name"
terraform_state_key    = "dev/terraform.tfstate"
terraform_lock_table   = "terraform-lock-table"
```

#### Step 3: Deploy Infrastructure

```bash
cd infrastructure

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply infrastructure
terraform apply -var-file="environments/dev.tfvars"
```

#### Step 4: Build and Push Docker Images

```bash
# Get ECR registry URL
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push each service
for service in user-service product-service order-service payment-service; do
  # Create ECR repository
  aws ecr create-repository --repository-name "ecommerce-microservices-${service}" --region us-west-2 || true
  
  # Build and push
  cd services/$service
  docker build -t "ecommerce-microservices-${service}:latest" .
  docker tag "ecommerce-microservices-${service}:latest" "${ECR_REGISTRY}/ecommerce-microservices-${service}:latest"
  docker push "${ECR_REGISTRY}/ecommerce-microservices-${service}:latest"
  cd ../..
done
```

#### Step 5: Deploy to Kubernetes

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name ecommerce-microservices-dev-cluster

# Deploy using Helm or kubectl
for service in user-service product-service order-service payment-service; do
  if [ -d "k8s/helm-charts/$service" ]; then
    helm upgrade --install $service k8s/helm-charts/$service \
      --namespace dev \
      --create-namespace \
      --set image.repository=$ECR_REGISTRY/ecommerce-microservices-$service \
      --set image.tag=latest \
      --wait
  fi
done
```

## 🔧 Configuration

### Environment-Specific Settings

Each environment has its own configuration file:

- **Development**: `infrastructure/environments/dev.tfvars`
- **Staging**: `infrastructure/environments/staging.tfvars`
- **Production**: `infrastructure/environments/prod.tfvars`

### Key Configuration Parameters

```hcl
# General
project_name = "ecommerce-microservices"
environment  = "dev"
aws_region   = "us-west-2"

# Networking
vpc_cidr = "10.0.0.0/16"
enable_nat_gateway = true

# EKS
cluster_version = "1.28"
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    # ... more configuration
  }
}

# Database
rds_instance_class = "db.t3.micro"  # dev
rds_instance_class = "db.r6g.large" # prod
```

## 🔒 Security Features

### Built-in Security
- **WAF**: Blocks common attacks, rate limiting, geo-blocking
- **Security Groups**: Least privilege network access
- **IAM Roles**: Service-specific permissions with IRSA
- **Secrets Management**: Encrypted secrets with rotation
- **Encryption**: At rest and in transit
- **Network Segmentation**: Multi-tier architecture

### Security Best Practices Implemented
- Container images run as non-root users
- Security scanning in CI/CD pipeline
- VPC Flow Logs enabled
- CloudTrail for audit logging
- Regular security updates via automated patching

## 📊 Monitoring & Observability

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **CloudWatch**: AWS native monitoring
- **X-Ray**: Distributed tracing
- **ELK Stack**: Log aggregation

### Key Metrics
- Application performance (response time, throughput)
- Infrastructure health (CPU, memory, disk)
- Business metrics (orders, users, revenue)
- Security events (failed logins, attacks)

## 🧪 Testing

### Load Testing
```bash
# Install k6
# Run load test
k6 run tests/load/load-test.js -e BASE_URL=https://your-load-balancer-url
```

### Health Checks
```bash
# Check service health
curl https://your-load-balancer-url/health

# Check individual services
kubectl get pods -n dev
kubectl logs -f deployment/user-service -n dev
```

## 🔄 CI/CD Pipeline

The project includes a complete GitHub Actions workflow:

1. **Security Scanning**: Trivy, Semgrep
2. **Code Quality**: Linting, testing, coverage
3. **Infrastructure**: Terraform validation and deployment
4. **Application**: Docker build, push, and deployment
5. **Testing**: Smoke tests and performance tests
6. **Notifications**: Slack integration

### Required GitHub Secrets
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
SLACK_WEBHOOK_URL
SEMGREP_APP_TOKEN
K6_CLOUD_TOKEN
```

## 📈 Performance Optimization

### Auto-scaling Configuration
- **EKS**: Horizontal Pod Autoscaler (HPA)
- **Cluster**: Cluster Autoscaler
- **Database**: Read replicas for scaling reads

### Cost Optimization
- Spot instances for non-critical workloads
- Reserved instances for predictable workloads
- S3 lifecycle policies
- CloudWatch cost anomaly detection

## 🛠️ Troubleshooting

### Common Issues

#### Terraform State Lock
```bash
# If terraform is stuck
terraform force-unlock <LOCK_ID>
```

#### ECR Permission Issues
```bash
# Ensure ECR login
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com
```

#### Kubernetes Deployment Issues
```bash
# Check pod status
kubectl get pods -n dev

# Check pod logs
kubectl logs <pod-name> -n dev

# Describe pod for events
kubectl describe pod <pod-name> -n dev
```

#### Database Connection Issues
```bash
# Check security groups
# Verify database credentials in Secrets Manager
aws secretsmanager get-secret-value --secret-id ecommerce-microservices-dev-db-credentials
```

### Getting Help

1. Check the logs first:
   - CloudWatch Logs
   - Kubernetes pod logs
   - Application logs

2. Verify resources:
   - AWS Console
   - `kubectl get all -n dev`
   - `terraform state list`

3. Common debugging commands:
   ```bash
   # Kubernetes debugging
   kubectl get events -n dev --sort-by=.metadata.creationTimestamp
   
   # AWS resource verification
   aws eks describe-cluster --name ecommerce-microservices-dev-cluster
   aws rds describe-db-instances
   ```

## 🗑️ Cleanup

### Destroy Everything
```bash
# Using the deployment script
./infrastructure/scripts/deploy.sh --destroy -e dev

# Manual cleanup
terraform destroy -var-file="environments/dev.tfvars"
```

### Partial Cleanup
```bash
# Remove only Kubernetes resources
kubectl delete namespace dev

# Remove only Docker images
docker system prune -a
```

## 📚 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)

## 💡 Tips for Production

1. **Multi-Region Deployment**: Consider deploying across multiple AWS regions
2. **Backup Strategy**: Implement comprehensive backup and disaster recovery
3. **Security Auditing**: Regular security assessments and penetration testing
4. **Performance Tuning**: Monitor and optimize based on actual usage patterns
5. **Cost Management**: Regular cost reviews and optimization

---

**Built with ❤️ for demonstrating enterprise-level AWS architecture and DevOps practices**
