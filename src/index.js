/**
 * Lambda@Edge handler for days-until API
 * Calculates the number of days from today to a target date
 * Returns badge-style JSON format
 * Triggered on CloudFront origin-request (cache miss)
 * 
 * NOTE: This code is embedded in infrastructure/template.yaml
 * This file is kept for reference and local testing only.
 * Any changes must be manually copied to the CloudFormation template.
 */

export const handler = async (event) => {
  const request = event.Records[0].cf.request;
  const uri = request.uri;
  const querystring = request.querystring;

  // Parse query parameters
  const params = new URLSearchParams(querystring);
  
  // Handle OPTIONS preflight request
  if (request.method === 'OPTIONS') {
    return {
      status: '200',
      statusDescription: 'OK',
      headers: {
        'content-type': [{ key: 'Content-Type', value: 'application/json' }],
        'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        'access-control-allow-methods': [{ key: 'Access-Control-Allow-Methods', value: 'GET, OPTIONS' }],
        'access-control-allow-headers': [{ key: 'Access-Control-Allow-Headers', value: 'Content-Type' }],
        'cache-control': [{ key: 'Cache-Control', value: 'public, max-age=21600' }],
      },
      body: '',
    };
  }

  try {
    // Extract date from path: /v1/yyyy-mm-dd
    const pathMatch = uri.match(/\/v1\/(\d{4}-\d{2}-\d{2})/);
    
    if (!pathMatch) {
      return {
        status: '400',
        statusDescription: 'Bad Request',
        headers: {
          'content-type': [{ key: 'Content-Type', value: 'application/json' }],
          'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        },
        body: JSON.stringify({
          error: 'Invalid path format. Expected: /v1/yyyy-mm-dd',
        }),
      };
    }

    const targetDateStr = pathMatch[1];
    
    // Parse the target date
    const targetDate = new Date(targetDateStr + 'T00:00:00Z');
    
    // Validate date
    if (Number.isNaN(targetDate.getTime())) {
      return {
        status: '400',
        statusDescription: 'Bad Request',
        headers: {
          'content-type': [{ key: 'Content-Type', value: 'application/json' }],
          'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        },
        body: JSON.stringify({
          error: 'Invalid date format. Use yyyy-mm-dd',
        }),
      };
    }

    // Calculate days until target date
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    
    const diffTime = targetDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    // Get query parameters (support both 'color' and 'colour' spellings)
    const label = params.get('label') || 'Days Remaining';
    const color = params.get('color') || params.get('colour') || 'blue';

    // Build badge-style response
    const response = {
      schemaVersion: 1,
      label: label,
      message: `${diffDays} days`,
      color: color,
    };

    return {
      status: '200',
      statusDescription: 'OK',
      headers: {
        'content-type': [{ key: 'Content-Type', value: 'application/json' }],
        'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        'cache-control': [{ key: 'Cache-Control', value: 'public, max-age=21600' }],
      },
      body: JSON.stringify(response),
    };

  } catch (error) {
    console.error('Error processing request:', error);
    
    return {
      status: '500',
      statusDescription: 'Internal Server Error',
      headers: {
        'content-type': [{ key: 'Content-Type', value: 'application/json' }],
        'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
      },
      body: JSON.stringify({
        error: 'Internal server error',
      }),
    };
  }
};
