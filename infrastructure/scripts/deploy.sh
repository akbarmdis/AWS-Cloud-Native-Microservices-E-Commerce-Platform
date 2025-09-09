#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure"
SERVICES_DIR="$PROJECT_ROOT/services"
K8S_DIR="$PROJECT_ROOT/k8s"

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-west-2"
TERRAFORM_PLAN_FILE="tfplan"
SKIP_TERRAFORM="false"
SKIP_DOCKER="false"
SKIP_K8S="false"
DRY_RUN="false"
VERBOSE="false"

# Functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy AWS Microservices E-Commerce Platform

OPTIONS:
    -e, --environment ENV          Environment to deploy (dev|staging|prod) [default: dev]
    -r, --region REGION           AWS region [default: us-west-2]
    --skip-terraform              Skip Terraform deployment
    --skip-docker                 Skip Docker build and push
    --skip-k8s                    Skip Kubernetes deployment
    --dry-run                     Show what would be done without executing
    -v, --verbose                 Enable verbose output
    -h, --help                    Show this help message

EXAMPLES:
    $0 -e dev                     Deploy to development environment
    $0 -e prod -r us-east-1       Deploy to production in us-east-1
    $0 --skip-terraform           Deploy only services (skip infrastructure)
    $0 --dry-run                  Preview deployment without executing

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform >= 1.0 installed
    - Docker installed and running
    - kubectl installed and configured
    - Helm 3 installed

EOF
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install them before running this script"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
        error "Please run 'aws configure' or set environment variables"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|prod)
            log "Deploying to environment: $ENVIRONMENT"
            ;;
        *)
            error "Invalid environment: $ENVIRONMENT"
            error "Supported environments: dev, staging, prod"
            exit 1
            ;;
    esac
    
    local tfvars_file="$TERRAFORM_DIR/environments/${ENVIRONMENT}.tfvars"
    if [ ! -f "$tfvars_file" ]; then
        error "Terraform variables file not found: $tfvars_file"
        exit 1
    fi
}

deploy_terraform() {
    if [ "$SKIP_TERRAFORM" = "true" ]; then
        warning "Skipping Terraform deployment"
        return
    fi
    
    log "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    info "Initializing Terraform..."
    if [ "$VERBOSE" = "true" ]; then
        terraform init
    else
        terraform init > /dev/null
    fi
    
    # Format check
    if ! terraform fmt -check=true -diff=true; then
        error "Terraform formatting check failed. Run 'terraform fmt -recursive' to fix."
        exit 1
    fi
    
    # Validate configuration
    info "Validating Terraform configuration..."
    terraform validate
    
    # Create plan
    info "Creating Terraform plan..."
    local plan_args=(-var-file="environments/${ENVIRONMENT}.tfvars" -out="$TERRAFORM_PLAN_FILE")
    
    if [ "$VERBOSE" = "true" ]; then
        terraform plan "${plan_args[@]}"
    else
        terraform plan "${plan_args[@]}" > /dev/null
    fi
    
    # Apply if not dry run
    if [ "$DRY_RUN" = "false" ]; then
        info "Applying Terraform plan..."
        terraform apply -auto-approve "$TERRAFORM_PLAN_FILE"
        log "Infrastructure deployment completed"
    else
        info "Dry run mode: Terraform plan created but not applied"
    fi
    
    cd - > /dev/null
}

build_and_push_images() {
    if [ "$SKIP_DOCKER" = "true" ]; then
        warning "Skipping Docker build and push"
        return
    fi
    
    log "Building and pushing Docker images..."
    
    # Get ECR registry
    local aws_account_id
    aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local ecr_registry="${aws_account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Login to ECR
    info "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ecr_registry"
    
    # Build and push each service
    local services=("user-service" "product-service" "order-service" "payment-service")
    
    for service in "${services[@]}"; do
        info "Building $service..."
        
        local service_dir="$SERVICES_DIR/$service"
        if [ ! -d "$service_dir" ]; then
            warning "Service directory not found: $service_dir, skipping..."
            continue
        fi
        
        local image_name="ecommerce-microservices-${service}"
        local image_tag="latest"
        local full_image_name="${ecr_registry}/${image_name}:${image_tag}"
        
        # Create ECR repository if it doesn't exist
        if ! aws ecr describe-repositories --repository-names "$image_name" --region "$AWS_REGION" &> /dev/null; then
            info "Creating ECR repository: $image_name"
            aws ecr create-repository --repository-name "$image_name" --region "$AWS_REGION" > /dev/null
        fi
        
        if [ "$DRY_RUN" = "false" ]; then
            # Build image
            docker build -t "$image_name:$image_tag" "$service_dir"
            docker tag "$image_name:$image_tag" "$full_image_name"
            
            # Push image
            info "Pushing $service to ECR..."
            docker push "$full_image_name"
            
            # Security scan (if trivy is available)
            if command -v trivy &> /dev/null; then
                info "Scanning $service for vulnerabilities..."
                trivy image --severity HIGH,CRITICAL "$full_image_name" || warning "Security scan found issues in $service"
            fi
        else
            info "Dry run mode: Would build and push $service"
        fi
    done
    
    log "Docker images build and push completed"
}

