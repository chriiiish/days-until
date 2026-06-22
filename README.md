# Days Until API

A lightweight, serverless API that calculates the number of days from today to a target date. Hosted on AWS API Gateway with Lambda.

🌐 **Live API**: [https://days-until.cjl.nz](https://days-until.cjl.nz)  
📚 **Documentation**: [https://days-until.cjl.nz/docs](https://days-until.cjl.nz/docs)

## Features

- ⚡ **Ultra-lightweight**: Single Lambda function, no dependencies
- 🚀 **Fast**: Typical response time < 50ms
- 💰 **Cost-effective**: Runs entirely on AWS free tier for moderate usage
- 🌍 **Public API**: No authentication required
- 📖 **OpenAPI/Swagger**: Interactive documentation included
- 🔒 **CORS-enabled**: Use from any web application

## Quick Start

### API Usage

Calculate days until a future date:
```bash
curl https://days-until.cjl.nz/v1/days-until/2027-01-01
# Response: {"days": 557}
```

Calculate days with a custom label:
```bash
curl https://days-until.cjl.nz/v1/days-until/2027-12-25?title=Christmas
# Response: {"Christmas": 557}
```

Calculate days since a past date:
```bash
curl https://days-until.cjl.nz/v1/days-until/2020-01-01
# Response: {"days": -2364}
```

### JavaScript Example

```javascript
async function getDaysUntil(date, title = null) {
  const url = title 
    ? `https://days-until.cjl.nz/v1/days-until/${date}?title=${title}`
    : `https://days-until.cjl.nz/v1/days-until/${date}`;
  
  const response = await fetch(url);
  return response.json();
}

// Usage
const result = await getDaysUntil('2027-12-31', 'New Year');
console.log(result); // { "New Year": 557 }
```

## API Reference

### Endpoint

```
GET /v1/days-until/{date}
```

### Path Parameters

| Parameter | Type   | Required | Description                      |
|-----------|--------|----------|----------------------------------|
| date      | string | Yes      | Target date in `yyyy-mm-dd` format |

### Query Parameters

| Parameter | Type   | Required | Description                                          |
|-----------|--------|----------|------------------------------------------------------|
| title     | string | No       | Custom label for the response (replaces "days")      |

### Response

**Default response:**
```json
{
  "days": 192
}
```

**Custom title response:**
```json
{
  "Christmas": 192
}
```

### Status Codes

- `200 OK`: Successful calculation
- `400 Bad Request`: Invalid date format
- `500 Internal Server Error`: Server error

## Project Structure

```
.
├── src/                    # Lambda function source code
│   └── index.js           # Main handler
├── infrastructure/         # AWS infrastructure as code
│   └── template.yaml      # CloudFormation template
├── docs/                   # Documentation
│   ├── openapi.yaml       # OpenAPI 3.0 specification
│   ├── index.html         # Swagger UI page
│   └── DEPLOYMENT.md      # Deployment guide
├── .github/
│   └── workflows/
│       └── deploy.yml     # GitHub Actions CI/CD
└── package.json           # Project metadata
```

## Local Development

### Prerequisites

- Node.js 22.x or later
- AWS CLI (for deployment)
- AWS Account

### Test Locally

```bash
# Clone the repository
git clone <repository-url>
cd days-until

# Test the Lambda function
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

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

2. **Deploy the stack:**
   ```bash
   aws cloudformation deploy \
     --template-file infrastructure/template.yaml \
     --stack-name days-until-api \
     --capabilities CAPABILITY_IAM
   ```

3. **Update Lambda code:**
   ```bash
   # Package
   cd src && zip -r ../lambda.zip . && cd ..
   
   # Deploy
   aws lambda update-function-code \
     --function-name days-until-api \
     --zip-file fileb://lambda.zip
   ```

4. **Get your API URL:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name days-until-api \
     --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
     --output text
   ```

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────┐
│   API Gateway       │
│   (days-until.cjl.nz)│
└──────┬──────────────┘
       │ Invoke
       ▼
┌─────────────────────┐
│  Lambda Function    │
│  (Node.js 22.x)     │
│  - No dependencies  │
│  - 128 MB memory    │
│  - ~5ms execution   │
└─────────────────────┘
```

## Technology Stack

- **Runtime**: Node.js 22.x (ES Modules)
- **Compute**: AWS Lambda (128 MB, ~10s timeout)
- **API**: AWS API Gateway (REST API)
- **Infrastructure**: AWS CloudFormation
- **CI/CD**: GitHub Actions
- **Documentation**: OpenAPI 3.0 + Swagger UI

## Cost Estimation

| Service       | Free Tier                | Cost Beyond Free Tier    |
|---------------|--------------------------|--------------------------|
| Lambda        | 1M requests/month        | $0.20 per 1M requests    |
| API Gateway   | 1M requests/month        | $3.50 per 1M requests    |
| CloudWatch    | 5GB logs/month           | $0.50 per GB             |
| **Total**     | **$0/month** (typical)   | **~$4 per 1M requests**  |

For moderate usage (< 1M requests/month), this API runs **completely free** on AWS.

## Performance

- **Cold start**: ~200-300ms
- **Warm execution**: ~5-10ms
- **Typical response time**: ~50ms (including network)
- **Memory usage**: ~40MB

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Built with ❤️ using Node.js and AWS**
