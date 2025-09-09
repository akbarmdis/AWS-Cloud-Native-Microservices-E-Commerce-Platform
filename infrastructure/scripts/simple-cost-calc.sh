#!/bin/bash

# Simple AWS Cost Calculator for Microservices E-Commerce Platform
# Compatible with standard bash/zsh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
DURATION_DAYS=30

usage() {
    cat << EOF
AWS Cost Calculator for Microservices E-Commerce Platform

Usage: $0 [environment] [days]

Arguments:
    environment     Environment (minimal|dev|staging|prod) [default: dev]
    days           Duration in days [default: 30]

Examples:
    $0 dev 30      # Development cost for 30 days
    $0 minimal 7   # Minimal setup for 1 week
    $0 prod 30     # Production cost for 1 month

EOF
}

get_cost() {
    local env=$1
    local service=$2
    
    case "$env-$service" in
        # Minimal costs
        minimal-eks) echo 72 ;;
        minimal-ec2) echo 30 ;;
        minimal-storage) echo 5 ;;
        minimal-rds) echo 16 ;;
        minimal-redis) echo 15 ;;
        minimal-alb) echo 18 ;;
        minimal-nat) echo 32 ;;
        minimal-other) echo 15 ;;
        
        # Development costs  
        dev-eks) echo 72 ;;
        dev-ec2) echo 60 ;;
        dev-storage) echo 10 ;;
        dev-rds) echo 16 ;;
        dev-redis) echo 15 ;;
        dev-alb) echo 18 ;;
        dev-nat) echo 32 ;;
        dev-other) echo 20 ;;
        
        # Staging costs
        staging-eks) echo 72 ;;
        staging-ec2) echo 134 ;;
        staging-storage) echo 25 ;;
        staging-rds) echo 70 ;;
        staging-redis) echo 45 ;;
        staging-alb) echo 35 ;;
        staging-nat) echo 64 ;;
        staging-other) echo 35 ;;
        
        # Production costs
        prod-eks) echo 72 ;;
        prod-ec2) echo 260 ;;
        prod-storage) echo 50 ;;
        prod-rds) echo 425 ;;
        prod-redis) echo 150 ;;
        prod-alb) echo 50 ;;
        prod-nat) echo 96 ;;
        prod-cloudfront) echo 85 ;;
        prod-other) echo 65 ;;
        
        *) echo 0 ;;
    esac
}

