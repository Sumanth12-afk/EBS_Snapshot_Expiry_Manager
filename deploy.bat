@echo off
REM ============================================================================
REM EBS Snapshot Expiry Manager - Windows Deployment Script
REM ============================================================================
REM This script automates the complete deployment process on Windows
REM Usage: deploy.bat
REM ============================================================================

setlocal enabledelayedexpansion

REM Configuration
set AWS_REGION=ap-south-1
set SECRET_NAME=ebs/gmail-app-password

echo.
echo ============================================================================
echo   EBS Snapshot Expiry Manager - Deployment (Windows)
echo ============================================================================
echo.

REM ============================================================================
REM Step 1: Prerequisites Check
REM ============================================================================
echo [Step 1] Checking Prerequisites...
echo.

REM Check AWS CLI
where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] AWS CLI not found. Please install it first.
    echo Visit: https://aws.amazon.com/cli/
    pause
    exit /b 1
)
echo [OK] AWS CLI is installed

REM Check Terraform
where terraform >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Terraform not found. Please install it first.
    echo Visit: https://www.terraform.io/downloads
    pause
    exit /b 1
)
echo [OK] Terraform is installed

REM Check AWS credentials
echo.
echo Checking AWS credentials...
aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] AWS credentials not configured
    echo Run: aws configure
    pause
    exit /b 1
)

for /f "tokens=*" %%a in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%a
echo [OK] AWS credentials configured
echo Account ID: %ACCOUNT_ID%
echo.

REM ============================================================================
REM Step 2: Gmail App Password Setup
REM ============================================================================
echo.
echo [Step 2] Gmail App Password Configuration
echo ============================================================================
echo.

echo Checking if secret exists...
aws secretsmanager describe-secret --secret-id %SECRET_NAME% --region %AWS_REGION% >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Gmail secret already exists in Secrets Manager
    echo.
    set /p UPDATE_SECRET="Do you want to update it? (y/N): "
    if /i "!UPDATE_SECRET!"=="y" (
        set /p GMAIL_PASSWORD="Enter Gmail App Password (16 characters): "
        aws secretsmanager update-secret --secret-id %SECRET_NAME% --secret-string "{\"password\":\"!GMAIL_PASSWORD!\"}" --region %AWS_REGION%
        echo [OK] Gmail secret updated
    )
) else (
    echo [WARNING] Gmail secret not found in Secrets Manager
    echo.
    echo You need to create a Gmail App Password first:
    echo 1. Go to: https://myaccount.google.com/apppasswords
    echo 2. Enable 2-Step Verification if not already enabled
    echo 3. Create an app password for 'Mail' ^> 'Other'
    echo 4. Copy the 16-character password
    echo.
    
    set /p HAVE_PASSWORD="Do you have your Gmail App Password ready? (y/N): "
    if /i "!HAVE_PASSWORD!"=="y" (
        set /p GMAIL_PASSWORD="Enter Gmail App Password (16 characters): "
        
        aws secretsmanager create-secret --name %SECRET_NAME% --description "Gmail SMTP password for EBS Snapshot Manager" --secret-string "{\"password\":\"!GMAIL_PASSWORD!\"}" --region %AWS_REGION%
        
        if !errorlevel! equ 0 (
            echo [OK] Gmail secret created successfully
        ) else (
            echo [ERROR] Failed to create secret
            pause
            exit /b 1
        )
    ) else (
        echo [ERROR] Gmail App Password is required. Please create it and run this script again.
        pause
        exit /b 1
    )
)

REM ============================================================================
REM Step 3: Terraform Configuration
REM ============================================================================
echo.
echo [Step 3] Terraform Configuration
echo ============================================================================
echo.

if not exist "terraform" (
    echo [ERROR] terraform\ directory not found
    echo Make sure you're running this script from the project root
    pause
    exit /b 1
)

cd terraform

if not exist "terraform.tfvars" (
    echo Creating terraform.tfvars from example...
    copy terraform.tfvars.example terraform.tfvars >nul
    echo [OK] terraform.tfvars created
    echo.
    echo [WARNING] IMPORTANT: You need to edit terraform.tfvars with your settings!
    echo Required settings:
    echo   - gmail_user: Your Gmail address
    echo   - alert_receiver: Email to receive reports
    echo   - aws_region: Your AWS region (default: ap-south-1)
    echo.
    
    set /p EDIT_NOW="Open terraform.tfvars for editing now? (y/N): "
    if /i "!EDIT_NOW!"=="y" (
        notepad terraform.tfvars
        echo.
        echo Press any key after you've saved and closed the editor...
        pause >nul
    ) else (
        echo [WARNING] Please edit terraform.tfvars before continuing
        echo Run this script again when ready
        cd ..
        pause
        exit /b 0
    )
) else (
    echo [OK] terraform.tfvars already exists
)

REM ============================================================================
REM Step 4: Terraform Initialization
REM ============================================================================
echo.
echo [Step 4] Terraform Initialization
echo ============================================================================
echo.

