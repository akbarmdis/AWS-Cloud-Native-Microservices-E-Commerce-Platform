#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
REGION="us-west-2"
DURATION_DAYS=30
SHOW_DETAILS=false

usage() {
    cat << EOF
AWS Cost Calculator for Microservices E-Commerce Platform

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV     Environment (minimal|dev|staging|prod) [default: dev]
    -r, --region REGION      AWS region [default: us-west-2]
    -d, --duration DAYS      Duration in days [default: 30]
    --details                Show detailed cost breakdown
    -h, --help               Show this help message

EXAMPLES:
    $0 -e dev -d 30          # Development cost for 30 days
    $0 -e prod --details     # Production cost with details
    $0 -e minimal -d 7       # Minimal setup for 1 week

EOF
}

# Cost data (monthly USD)
declare -A COSTS

# Minimal configuration costs
COSTS[minimal_eks_cluster]=72
COSTS[minimal_ec2_nodes]=30        # 1x t3.small
COSTS[minimal_ebs_storage]=5       # 50GB
COSTS[minimal_rds]=16             # db.t3.micro
COSTS[minimal_elasticache]=15     # cache.t3.micro
COSTS[minimal_alb]=18
COSTS[minimal_nat_gateway]=32
COSTS[minimal_s3]=1
COSTS[minimal_data_transfer]=5
COSTS[minimal_cloudwatch]=3
COSTS[minimal_secrets]=1
COSTS[minimal_waf]=5

# Development configuration costs
COSTS[dev_eks_cluster]=72
COSTS[dev_ec2_nodes]=60           # 2x t3.medium
COSTS[dev_ebs_storage]=10         # 100GB
COSTS[dev_rds]=16                # db.t3.micro
COSTS[dev_elasticache]=15        # cache.t3.micro
COSTS[dev_alb]=18
COSTS[dev_nat_gateway]=32
COSTS[dev_s3]=1.15
COSTS[dev_data_transfer]=9
COSTS[dev_cloudwatch]=5
COSTS[dev_secrets]=2.50
COSTS[dev_kms]=1
COSTS[dev_waf]=5

# Staging configuration costs
COSTS[staging_eks_cluster]=72
COSTS[staging_ec2_nodes]=134      # 2x t3.large
COSTS[staging_ebs_storage]=25     # 250GB
COSTS[staging_rds]=70            # db.t3.small (Multi-AZ)
COSTS[staging_elasticache]=45    # cache.t3.small
COSTS[staging_alb]=35
COSTS[staging_nat_gateway]=64    # 2 AZ
COSTS[staging_s3]=8
COSTS[staging_data_transfer]=20
COSTS[staging_cloudwatch]=15
COSTS[staging_secrets]=3
COSTS[staging_kms]=2
COSTS[staging_waf]=10
COSTS[staging_cloudtrail]=5

# Production configuration costs
COSTS[prod_eks_cluster]=72
COSTS[prod_ec2_nodes]=260        # 3x t3.large + 2x t3.large spot
COSTS[prod_ebs_storage]=50       # 500GB
COSTS[prod_rds]=425             # db.r6g.large Multi-AZ + read replica
COSTS[prod_elasticache]=150     # cache.r6g.large
COSTS[prod_alb]=50
COSTS[prod_nat_gateway]=96      # 3 AZ
COSTS[prod_s3]=15
COSTS[prod_cloudfront]=85
COSTS[prod_data_transfer]=45
COSTS[prod_cloudwatch]=50
COSTS[prod_secrets]=5
COSTS[prod_kms]=3
COSTS[prod_waf]=20
COSTS[prod_cloudtrail]=10
COSTS[prod_xray]=5

# Regional multipliers (us-west-2 = 1.0)
declare -A REGION_MULTIPLIERS
REGION_MULTIPLIERS[us-east-1]=0.95
REGION_MULTIPLIERS[us-east-2]=0.95
REGION_MULTIPLIERS[us-west-1]=1.05
REGION_MULTIPLIERS[us-west-2]=1.00
REGION_MULTIPLIERS[eu-west-1]=1.15
REGION_MULTIPLIERS[eu-central-1]=1.10
REGION_MULTIPLIERS[ap-northeast-1]=1.20
REGION_MULTIPLIERS[ap-southeast-1]=1.15

