#!/bin/bash

################################################################################
# EBS Snapshot Expiry Manager - Automated Deployment Script
################################################################################
# This script automates the complete deployment process
# Usage: ./deploy.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
SECRET_NAME="ebs/gmail-app-password"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    print_success "$1 is installed"
    return 0
}

################################################################################
# Main Deployment Steps
################################################################################

main() {
    print_header "EBS Snapshot Expiry Manager - Deployment"
    
    # Step 1: Prerequisites Check
    print_header "Step 1: Checking Prerequisites"
    
    check_command "aws" || exit 1
    check_command "terraform" || exit 1
    check_command "python" || print_warning "Python not found (optional for local testing)"
    
    # Check AWS credentials
    print_info "Checking AWS credentials..."
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS credentials configured"
        print_info "Account ID: $ACCOUNT_ID"
        print_info "User/Role: $USER_ARN"
    else
        print_error "AWS credentials not configured"
        print_info "Run: aws configure"
        exit 1
    fi
    
    # Step 2: Gmail App Password Setup
    print_header "Step 2: Gmail App Password Configuration"
    
    print_info "Checking if secret exists..."
    if aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $AWS_REGION &> /dev/null; then
        print_success "Gmail secret already exists in Secrets Manager"
        
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -sp "Enter Gmail App Password (16 characters): " GMAIL_PASSWORD
            echo
            
            aws secretsmanager update-secret \
                --secret-id $SECRET_NAME \
                --secret-string "{\"password\":\"$GMAIL_PASSWORD\"}" \
                --region $AWS_REGION
            
            print_success "Gmail secret updated"
        fi
    else
        print_warning "Gmail secret not found in Secrets Manager"
        print_info "You need to create a Gmail App Password first:"
        print_info "1. Go to: https://myaccount.google.com/apppasswords"
        print_info "2. Enable 2-Step Verification if not already enabled"
        print_info "3. Create an app password for 'Mail' > 'Other'"
        print_info "4. Copy the 16-character password"
        echo
        
        read -p "Do you have your Gmail App Password ready? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -sp "Enter Gmail App Password (16 characters): " GMAIL_PASSWORD
            echo
            
            if [ -z "$GMAIL_PASSWORD" ]; then
                print_error "Password cannot be empty"
                exit 1
            fi
            
            aws secretsmanager create-secret \
                --name $SECRET_NAME \
                --description "Gmail SMTP password for EBS Snapshot Manager" \
                --secret-string "{\"password\":\"$GMAIL_PASSWORD\"}" \
                --region $AWS_REGION
            
            print_success "Gmail secret created successfully"
        else
            print_error "Gmail App Password is required. Please create it and run this script again."
            exit 1
        fi
    fi
    
    # Step 3: Terraform Configuration
    print_header "Step 3: Terraform Configuration"
    
    if [ ! -d "terraform" ]; then
        print_error "terraform/ directory not found"
        print_info "Make sure you're running this script from the project root"
        exit 1
    fi
    
    cd terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        print_info "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_success "terraform.tfvars created"
        
        print_warning "IMPORTANT: You need to edit terraform.tfvars with your settings!"
        print_info "Required settings:"
        print_info "  - gmail_user: Your Gmail address"
        print_info "  - alert_receiver: Email to receive reports"
        print_info "  - aws_region: Your AWS region (default: ap-south-1)"
        echo
        
        read -p "Open terraform.tfvars for editing now? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v nano &> /dev/null; then
                nano terraform.tfvars
            elif command -v vim &> /dev/null; then
                vim terraform.tfvars
            elif command -v code &> /dev/null; then
                code terraform.tfvars
                print_info "Waiting for you to save and close the editor..."
                read -p "Press Enter when done editing..."
            else
                print_warning "No editor found. Please edit terraform.tfvars manually."
                exit 1
            fi
        else
            print_warning "Please edit terraform.tfvars before continuing"
            print_info "Run this script again when ready"
            exit 0
        fi
    else
        print_success "terraform.tfvars already exists"
    fi
    
    # Step 4: Terraform Initialization
    print_header "Step 4: Terraform Initialization"
    
    print_info "Running terraform init..."
    if terraform init; then
        print_success "Terraform initialized"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    # Step 5: Terraform Validation
    print_header "Step 5: Terraform Validation"
    
    print_info "Validating Terraform configuration..."
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Step 6: Terraform Plan
    print_header "Step 6: Terraform Plan"
    
    print_info "Running terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan completed"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    echo
    print_warning "Review the plan above carefully!"
    print_info "Resources to be created:"
    print_info "  - Lambda function"
    print_info "  - IAM role and policies"
    print_info "  - DynamoDB table"
    print_info "  - EventBridge rule"
    print_info "  - CloudWatch Log Group"
    echo
    
    read -p "Continue with deployment? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        print_warning "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
    
    # Step 7: Terraform Apply
    print_header "Step 7: Terraform Apply"
    
    print_info "Deploying infrastructure..."
    if terraform apply tfplan; then
        print_success "Infrastructure deployed successfully!"
        rm -f tfplan
    else
        print_error "Terraform apply failed"
        exit 1
    fi
    
    # Get outputs
    LAMBDA_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "ebs-snapshot-manager-prod")
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "ebs-snapshot-manager-reports-prod")
    
    # Step 8: Testing
    print_header "Step 8: Testing Deployment"
    
    print_info "Waiting 5 seconds for resources to be ready..."
    sleep 5
    
    print_info "Invoking Lambda function for test..."
    cd ..
    
    if aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --region "$AWS_REGION" \
        --log-type Tail \
        response.json > /dev/null 2>&1; then
        
        print_success "Lambda invocation successful"
        
        if [ -f "response.json" ]; then
            STATUS_CODE=$(cat response.json | grep -o '"statusCode":[0-9]*' | cut -d':' -f2 || echo "unknown")
            
            if [ "$STATUS_CODE" = "200" ]; then
                print_success "Lambda execution completed successfully"
                print_info "Response saved to response.json"
                
                # Show summary
                TOTAL_SNAPSHOTS=$(cat response.json | grep -o '"total_snapshots":[0-9]*' | cut -d':' -f2 || echo "0")
                OLD_SNAPSHOTS=$(cat response.json | grep -o '"old_snapshots_count":[0-9]*' | cut -d':' -f2 || echo "0")
                
                echo
                print_info "Scan Results:"
                print_info "  Total Snapshots: $TOTAL_SNAPSHOTS"
                print_info "  Old Snapshots: $OLD_SNAPSHOTS"
            else
                print_warning "Lambda returned status code: $STATUS_CODE"
                print_info "Check response.json for details"
            fi
        fi
    else
        print_error "Lambda invocation failed"
        print_info "Check CloudWatch logs for details"
    fi
    
    # Step 9: Verification
    print_header "Step 9: Deployment Verification"
    
    print_info "Checking DynamoDB records..."
    ITEM_COUNT=$(aws dynamodb scan \
        --table-name "$DYNAMODB_TABLE" \
        --select COUNT \
        --region "$AWS_REGION" \
        2>/dev/null | grep -o '"Count":[0-9]*' | cut -d':' -f2 || echo "0")
    
    if [ "$ITEM_COUNT" -gt 0 ]; then
        print_success "DynamoDB has $ITEM_COUNT records"
    else
        print_warning "No DynamoDB records found (this may be normal if you have no snapshots)"
    fi
    
    print_info "Checking CloudWatch logs..."
    LOG_STREAM=$(aws logs describe-log-streams \
        --log-group-name "/aws/lambda/$LAMBDA_NAME" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --region "$AWS_REGION" \
        2>/dev/null | grep -o '"logStreamName":"[^"]*' | cut -d'"' -f4 || echo "")
    
    if [ -n "$LOG_STREAM" ]; then
        print_success "CloudWatch logs available"
        print_info "Log stream: $LOG_STREAM"
    fi
    
    # Final Summary
    print_header "Deployment Complete! 🎉"
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  DEPLOYMENT SUMMARY                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    print_success "Lambda Function: $LAMBDA_NAME"
    print_success "DynamoDB Table: $DYNAMODB_TABLE"
    print_success "Region: $AWS_REGION"
    print_success "Schedule: Daily at 6 AM UTC"
    echo
    print_info "Next Steps:"
    print_info "1. Check your email for the first scan report"
    print_info "2. Review the report for accuracy"
    print_info "3. Monitor for a few days before enabling auto-delete"
    echo
    print_info "Useful Commands:"
    echo -e "  ${YELLOW}View logs:${NC}"
    echo "    aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $AWS_REGION"
    echo
    echo -e "  ${YELLOW}Manual invoke:${NC}"
    echo "    aws lambda invoke --function-name $LAMBDA_NAME --region $AWS_REGION response.json"
    echo
    echo -e "  ${YELLOW}Check DynamoDB:${NC}"
    echo "    aws dynamodb scan --table-name $DYNAMODB_TABLE --max-items 5 --region $AWS_REGION"
    echo
    echo -e "  ${YELLOW}Terraform outputs:${NC}"
    echo "    cd terraform && terraform output"
    echo
    
    print_warning "Auto-delete is currently DISABLED for safety"
    print_info "To enable after testing, edit terraform/terraform.tfvars:"
    print_info "  enable_auto_delete = true"
    print_info "Then run: cd terraform && terraform apply"
    echo
    
    print_success "Deployment completed successfully!"
    echo
}

################################################################################
# Script Entry Point
################################################################################

# Check if running from correct directory
if [ ! -f "README.md" ] || [ ! -d "terraform" ] || [ ! -d "lambda" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Run main deployment
main

exit 0

