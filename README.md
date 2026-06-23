# Days Until API

A lightweight, serverless API that calculates the number of days from today to a target date. Hosted on AWS CloudFront with Lambda@Edge.

🌐 **Live API**: [https://days-until.cjl.nz](https://days-until.cjl.nz)  
📚 **Documentation**: [https://days-until.cjl.nz/docs](https://days-until.cjl.nz/docs)

## Features

- ⚡ **Ultra-lightweight**: Single Lambda@Edge function, no dependencies
- 🚀 **Fast**: Runs at CloudFront edge locations for low latency
- 💰 **Cost-effective**: 6-hour caching reduces costs by >90%
- 🌍 **Public API**: No authentication required
- 📖 **OpenAPI/Swagger**: Interactive documentation included
- 🔒 **CORS-enabled**: Use from any web application
- 🎨 **Shields.io Compatible**: Response format works with [Shields.io Endpoint Badge](https://shields.io/badges/endpoint-badge)
- 🗄️ **Self-contained**: All code embedded in CloudFormation template

## Quick Start

### API Usage

Calculate days until a future date:
```bash
curl https://days-until.cjl.nz/v1/days-until/2027-01-01
# Response: {"schemaVersion": 1, "label": "Days Remaining", "message": "557 days", "color": "blue"}
```

Calculate days with a custom label:
```bash
curl https://days-until.cjl.nz/v1/days-until/2027-12-25?label=Christmas
# Response: {"schemaVersion": 1, "label": "Christmas", "message": "557 days", "color": "blue"}
```

Calculate days since a past date:
```bash
curl https://days-until.cjl.nz/v1/days-until/2020-01-01
# Response: {"schemaVersion": 1, "label": "Days Remaining", "message": "-2364 days", "color": "blue"}
```

### Use with Shields.io

The response format is compatible with [Shields.io Endpoint Badge](https://shields.io/badges/endpoint-badge). Create dynamic badges in your README:

```markdown
![Days Until 2027](https://img.shields.io/endpoint?url=https://days-until.cjl.nz/v1/days-until/2027-01-01)
![Christmas Countdown](https://img.shields.io/endpoint?url=https://days-until.cjl.nz/v1/days-until/2027-12-25?label=Christmas&color=red)
```

### JavaScript Example

```javascript
async function getDaysUntil(date, label = null, color = 'blue') {
  const params = new URLSearchParams();
  if (label) params.append('label', label);
  if (color) params.append('color', color);
  
  const url = `https://days-until.cjl.nz/v1/days-until/${date}${params.toString() ? '?' + params.toString() : ''}`;
  const response = await fetch(url);
  return response.json();
}

// Usage
const result = await getDaysUntil('2027-12-31', 'New Year', 'green');
console.log(result);
// { "schemaVersion": 1, "label": "New Year", "message": "557 days", "color": "green" }
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
| label     | string | No       | Custom label for the badge (default: "Days Remaining") |
| color     | string | No       | Badge color (default: "blue"). Also accepts "colour" spelling |

### Response

**Default response (Shields.io badge format):**
```json
{
  "schemaVersion": 1,
  "label": "Days Remaining",
  "message": "192 days",
  "color": "blue"
}
```

**Custom label and color:**
```json
{
  "schemaVersion": 1,
  "label": "Christmas",
  "message": "192 days",
  "color": "green"
}
```

### Status Codes

- `200 OK`: Successful calculation
- `400 Bad Request`: Invalid date format
- `500 Internal Server Error`: Server error

## Project Structure

```
.
├── infrastructure/         # AWS infrastructure as code
│   └── template.yaml      # CloudFormation template (includes Lambda code)
├── docs/                   # Documentation
│   ├── openapi.yaml       # OpenAPI 3.0 specification
│   ├── index.html         # Swagger UI page
│   └── DEPLOYMENT.md      # Deployment guide
├── src/                    # Reference code (embedded in CloudFormation)
│   └── index.js           # Lambda@Edge handler
├── .github/
│   └── workflows/
│       └── deploy.yml     # GitHub Actions CI/CD
└── package.json           # Project metadata
```

**Note**: The Lambda@Edge code is embedded directly in the CloudFormation template for simplified deployment.

## Local Development

### Prerequisites

- Node.js 22.x or later (for local testing)
- AWS CLI (for deployment)
- AWS Account

### Test Locally

```bash
# Clone the repository
git clone <repository-url>
cd days-until

# Test the Lambda@Edge function locally (reference code in src/)
node -e "
import('./src/index.js').then(module => {
  const event = {
    Records: [{
      cf: {
        request: {
          uri: '/v1/days-until/2027-01-01',
          method: 'GET',
          querystring: 'label=Test&color=blue'
        }
      }
    }]
  };
  module.handler(event).then(response => console.log(JSON.stringify(response, null, 2)));
});
"
```

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy (Windows)

```powershell
.\deploy.ps1
```

### Manual Deploy

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

2. **Deploy the stack** (must be in us-east-1 for Lambda@Edge):
   ```bash
   aws cloudformation deploy \
     --template-file infrastructure/template.yaml \
     --stack-name days-until-api \
     --capabilities CAPABILITY_IAM \
     --region us-east-1
   ```

3. **Get your CloudFront URL:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name days-until-api \
     --query "Stacks[0].Outputs[?OutputKey=='CloudFrontUrl'].OutputValue" \
     --output text \
     --region us-east-1
   ```

4. **Wait for CloudFront deployment** (15-20 minutes)

**Note**: Code is embedded in CloudFormation template - no separate packaging needed!

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────┐
│   CloudFront CDN        │
│   (days-until.cjl.nz)   │
│   - 6-hour edge cache   │
│   - Global distribution │
└──────┬──────────────────┘
       │ Cache Miss
       ▼
┌─────────────────────────┐
│  Lambda@Edge            │
│  (Origin Request)       │
│  - Node.js 22.x         │
│  - No dependencies      │
│  - Runs at edge         │
└─────────────────────────┘
```

**Key benefits:**
- Cache hits served from CloudFront edge (no Lambda invocation)
- Lambda@Edge runs at edge locations for reduced latency
- No API Gateway costs
- 6-hour cache TTL reduces Lambda invocations by >90%

## Technology Stack

- **Runtime**: Node.js 22.x (ES Modules)
- **Compute**: AWS Lambda@Edge (128 MB, 5s timeout)
- **CDN**: AWS CloudFront (6-hour cache)
- **Infrastructure**: AWS CloudFormation (single template)
- **CI/CD**: GitHub Actions
- **Documentation**: OpenAPI 3.0 + Swagger UI

## Cost Estimation

| Service       | Free Tier                | Cost Beyond Free Tier    | Notes                           |
|---------------|--------------------------|--------------------------|----------------------------------|
| CloudFront    | 1TB/month, 10M requests  | $0.085 per 10K requests  | ~90% of requests cached         |
| Lambda@Edge   | 1M requests/month        | $0.60 per 1M requests    | Only runs on cache misses       |
| CloudWatch    | 5GB logs/month           | $0.50 per GB             | Minimal logging                 |
| **Total**     | **$0/month** (typical)   | **~$0.15 per 1M requests** | 95%+ cost reduction vs API Gateway |

**Example**: 10M requests/month with 90% cache hit rate:
- CloudFront: $85 (10M requests)
- Lambda@Edge: $0.60 (1M cache misses)
- **Total**: ~$85/month (vs ~$350/month with API Gateway)

## Performance

- **Cache hit**: ~10-30ms (served from CloudFront edge)
- **Cache miss cold start**: ~200-300ms
- **Cache miss warm**: ~30-50ms
- **Memory usage**: ~40MB
- **Cache duration**: 6 hours
- **Edge locations**: Global (CloudFront network)

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Built with ❤️ using Node.js and AWS**