log() {
    echo -e "${GREEN}[COST CALC]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

calculate_costs() {
    local env=$1
    local region_multiplier=${REGION_MULTIPLIERS[$REGION]:-1.0}
    
    case $env in
        minimal)
            local services=(
                "eks_cluster:EKS Cluster"
                "ec2_nodes:EC2 Instances"
                "ebs_storage:EBS Storage"
                "rds:RDS PostgreSQL"
                "elasticache:ElastiCache Redis"
                "alb:Application Load Balancer"
                "nat_gateway:NAT Gateway"
                "s3:S3 Storage"
                "data_transfer:Data Transfer"
                "cloudwatch:CloudWatch"
                "secrets:Secrets Manager"
                "waf:AWS WAF"
            )
            ;;
        dev)
            local services=(
                "eks_cluster:EKS Cluster"
                "ec2_nodes:EC2 Instances"
                "ebs_storage:EBS Storage"
                "rds:RDS PostgreSQL"
                "elasticache:ElastiCache Redis"
                "alb:Application Load Balancer"
                "nat_gateway:NAT Gateway"
                "s3:S3 Storage"
                "data_transfer:Data Transfer"
                "cloudwatch:CloudWatch"
                "secrets:Secrets Manager"
                "kms:KMS"
                "waf:AWS WAF"
            )
            ;;
        staging)
            local services=(
                "eks_cluster:EKS Cluster"
                "ec2_nodes:EC2 Instances"
                "ebs_storage:EBS Storage"
                "rds:RDS PostgreSQL"
                "elasticache:ElastiCache Redis"
                "alb:Application Load Balancer"
                "nat_gateway:NAT Gateway"
                "s3:S3 Storage"
                "data_transfer:Data Transfer"
                "cloudwatch:CloudWatch"
                "secrets:Secrets Manager"
                "kms:KMS"
                "waf:AWS WAF"
                "cloudtrail:CloudTrail"
            )
            ;;
        prod)
            local services=(
                "eks_cluster:EKS Cluster"
                "ec2_nodes:EC2 Instances"
                "ebs_storage:EBS Storage"
                "rds:RDS PostgreSQL"
                "elasticache:ElastiCache Redis"
                "alb:Application Load Balancer"
                "nat_gateway:NAT Gateway"
                "s3:S3 Storage"
                "cloudfront:CloudFront"
                "data_transfer:Data Transfer"
                "cloudwatch:CloudWatch"
                "secrets:Secrets Manager"
                "kms:KMS"
                "waf:AWS WAF"
                "cloudtrail:CloudTrail"
                "xray:X-Ray"
            )
            ;;
    esac
    
    local total=0
    local daily_total=0
    
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         AWS COST BREAKDOWN - ${env^^}              ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║ Region: ${REGION}                              ║${NC}"
    echo -e "${CYAN}║ Duration: ${DURATION_DAYS} days                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo
    
    if [ "$SHOW_DETAILS" = "true" ]; then
        printf "%-25s %-15s %-15s\n" "Service" "Monthly Cost" "Period Cost"
        printf "%-25s %-15s %-15s\n" "-------" "------------" "-----------"
    fi
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_key service_name <<< "$service_info"
        local cost_key="${env}_${service_key}"
        local monthly_cost=${COSTS[$cost_key]:-0}
        
        # Apply regional multiplier
        monthly_cost=$(echo "$monthly_cost * $region_multiplier" | bc -l)
        
        # Calculate cost for the specified duration
        local period_cost=$(echo "$monthly_cost * $DURATION_DAYS / 30" | bc -l)
        
        total=$(echo "$total + $period_cost" | bc -l)
        
        if [ "$SHOW_DETAILS" = "true" ]; then
            printf "%-25s \$%-14.2f \$%-14.2f\n" "$service_name" "$monthly_cost" "$period_cost"
        fi
    done
    
    daily_total=$(echo "$total / $DURATION_DAYS" | bc -l)
    local monthly_equivalent=$(echo "$total * 30 / $DURATION_DAYS" | bc -l)
    
    if [ "$SHOW_DETAILS" = "true" ]; then
        printf "%-25s %-15s %-15s\n" "-------" "------------" "-----------"
    fi
    
    echo
    echo -e "${GREEN}💰 COST SUMMARY${NC}"
    echo "════════════════════════════════════════════"
    printf "Total for %d days:     ${GREEN}\$%.2f${NC}\n" "$DURATION_DAYS" "$total"
    printf "Daily cost:            ${GREEN}\$%.2f${NC}\n" "$daily_total"
    printf "Monthly equivalent:    ${GREEN}\$%.2f${NC}\n" "$monthly_equivalent"
    echo
    
    # Cost optimization suggestions
    echo -e "${YELLOW}💡 COST OPTIMIZATION TIPS${NC}"
    echo "════════════════════════════════════════════"
    
    case $env in
        minimal)
            echo "• Already using minimal configuration"
            echo "• Consider using AWS Free Tier for t2.micro instances"
            echo "• Use spot instances to save ~50-70%"
            ;;
        dev)
            echo "• Switch to 'minimal' configuration to save ~\$30-50/month"
            echo "• Use spot instances for EKS nodes (save ~50-70%)"
            echo "• Scale down resources during off-hours"
            echo "• Consider single-AZ deployment for non-critical workloads"
            ;;
        staging)
            echo "• Use spot instances for EKS nodes (save ~\$40-80/month)"
            echo "• Consider reserved instances for long-term usage (save 30-60%)"
            echo "• Implement auto-scaling to optimize resource usage"
            ;;
        prod)
            echo "• Purchase reserved instances (save 30-60%): ~\$200-400/month"
            echo "• Use more spot instances for fault-tolerant workloads"
            echo "• Implement S3 lifecycle policies for storage optimization"
            echo "• Consider multi-region deployment for better cost distribution"
            ;;
    esac
    
    echo
    echo -e "${BLUE}📊 COMPARISON${NC}"
    echo "════════════════════════════════════════════"
    
    # Quick comparison
    local minimal_monthly=$(echo "${COSTS[minimal_eks_cluster]} + ${COSTS[minimal_ec2_nodes]} + ${COSTS[minimal_ebs_storage]} + ${COSTS[minimal_rds]} + ${COSTS[minimal_elasticache]} + ${COSTS[minimal_alb]} + ${COSTS[minimal_nat_gateway]} + ${COSTS[minimal_s3]} + ${COSTS[minimal_data_transfer]} + ${COSTS[minimal_cloudwatch]} + ${COSTS[minimal_secrets]} + ${COSTS[minimal_waf]}" | bc -l)
    
    local dev_monthly=$(echo "${COSTS[dev_eks_cluster]} + ${COSTS[dev_ec2_nodes]} + ${COSTS[dev_ebs_storage]} + ${COSTS[dev_rds]} + ${COSTS[dev_elasticache]} + ${COSTS[dev_alb]} + ${COSTS[dev_nat_gateway]} + ${COSTS[dev_s3]} + ${COSTS[dev_data_transfer]} + ${COSTS[dev_cloudwatch]} + ${COSTS[dev_secrets]} + ${COSTS[dev_kms]} + ${COSTS[dev_waf]}" | bc -l)
    
    printf "Minimal:     \$%.0f/month  (\$%.0f for %d days)\n" "$minimal_monthly" "$(echo "$minimal_monthly * $DURATION_DAYS / 30" | bc -l)" "$DURATION_DAYS"
    printf "Development: \$%.0f/month  (\$%.0f for %d days)\n" "$dev_monthly" "$(echo "$dev_monthly * $DURATION_DAYS / 30" | bc -l)" "$DURATION_DAYS"
    printf "Staging:     \$%.0f/month  (\$%.0f for %d days)\n" "420" "$(echo "420 * $DURATION_DAYS / 30" | bc -l)" "$DURATION_DAYS"
    printf "Production:  \$%.0f/month  (\$%.0f for %d days)\n" "1000" "$(echo "1000 * $DURATION_DAYS / 30" | bc -l)" "$DURATION_DAYS"
    
    echo
    echo -e "${GREEN}🎯 RECOMMENDATION${NC}"
    echo "════════════════════════════════════════════"
    
    if [ "$DURATION_DAYS" -le 7 ]; then
        echo "For learning/demo (1 week): Use 'minimal' configuration"
        echo "Estimated cost: \$25-35 for exploration"
    elif [ "$DURATION_DAYS" -le 14 ]; then
        echo "For portfolio building (2 weeks): Use 'dev' configuration"  
        echo "Estimated cost: \$60-90 for comprehensive demo"
    elif [ "$DURATION_DAYS" -le 30 ]; then
        echo "For thorough learning (1 month): Use 'dev' configuration"
        echo "Estimated cost: \$185-250 for complete experience"
    else
        echo "For long-term usage: Consider reserved instances and auto-scaling"
        echo "Potential savings: 30-60% with reserved instances"
    fi
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -d|--duration)
                DURATION_DAYS="$2"
                shift 2
                ;;
            --details)
                SHOW_DETAILS=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate environment
    case "$ENVIRONMENT" in
        minimal|dev|staging|prod)
            ;;
        *)
            echo "Invalid environment: $ENVIRONMENT"
            echo "Valid options: minimal, dev, staging, prod"
            exit 1
            ;;
    esac
    
    # Check if bc is available
    if ! command -v bc &> /dev/null; then
        echo "Error: 'bc' calculator is required but not installed."
        echo "Install it with: brew install bc (macOS) or apt-get install bc (Ubuntu)"
        exit 1
    fi
    
    # Check region
    if [ -z "${REGION_MULTIPLIERS[$REGION]:-}" ]; then
        warning "Region $REGION not in our database. Using us-west-2 pricing."
        REGION="us-west-2"
    fi
    
    calculate_costs "$ENVIRONMENT"
}

# Run main function
main "$@"