deploy_kubernetes() {
    if [ "$SKIP_K8S" = "true" ]; then
        warning "Skipping Kubernetes deployment"
        return
    fi
    
    log "Deploying services to Kubernetes..."
    
    # Get cluster name from Terraform output
    cd "$TERRAFORM_DIR"
    local cluster_name
    cluster_name=$(terraform output -raw cluster_name 2>/dev/null || echo "ecommerce-microservices-${ENVIRONMENT}-cluster")
    cd - > /dev/null
    
    # Update kubeconfig
    info "Updating kubeconfig for cluster: $cluster_name"
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$cluster_name"
    
    # Verify cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Create namespace if it doesn't exist
    local namespace="$ENVIRONMENT"
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy services using Helm or kubectl
    local services=("user-service" "product-service" "order-service" "payment-service")
    
    for service in "${services[@]}"; do
        info "Deploying $service to Kubernetes..."
        
        local helm_chart_dir="$K8S_DIR/helm-charts/$service"
        local manifest_dir="$K8S_DIR/base"
        
        if [ -d "$helm_chart_dir" ]; then
            # Deploy using Helm
            if [ "$DRY_RUN" = "false" ]; then
                helm upgrade --install "$service" "$helm_chart_dir" \
                    --namespace "$namespace" \
                    --set environment="$ENVIRONMENT" \
                    --set image.tag=latest \
                    --wait \
                    --timeout=10m
            else
                info "Dry run mode: Would deploy $service using Helm"
            fi
        elif [ -f "$manifest_dir/${service}.yaml" ]; then
            # Deploy using kubectl
            if [ "$DRY_RUN" = "false" ]; then
                kubectl apply -f "$manifest_dir/${service}.yaml" -n "$namespace"
                kubectl rollout status deployment "$service" -n "$namespace" --timeout=600s
            else
                info "Dry run mode: Would deploy $service using kubectl"
            fi
        else
            warning "No deployment configuration found for $service"
        fi
    done
    
    # Wait for services to be ready
    if [ "$DRY_RUN" = "false" ]; then
        info "Waiting for services to be ready..."
        for service in "${services[@]}"; do
            kubectl wait --for=condition=ready pod -l app="$service" -n "$namespace" --timeout=300s || warning "Service $service may not be fully ready"
        done
    fi
    
    log "Kubernetes deployment completed"
}

run_health_checks() {
    if [ "$DRY_RUN" = "true" ]; then
        info "Dry run mode: Skipping health checks"
        return
    fi
    
    log "Running health checks..."
    
    local namespace="$ENVIRONMENT"
    local services=("user-service" "product-service" "order-service" "payment-service")
    
    for service in "${services[@]}"; do
        info "Checking health of $service..."
        
        # Get service endpoint
        local service_exists
        service_exists=$(kubectl get service "$service" -n "$namespace" --ignore-not-found=true)
        
        if [ -z "$service_exists" ]; then
            warning "Service $service not found, skipping health check"
            continue
        fi
        
        # Port forward and test
        kubectl port-forward "service/$service" 8080:80 -n "$namespace" > /dev/null 2>&1 &
        local port_forward_pid=$!
        
        sleep 5
        
        if curl -sf "http://localhost:8080/health" > /dev/null 2>&1; then
            info "$service health check passed ✓"
        else
            warning "$service health check failed ✗"
        fi
        
        kill $port_forward_pid 2>/dev/null || true
        sleep 2
    done
    
    log "Health checks completed"
}

cleanup() {
    info "Cleaning up..."
    # Kill any remaining port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
}

main() {
    trap cleanup EXIT
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            --skip-terraform)
                SKIP_TERRAFORM="true"
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER="true"
                shift
                ;;
            --skip-k8s)
                SKIP_K8S="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log "Starting deployment of AWS Microservices E-Commerce Platform"
    log "Environment: $ENVIRONMENT"
    log "AWS Region: $AWS_REGION"
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN MODE - No changes will be made"
    fi
    
    check_prerequisites
    validate_environment
    
    # Set AWS region
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    # Deploy infrastructure
    deploy_terraform
    
    # Build and push Docker images
    build_and_push_images
    
    # Deploy to Kubernetes
    deploy_kubernetes
    
    # Run health checks
    run_health_checks
    
    log "Deployment completed successfully! 🚀"
    log "Access your services at:"
    
    if [ "$DRY_RUN" = "false" ]; then
        # Get load balancer URL
        local lb_hostname
        lb_hostname=$(kubectl get svc -n "$ENVIRONMENT" -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "N/A")
        
        if [ "$lb_hostname" != "N/A" ] && [ -n "$lb_hostname" ]; then
            log "Load Balancer: http://$lb_hostname"
        else
            info "Load balancer URL not available yet, check in a few minutes"
        fi
    fi
}

# Run main function
main "$@"