echo Running terraform init...
terraform init
if %errorlevel% neq 0 (
    echo [ERROR] Terraform initialization failed
    cd ..
    pause
    exit /b 1
)
echo [OK] Terraform initialized

REM ============================================================================
REM Step 5: Terraform Validation
REM ============================================================================
echo.
echo [Step 5] Terraform Validation
echo ============================================================================
echo.

echo Validating Terraform configuration...
terraform validate
if %errorlevel% neq 0 (
    echo [ERROR] Terraform validation failed
    cd ..
    pause
    exit /b 1
)
echo [OK] Terraform configuration is valid

REM ============================================================================
REM Step 6: Terraform Plan
REM ============================================================================
echo.
echo [Step 6] Terraform Plan
echo ============================================================================
echo.

echo Running terraform plan...
terraform plan -out=tfplan
if %errorlevel% neq 0 (
    echo [ERROR] Terraform plan failed
    cd ..
    pause
    exit /b 1
)
echo [OK] Terraform plan completed
echo.

echo [WARNING] Review the plan above carefully!
echo Resources to be created:
echo   - Lambda function
echo   - IAM role and policies
echo   - DynamoDB table
echo   - EventBridge rule
echo   - CloudWatch Log Group
echo.

set /p CONFIRM="Continue with deployment? Type 'yes' to proceed: "
if /i not "!CONFIRM!"=="yes" (
    echo [WARNING] Deployment cancelled
    del tfplan 2>nul
    cd ..
    pause
    exit /b 0
)

REM ============================================================================
REM Step 7: Terraform Apply
REM ============================================================================
echo.
echo [Step 7] Terraform Apply
echo ============================================================================
echo.

echo Deploying infrastructure...
terraform apply tfplan
if %errorlevel% neq 0 (
    echo [ERROR] Terraform apply failed
    cd ..
    pause
    exit /b 1
)
echo [OK] Infrastructure deployed successfully!
del tfplan 2>nul

REM Get outputs
for /f "tokens=*" %%a in ('terraform output -raw lambda_function_name 2^>nul') do set LAMBDA_NAME=%%a
if "!LAMBDA_NAME!"=="" set LAMBDA_NAME=ebs-snapshot-manager-prod

for /f "tokens=*" %%a in ('terraform output -raw dynamodb_table_name 2^>nul') do set DYNAMODB_TABLE=%%a
if "!DYNAMODB_TABLE!"=="" set DYNAMODB_TABLE=ebs-snapshot-manager-reports-prod

REM ============================================================================
REM Step 8: Testing
REM ============================================================================
echo.
echo [Step 8] Testing Deployment
echo ============================================================================
echo.

echo Waiting 5 seconds for resources to be ready...
timeout /t 5 /nobreak >nul

echo Invoking Lambda function for test...
cd ..

aws lambda invoke --function-name %LAMBDA_NAME% --region %AWS_REGION% --log-type Tail response.json >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Lambda invocation successful
    
    if exist response.json (
        echo [OK] Response saved to response.json
        type response.json
    )
) else (
    echo [WARNING] Lambda invocation failed
    echo Check CloudWatch logs for details
)

REM ============================================================================
REM Step 9: Verification
REM ============================================================================
echo.
echo [Step 9] Deployment Verification
echo ============================================================================
echo.

echo Checking DynamoDB records...
aws dynamodb scan --table-name %DYNAMODB_TABLE% --select COUNT --region %AWS_REGION% >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] DynamoDB table is accessible
) else (
    echo [WARNING] Could not access DynamoDB table
)

REM ============================================================================
REM Final Summary
REM ============================================================================
echo.
echo ============================================================================
echo   DEPLOYMENT COMPLETE!
echo ============================================================================
echo.
echo [OK] Lambda Function: %LAMBDA_NAME%
echo [OK] DynamoDB Table: %DYNAMODB_TABLE%
echo [OK] Region: %AWS_REGION%
echo [OK] Schedule: Daily at 6 AM UTC
echo.
echo Next Steps:
echo 1. Check your email for the first scan report
echo 2. Review the report for accuracy
echo 3. Monitor for a few days before enabling auto-delete
echo.
echo Useful Commands:
echo.
echo   View logs:
echo     aws logs tail /aws/lambda/%LAMBDA_NAME% --follow --region %AWS_REGION%
echo.
echo   Manual invoke:
echo     aws lambda invoke --function-name %LAMBDA_NAME% --region %AWS_REGION% response.json
echo.
echo   Check DynamoDB:
echo     aws dynamodb scan --table-name %DYNAMODB_TABLE% --max-items 5 --region %AWS_REGION%
echo.
echo   Terraform outputs:
echo     cd terraform ^&^& terraform output
echo.
echo [WARNING] Auto-delete is currently DISABLED for safety
echo To enable after testing, edit terraform\terraform.tfvars:
echo   enable_auto_delete = true
echo Then run: cd terraform ^&^& terraform apply
echo.
echo [OK] Deployment completed successfully!
echo.
pause
exit /b 0

