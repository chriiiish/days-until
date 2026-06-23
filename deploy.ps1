# Days Until API - Deployment Script for Windows
# Usage: .\deploy.ps1
# Note: Lambda@Edge requires deployment to us-east-1

Write-Host "🚀 Days Until API - Deployment Script (CloudFront + Lambda@Edge)" -ForegroundColor Cyan
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
$region = "us-east-1"  # Lambda@Edge MUST be in us-east-1

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Stack Name: $stackName"
Write-Host "  Region: $region (required for Lambda@Edge)"
Write-Host ""

# Deploy CloudFormation stack
Write-Host "☁️  Deploying CloudFormation stack (CloudFront + Lambda@Edge)..." -ForegroundColor Yellow
Write-Host "   Note: Code is embedded in CloudFormation template" -ForegroundColor Gray
Write-Host ""

# Check if user wants custom domain
$useDomain = Read-Host "Do you want to configure a custom domain? (y/n)"
if ($useDomain -eq "y") {
    $domainName = Read-Host "Enter domain name (e.g., days-until.cjl.nz)"
    $certArn = Read-Host "Enter ACM Certificate ARN (must be in us-east-1 for CloudFront)"
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
Write-Host "   ⏳ CloudFront distribution is being created (this can take 15-20 minutes)" -ForegroundColor Yellow

# Get CloudFront URL
Write-Host ""
Write-Host "🌐 Getting CloudFront URL..." -ForegroundColor Yellow

$cloudFrontUrl = aws cloudformation describe-stacks `
    --stack-name $stackName `
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontUrl'].OutputValue" `
    --output text `
    --region $region

$customDomainUrl = aws cloudformation describe-stacks `
    --stack-name $stackName `
    --query "Stacks[0].Outputs[?OutputKey=='CustomDomainUrl'].OutputValue" `
    --output text `
    --region $region

$distributionId = aws cloudformation describe-stacks `
    --stack-name $stackName `
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" `
    --output text `
    --region $region

if ($cloudFrontUrl) {
    Write-Host "✅ API deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    if ($customDomainUrl -and $customDomainUrl -ne "") {
        Write-Host "  Custom Domain: $customDomainUrl" -ForegroundColor White
    }
    Write-Host "  CloudFront URL: $cloudFrontUrl" -ForegroundColor White
    Write-Host "  Distribution ID: $distributionId" -ForegroundColor Gray
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Test the API
    Write-Host "🧪 Testing API..." -ForegroundColor Yellow
    $testDate = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")
    $testUrl = "$cloudFrontUrl/v1/days-until/$testDate"
    
    Write-Host "   Waiting for CloudFront distribution to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    try {
        $response = Invoke-RestMethod -Uri $testUrl -Method Get
        Write-Host "✅ API test successful!" -ForegroundColor Green
        Write-Host "   Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor White
    } catch {
        Write-Host "⚠️  CloudFront is still deploying. Test manually in a few minutes:" -ForegroundColor Yellow
        Write-Host "   curl $testUrl" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "📚 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Wait for CloudFront deployment to complete (check AWS Console)"
    Write-Host "   2. Test: curl $cloudFrontUrl/v1/days-until/2027-01-01"
    if ($customDomainUrl -and $customDomainUrl -ne "") {
        Write-Host "   3. Use custom domain: $customDomainUrl/v1/days-until/2027-01-01"
    }
    Write-Host ""
    Write-Host "💡 Cache Info:" -ForegroundColor Cyan
    Write-Host "   - Responses cached for 6 hours at CloudFront edge locations"
    Write-Host "   - Lambda@Edge only runs on cache misses (huge cost savings!)"
    Write-Host "   - To invalidate cache: aws cloudfront create-invalidation --distribution-id $distributionId --paths '/*'"
    Write-Host ""
} else {
    Write-Host "❌ Error: Could not retrieve CloudFront URL" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Deployment complete!" -ForegroundColor Green
