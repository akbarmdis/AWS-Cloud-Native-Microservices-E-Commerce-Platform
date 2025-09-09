# AWS Cost Analysis - Microservices E-Commerce Platform

## 💰 Cost Overview

This document provides a detailed breakdown of AWS costs for deploying the microservices e-commerce platform in different environments.

> **⚠️ Important**: All costs are estimates based on us-west-2 pricing as of December 2023. Actual costs may vary based on usage patterns, data transfer, and AWS pricing changes.

## 🏷️ Cost Summary Table

| Environment | Monthly Cost | Daily Cost | Key Components |
|-------------|--------------|------------|----------------|
| **Development** | **$185-250** | **$6-8** | Minimal instances, single AZ |
| **Staging** | **$350-500** | **$12-17** | Production-like with reduced capacity |
| **Production** | **$800-1,500** | **$27-50** | Full redundancy, auto-scaling |

## 📊 Development Environment Costs

### Core Infrastructure
| Service | Configuration | Monthly Cost | Notes |
|---------|---------------|--------------|-------|
| **EKS Cluster** | 1 cluster | $72 | Fixed cost per cluster |
| **EC2 Instances (EKS Nodes)** | 2x t3.medium (on-demand) | $60 | 2 vCPU, 4GB RAM each |
| **EBS Storage** | 100GB gp3 | $10 | Node storage |
| **RDS PostgreSQL** | db.t3.micro | $16 | 1 vCPU, 1GB RAM |
| **ElastiCache Redis** | cache.t3.micro | $15 | 1 vCPU, 0.5GB RAM |
| **Application Load Balancer** | 1 ALB | $18 | ~25GB data processed |
| **NAT Gateway** | 1 NAT Gateway | $32 | Single AZ |

### Storage & Data Transfer
| Service | Usage | Monthly Cost | Notes |
|---------|--------|--------------|-------|
| **S3 Storage** | 50GB Standard | $1.15 | Assets, logs, backups |
| **Data Transfer** | 100GB outbound | $9 | API responses, assets |
| **CloudWatch Logs** | 10GB | $5 | Application logs |

### Security & Monitoring
| Service | Configuration | Monthly Cost | Notes |
|---------|---------------|--------------|-------|
| **Secrets Manager** | 5 secrets | $2.50 | Database, JWT secrets |
| **KMS** | 100 requests/month | $1 | Minimal usage |
| **WAF** | Basic rules | $5 | Web ACL + requests |

**Development Total: ~$185-220/month**

## 🚀 Production Environment Costs

### Core Infrastructure
| Service | Configuration | Monthly Cost | Notes |
|---------|---------------|--------------|-------|
| **EKS Cluster** | 1 cluster | $72 | Fixed cost per cluster |
| **EC2 Instances (EKS Nodes)** | 3x t3.large (on-demand) | $200 | 2 vCPU, 8GB RAM each |
| **EC2 Instances (Spot)** | 2x t3.large (spot, 70% off) | $60 | Additional capacity |
| **EBS Storage** | 500GB gp3 | $50 | Higher IOPS for production |
| **RDS PostgreSQL** | db.r6g.large (Multi-AZ) | $285 | 2 vCPU, 16GB RAM, Multi-AZ |
| **RDS Read Replica** | db.r6g.large | $140 | Read scaling |
| **ElastiCache Redis** | cache.r6g.large | $150 | 2 vCPU, 13GB RAM |
| **Application Load Balancer** | 2 ALBs | $50 | ~200GB data processed |
| **NAT Gateway** | 3 NAT Gateways (Multi-AZ) | $96 | High availability |

### Storage & Data Transfer
| Service | Usage | Monthly Cost | Notes |
|---------|--------|--------------|-------|
| **S3 Storage** | 500GB Standard + 200GB IA | $15 | Lifecycle policies |
| **CloudFront CDN** | 1TB transfer | $85 | Global content delivery |
| **Data Transfer** | 500GB outbound | $45 | Higher traffic |
| **CloudWatch Logs** | 100GB | $50 | Comprehensive logging |

### Security & Monitoring
| Service | Configuration | Monthly Cost | Notes |
|---------|---------------|--------------|-------|
| **Secrets Manager** | 10 secrets | $5 | Multiple environments |
| **KMS** | 10,000 requests/month | $3 | Production encryption |
| **WAF** | Advanced rules | $20 | DDoS protection, bot control |
| **CloudTrail** | Data events | $10 | Compliance logging |
| **X-Ray** | 1M traces | $5 | Distributed tracing |

**Production Total: ~$800-1,200/month**

## 💡 Cost Optimization Strategies

### Immediate Savings (Development)
```bash
# Use spot instances for non-critical workloads
node_groups = {
  spot = {
    capacity_type = "SPOT"
    instance_types = ["t3.medium", "t3.large"]
    # Can save 50-70% on compute costs
  }
}
```

### Production Optimizations

#### 1. **Reserved Instances** (Save 30-60%)
```bash
# 1-year Reserved Instances for predictable workloads
# RDS: db.r6g.large: $285 → $190 (33% savings)
# EC2: t3.large: $67 → $42 (37% savings)
```

