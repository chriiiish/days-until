# Deployment Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Node.js 22.x** or later
4. **Custom Domain** (optional): SSL certificate in AWS Certificate Manager
5. **S3 Bucket** for Lambda deployment packages (for CI/CD)

## Local Development

### Test the Lambda function locally

```bash
# Install Node.js dependencies (none required for this simple API)
npm install

# Test locally with Node.js
node -e "
import('./src/index.js').then(module => {
  const event = {
    path: '/v1/days-until/2027-01-01',
    httpMethod: 'GET',
    queryStringParameters: null
  };
  module.handler(event).then(response => console.log(JSON.stringify(response, null, 2)));
});
"
```

## Manual Deployment

### Step 1: Package the Lambda function

```bash
cd src
zip -r ../lambda.zip .
cd ..
```

### Step 2: Create an S3 bucket for deployment (if not exists)

```bash
aws s3 mb s3://your-deployment-bucket --region us-east-1
```

### Step 3: Upload the Lambda package

```bash
aws s3 cp lambda.zip s3://your-deployment-bucket/lambda-deployments/days-until-api.zip
```

### Step 4: Deploy the CloudFormation stack

**Without custom domain:**

```bash
aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name days-until-api \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

**With custom domain:**

```bash
aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name days-until-api \
  --parameter-overrides \
    DomainName=days-until.cjl.nz \
    CertificateArn=arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID \
    HostedZoneId=Z1234567890ABC \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

### Step 5: Update Lambda function code

```bash
# Get the function name from CloudFormation outputs
FUNCTION_NAME=$(aws cloudformation describe-stacks \
  --stack-name days-until-api \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" \
  --output text)

# Update the function code
aws lambda update-function-code \
  --function-name ${FUNCTION_NAME} \
  --s3-bucket your-deployment-bucket \
  --s3-key lambda-deployments/days-until-api.zip
```

### Step 6: Get the API URL

```bash
aws cloudformation describe-stacks \
  --stack-name days-until-api \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text
```

## CI/CD with GitHub Actions

### Setup

1. **Create an S3 bucket** for Lambda deployments:
   ```bash
   aws s3 mb s3://your-deployment-bucket
   ```

2. **Create AWS IAM Role for GitHub Actions** (recommended - using OIDC):
   
   ```bash
   # Create identity provider for GitHub
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   
   # Create IAM role with trust policy for GitHub
   # See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
   ```

3. **Configure GitHub Secrets**:

   Go to your repository → Settings → Secrets and variables → Actions, and add:

   - `AWS_ROLE_ARN`: ARN of the IAM role for GitHub Actions
   - `DEPLOYMENT_BUCKET`: S3 bucket name for Lambda packages
   - `DOMAIN_NAME`: `days-until.cjl.nz` (optional)
   - `CERTIFICATE_ARN`: ACM certificate ARN (optional)
   - `HOSTED_ZONE_ID`: Route53 hosted zone ID (optional)

   **Alternative (less secure)**: Use access keys
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### Trigger Deployment

Push to the `main` branch or manually trigger the workflow:

```bash
git add .
git commit -m "Deploy API"
git push origin main
```

Or trigger manually from GitHub Actions tab.

## Custom Domain Setup

### 1. Request SSL Certificate

```bash
aws acm request-certificate \
  --domain-name days-until.cjl.nz \
  --validation-method DNS \
  --region us-east-1
```

### 2. Validate the certificate

Follow the DNS validation instructions from ACM console.

### 3. Get Certificate ARN

```bash
aws acm list-certificates --region us-east-1
```

### 4. Deploy with custom domain parameters

Use the certificate ARN when deploying (see Step 4 above).

## Testing

### Test the API

```bash
# Get the API URL
API_URL=$(aws cloudformation describe-stacks \
  --stack-name days-until-api \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text)

# Test basic endpoint
curl "${API_URL}/v1/days-until/2027-01-01"

# Test with custom title
curl "${API_URL}/v1/days-until/2027-12-25?title=Christmas"

# Test with past date
curl "${API_URL}/v1/days-until/2020-01-01"
```

### Expected responses

```json
{"days": 557}
```

```json
{"Christmas": 557}
```

```json
{"days": -2364}
```

## Monitoring

### View CloudWatch Logs

```bash
# Get log group name
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/days-until-api

# Tail logs
aws logs tail /aws/lambda/days-until-api --follow
```

### View API Gateway metrics

```bash
# Get API ID
API_ID=$(aws cloudformation describe-stacks \
  --stack-name days-until-api \
  --query "Stacks[0].Outputs[?OutputKey=='ApiId'].OutputValue" \
  --output text)

# View in CloudWatch console
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#metricsV2:graph=~();query=~'*7bAWS*2fApiGateway*2cApiName*7d*20${API_ID}"
```

## Updating the API

### Update Lambda code

1. Modify `src/index.js`
2. Package and deploy:
   ```bash
   cd src && zip -r ../lambda.zip . && cd ..
   aws lambda update-function-code \
     --function-name days-until-api \
     --zip-file fileb://lambda.zip
   ```

### Update infrastructure

1. Modify `infrastructure/template.yaml`
2. Deploy stack:
   ```bash
   aws cloudformation deploy \
     --template-file infrastructure/template.yaml \
     --stack-name days-until-api \
     --capabilities CAPABILITY_IAM
   ```

## Cleanup

To remove all resources:

```bash
aws cloudformation delete-stack --stack-name days-until-api
```

## Costs

This is an extremely lightweight setup:
- **Lambda**: Free tier includes 1M requests/month
- **API Gateway**: Free tier includes 1M requests/month
- **CloudWatch Logs**: Free tier includes 5GB/month

Expected monthly cost: **$0** (within free tier) to **~$1-5** for moderate usage.
