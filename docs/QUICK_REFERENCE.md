# Quick Reference Guide

## Common Commands

### Test Locally
```bash
node -e "import('./src/index.js').then(m => m.handler({path: '/v1/2027-01-01', httpMethod: 'GET', queryStringParameters: null}).then(r => console.log(JSON.stringify(r, null, 2))))"
```

### Package Lambda
```bash
cd src && zip -r ../lambda.zip . && cd ..
```

### Deploy Stack (First Time)
```bash
aws cloudformation create-stack \
  --stack-name days-until-api \
  --template-body file://infrastructure/template.yaml \
  --capabilities CAPABILITY_IAM
```

### Update Stack
```bash
aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name days-until-api \
  --capabilities CAPABILITY_IAM
```

### Update Lambda Code
```bash
aws lambda update-function-code \
  --function-name days-until-api \
  --zip-file fileb://lambda.zip
```

### Get API URL
```bash
aws cloudformation describe-stacks \
  --stack-name days-until-api \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text
```

### Test API
```bash
API_URL=$(aws cloudformation describe-stacks --stack-name days-until-api --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)
curl "${API_URL}/v1/2027-01-01"
curl "${API_URL}/v1/2027-12-25?label=Christmas&color=green"
```

### View Logs
```bash
aws logs tail /aws/lambda/days-until-api --follow
```

### Delete Stack
```bash
aws cloudformation delete-stack --stack-name days-until-api
```

## GitHub Actions Setup

### Required Secrets
- `AWS_ROLE_ARN` - IAM role for GitHub Actions (OIDC)
- `DEPLOYMENT_BUCKET` - S3 bucket for Lambda packages
- `DOMAIN_NAME` - Custom domain (optional)
- `CERTIFICATE_ARN` - ACM certificate ARN (optional)
- `HOSTED_ZONE_ID` - Route53 zone ID (optional)

## Testing Examples

### Bash
```bash
# Basic request
curl https://days-until.cjl.nz/v1/2027-01-01

# With custom label and color
curl "https://days-until.cjl.nz/v1/2027-12-25?label=Christmas&color=green"
```

### JavaScript/Node.js
```javascript
const response = await fetch('https://days-until.cjl.nz/v1/2027-01-01');
const data = await response.json();
console.log(data);
// { schemaVersion: 1, label: "Days Remaining", message: "557 days", color: "blue" }
```

### Python
```python
import requests
response = requests.get('https://days-until.cjl.nz/v1/2027-01-01')
print(response.json())
# {'schemaVersion': 1, 'label': 'Days Remaining', 'message': '557 days', 'color': 'blue'}
```

## Troubleshooting

### Lambda Execution Errors
```bash
aws logs tail /aws/lambda/days-until-api --since 10m
```

### API Gateway Issues
Check CloudWatch logs and X-Ray traces in AWS Console

### Stack Update Failures
```bash
aws cloudformation describe-stack-events \
  --stack-name days-until-api \
  --max-items 10
```