#### 2. **Spot Instances** (Save 50-90%)
```bash
# Use for development, testing, and fault-tolerant workloads
# t3.large spot: $67 → $20 (70% savings average)
```

#### 3. **Auto Scaling** 
```bash
# Scale down during off-hours
# Potential 40-60% savings on compute during nights/weekends
```

#### 4. **S3 Intelligent Tiering**
```bash
# Automatically move data to cheaper storage classes
# 500GB → Potential 20-40% storage cost reduction
```

## 📈 Cost Scaling Examples

### Scenario 1: Minimal Development Setup
**Goal**: Learn and demonstrate capabilities
**Monthly Cost**: ~$120-150

**Configuration**:
- EKS with 1 t3.small node
- RDS db.t3.micro (no Multi-AZ)
- Single AZ deployment
- Minimal monitoring

```hcl
# Minimal dev configuration
node_groups = {
  general = {
    instance_types = ["t3.small"]
    desired_size = 1
    max_size = 2
    min_size = 1
  }
}
rds_instance_class = "db.t3.micro"
multi_az = false
```

### Scenario 2: Portfolio Demo (Recommended)
**Goal**: Showcase production-ready architecture
**Monthly Cost**: ~$250-350

**Configuration**:
- EKS with 2 t3.medium nodes
- RDS db.t3.small with automated backups
- Multi-AZ setup
- Basic monitoring and security

### Scenario 3: Production-Ready
**Goal**: Handle real traffic and business requirements
**Monthly Cost**: ~$800-1,500

**Configuration**:
- Full multi-AZ deployment
- Auto-scaling enabled
- Comprehensive monitoring
- Advanced security features

## 🛑 Cost Monitoring & Alerts

### Set up Cost Alerts
```bash
# Create billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Monthly-Cost-Alarm" \
  --alarm-description "Alert when monthly costs exceed $200" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 200 \
  --comparison-operator GreaterThanThreshold
```

### Cost Monitoring Tools
1. **AWS Cost Explorer**: Track spending patterns
2. **AWS Budgets**: Set spending limits and alerts  
3. **AWS Cost Anomaly Detection**: Identify unusual spending
4. **CloudWatch Billing Metrics**: Real-time cost monitoring

## 💸 Ways to Minimize Costs While Learning

### 1. **Use Development Environment Only**
- Deploy only the dev configuration
- **Cost**: ~$150-200/month

### 2. **Shut Down When Not Needed**
```bash
# Stop EKS nodes when not in use (saves ~$60-200/month)
kubectl scale deployment --all --replicas=0 -n dev

# Use deployment script with scheduling
./infrastructure/scripts/deploy.sh --schedule-stop "20:00" --schedule-start "08:00"
```

### 3. **Use AWS Free Tier**
- RDS: 750 hours of db.t2.micro (first 12 months)
- EC2: 750 hours of t2.micro (first 12 months)
- S3: 5GB standard storage (always free)
- CloudWatch: 10 custom metrics (always free)

### 4. **Regional Considerations**
```bash
# Cheaper regions (can save 10-20%)
us-east-1 (Virginia)    # Often cheapest
us-west-1 (N. California)
us-east-2 (Ohio)

# More expensive regions
eu-west-1 (Ireland)
ap-northeast-1 (Tokyo)
```

### 5. **Clean Up Resources**
```bash
# Always clean up after demos
terraform destroy -var-file="environments/dev.tfvars"

# Or use the deployment script
./infrastructure/scripts/deploy.sh --destroy -e dev
```

## 🎯 Recommended Approach for Resume Building

### Phase 1: Basic Demo ($120-150/month)
1. Deploy minimal development environment
2. Focus on architecture and code quality
3. Document everything thoroughly
4. Take screenshots and create demos

### Phase 2: Advanced Features ($200-250/month)
1. Add monitoring and security features
2. Implement CI/CD pipeline
3. Add load testing and performance optimization
4. Create production-like configuration

### Phase 3: Portfolio Presentation ($0/month)
1. Clean up AWS resources
2. Create video demos and documentation
3. Showcase code in GitHub
4. Present architecture diagrams

## ⏰ Sample 30-Day Learning Plan

**Week 1**: Deploy basic infrastructure ($150)
**Week 2**: Add services and monitoring ($200)
**Week 3**: Implement CI/CD and testing ($250)
**Week 4**: Documentation and cleanup ($50)

**Total Learning Cost**: ~$650 for comprehensive hands-on experience

## 🔍 Hidden Costs to Watch

1. **Data Transfer**: Can add $20-50/month with heavy usage
2. **CloudWatch Logs**: $0.50/GB can accumulate quickly
3. **EBS Snapshots**: Automated backups add storage costs
4. **NAT Gateway**: $32/month per gateway + data processing
5. **Load Balancer**: $18/month + $0.008 per LCU-hour

## 💰 Free Alternatives for Learning

If budget is a major concern, consider:

1. **AWS Free Tier**: Use t2.micro instances (limited but functional)
2. **LocalStack**: Local AWS cloud stack emulation
3. **Minikube/Kind**: Local Kubernetes development
4. **Docker Compose**: Simulate microservices locally

---

**💡 Pro Tip**: Deploy for 2-3 weeks to build the project, document everything, then clean up resources. You'll have a complete portfolio project with minimal ongoing costs!