calculate_costs() {
    local env=$1
    local days=$2
    
    echo
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    local env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')
    echo -e "${CYAN}║     AWS COST BREAKDOWN - ${env_upper}        ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║ Duration: $days days                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    
    # Get monthly costs
    local eks_cost=$(get_cost $env eks)
    local ec2_cost=$(get_cost $env ec2)
    local storage_cost=$(get_cost $env storage)
    local rds_cost=$(get_cost $env rds)
    local redis_cost=$(get_cost $env redis)
    local alb_cost=$(get_cost $env alb)
    local nat_cost=$(get_cost $env nat)
    local other_cost=$(get_cost $env other)
    local cloudfront_cost=0
    
    if [ "$env" = "prod" ]; then
        cloudfront_cost=$(get_cost $env cloudfront)
    fi
    
    # Calculate monthly total
    local monthly_total=$((eks_cost + ec2_cost + storage_cost + rds_cost + redis_cost + alb_cost + nat_cost + other_cost + cloudfront_cost))
    
    # Calculate period total
    local period_total=$((monthly_total * days / 30))
    local daily_cost=$((period_total / days))
    
    printf "%-25s %s\n" "Service" "Monthly Cost"
    printf "%-25s %s\n" "-------" "------------"
    printf "%-25s \$%d\n" "EKS Cluster" "$eks_cost"
    printf "%-25s \$%d\n" "EC2 Instances" "$ec2_cost"
    printf "%-25s \$%d\n" "Storage (EBS/S3)" "$storage_cost"
    printf "%-25s \$%d\n" "RDS PostgreSQL" "$rds_cost"
    printf "%-25s \$%d\n" "ElastiCache Redis" "$redis_cost"
    printf "%-25s \$%d\n" "Load Balancer" "$alb_cost"
    printf "%-25s \$%d\n" "NAT Gateway" "$nat_cost"
    
    if [ "$env" = "prod" ]; then
        printf "%-25s \$%d\n" "CloudFront CDN" "$cloudfront_cost"
    fi
    
    printf "%-25s \$%d\n" "Other Services" "$other_cost"
    printf "%-25s %s\n" "-------" "------------"
    printf "%-25s \$%d\n" "TOTAL MONTHLY" "$monthly_total"
    
    echo
    echo -e "${GREEN}💰 COST SUMMARY${NC}"
    echo "════════════════════════════════════════════"
    printf "Total for %d days:     ${GREEN}\$%d${NC}\n" "$days" "$period_total"
    printf "Daily cost:            ${GREEN}\$%d${NC}\n" "$daily_cost"
    printf "Monthly equivalent:    ${GREEN}\$%d${NC}\n" "$monthly_total"
    echo
    
    # Cost optimization tips
    echo -e "${YELLOW}💡 COST OPTIMIZATION TIPS${NC}"
    echo "════════════════════════════════════════════"
    
    case $env in
        minimal)
            echo "• Already using minimal configuration"
            echo "• Consider using AWS Free Tier (t2.micro)"
            echo "• Use spot instances to save 50-70%"
            ;;
        dev)
            echo "• Switch to 'minimal' to save ~\$30-50/month"
            echo "• Use spot instances (save 50-70%)"
            echo "• Scale down during off-hours"
            ;;
        staging)
            echo "• Use spot instances (save \$40-80/month)"
            echo "• Reserved instances (save 30-60%)"
            echo "• Implement auto-scaling"
            ;;
        prod)
            echo "• Purchase reserved instances (save \$200-400/month)"
            echo "• Use more spot instances for fault-tolerant workloads"
            echo "• S3 lifecycle policies for storage optimization"
            ;;
    esac
    
    echo
    echo -e "${BLUE}📊 QUICK COMPARISON${NC}"
    echo "════════════════════════════════════════════"
    printf "Minimal:     \$203/month  (\$%d for %d days)\n" $((203 * days / 30)) "$days"
    printf "Development: \$248/month  (\$%d for %d days)\n" $((248 * days / 30)) "$days" 
    printf "Staging:     \$480/month  (\$%d for %d days)\n" $((480 * days / 30)) "$days"
    printf "Production:  \$1253/month (\$%d for %d days)\n" $((1253 * days / 30)) "$days"
    
    echo
    echo -e "${GREEN}🎯 RECOMMENDATION${NC}"
    echo "════════════════════════════════════════════"
    
    if [ "$days" -le 7 ]; then
        echo "For learning (1 week): Use 'minimal' configuration"
        echo "Estimated cost: \$47 for exploration"
    elif [ "$days" -le 14 ]; then
        echo "For portfolio building (2 weeks): Use 'dev' configuration"
        echo "Estimated cost: \$116 for comprehensive demo"
    elif [ "$days" -le 30 ]; then
        echo "For thorough learning (1 month): Use 'dev' configuration"
        echo "Estimated cost: \$248 for complete experience"
    else
        echo "For long-term usage: Consider reserved instances"
        echo "Potential savings: 30-60% with reserved instances"
    fi
    
    echo
    echo -e "${YELLOW}⚠️  IMPORTANT NOTES${NC}"
    echo "════════════════════════════════════════════"
    echo "• Costs are estimates based on us-west-2 pricing"
    echo "• Actual costs depend on usage patterns and data transfer"
    echo "• Always monitor costs with AWS Billing Alerts"
    echo "• Clean up resources when not needed to avoid charges"
    echo "• Consider using the 'minimal' config for learning/demos"
}

main() {
    # Parse arguments
    if [ $# -ge 1 ]; then
        ENVIRONMENT=$1
    fi
    
    if [ $# -ge 2 ]; then
        DURATION_DAYS=$2
    fi
    
    # Validate environment
    case "$ENVIRONMENT" in
        minimal|dev|staging|prod)
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            echo "Invalid environment: $ENVIRONMENT"
            echo "Valid options: minimal, dev, staging, prod"
            echo
            usage
            exit 1
            ;;
    esac
    
    # Validate duration
    if ! [[ "$DURATION_DAYS" =~ ^[0-9]+$ ]] || [ "$DURATION_DAYS" -le 0 ]; then
        echo "Duration must be a positive number"
        exit 1
    fi
    
    calculate_costs "$ENVIRONMENT" "$DURATION_DAYS"
}

# Run main function
main "$@"
