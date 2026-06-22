# Days Until API - Deployment Script for Windows
# Usage: .\deploy.ps1

Write-Host "🚀 Days Until API - Deployment Script" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: AWS CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "   Please install AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check AWS credentials
Write-Host "📋 Checking AWS credentials..." -ForegroundColor Yellow
try {
    $awsIdentity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($awsIdentity) {
        Write-Host "✅ AWS credentials configured for account: $($awsIdentity.Account)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Configuration
$stackName = "days-until-api"
$region = "us-east-1"
$functionName = "days-until-api"

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Stack Name: $stackName"
Write-Host "  Region: $region"
Write-Host "  Function Name: $functionName"
Write-Host ""

# Step 1: Package Lambda function
Write-Host "📦 Step 1: Packaging Lambda function..." -ForegroundColor Yellow
Push-Location src
if (Test-Path "../lambda.zip") {
    Remove-Item "../lambda.zip" -Force
}
Compress-Archive -Path * -DestinationPath ../lambda.zip -Force
Pop-Location

if (Test-Path "lambda.zip") {
    Write-Host "✅ Lambda package created successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Error: Failed to create Lambda package" -ForegroundColor Red
    exit 1
}

# Step 2: Deploy CloudFormation stack
Write-Host ""
Write-Host "☁️  Step 2: Deploying CloudFormation stack..." -ForegroundColor Yellow

# Check if user wants custom domain
$useDomain = Read-Host "Do you want to configure a custom domain? (y/n)"
if ($useDomain -eq "y") {
    $domainName = Read-Host "Enter domain name (e.g., days-until.cjl.nz)"
    $certArn = Read-Host "Enter ACM Certificate ARN"
    $hostedZoneId = Read-Host "Enter Route53 Hosted Zone ID (optional, press Enter to skip)"
    
    if ($hostedZoneId) {
        aws cloudformation deploy `
            --template-file infrastructure/template.yaml `
            --stack-name $stackName `
            --parameter-overrides "DomainName=$domainName" "CertificateArn=$certArn" "HostedZoneId=$hostedZoneId" `
            --capabilities CAPABILITY_IAM `
            --region $region
    } else {
        aws cloudformation deploy `
            --template-file infrastructure/template.yaml `
            --stack-name $stackName `
            --parameter-overrides "DomainName=$domainName" "CertificateArn=$certArn" `
            --capabilities CAPABILITY_IAM `
            --region $region
    }
} else {
    aws cloudformation deploy `
        --template-file infrastructure/template.yaml `
        --stack-name $stackName `
        --capabilities CAPABILITY_IAM `
        --region $region
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: CloudFormation deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ CloudFormation stack deployed successfully" -ForegroundColor Green

# Step 3: Update Lambda function code
Write-Host ""
Write-Host "🔄 Step 3: Updating Lambda function code..." -ForegroundColor Yellow

aws lambda update-function-code `
    --function-name $functionName `
    --zip-file fileb://lambda.zip `
    --region $region | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Lambda update failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Lambda function updated successfully" -ForegroundColor Green

# Step 4: Get API URL
Write-Host ""
Write-Host "🌐 Step 4: Getting API URL..." -ForegroundColor Yellow

$apiUrl = aws cloudformation describe-stacks `
    --stack-name $stackName `
    --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" `
    --output text `
    --region $region

if ($apiUrl) {
    Write-Host "✅ API deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  API URL: $apiUrl" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Test the API
    Write-Host "🧪 Testing API..." -ForegroundColor Yellow
    $testDate = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")
    $testUrl = "$apiUrl/v1/days-until/$testDate"
    
    try {
        $response = Invoke-RestMethod -Uri $testUrl -Method Get
        Write-Host "✅ API test successful!" -ForegroundColor Green
        Write-Host "   Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor White
    } catch {
        Write-Host "⚠️  Warning: API test failed, but deployment may still be successful" -ForegroundColor Yellow
        Write-Host "   Wait a few seconds and try manually:" -ForegroundColor Yellow
        Write-Host "   curl $testUrl" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "📚 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Test: curl $apiUrl/v1/days-until/2027-01-01"
    Write-Host "   2. View docs: $apiUrl/docs (requires separate hosting)"
    Write-Host "   3. Monitor logs: aws logs tail /aws/lambda/$functionName --follow"
    Write-Host ""
} else {
    Write-Host "❌ Error: Could not retrieve API URL" -ForegroundColor Red
    exit 1
}

# Cleanup
Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow
Remove-Item lambda.zip -Force -ErrorAction SilentlyContinue

Write-Host "✅ Deployment complete!" -ForegroundColor Green
