/**
 * Lambda handler for days-until API
 * Calculates the number of days from today to a target date
 * Returns badge-style JSON format
 */

export const handler = async (event) => {
  // Set CORS headers
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  // Handle OPTIONS preflight request
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: '',
    };
  }

  try {
    // Extract date from path: /v1/days-until/yyyy-mm-dd
    const pathMatch = event.path.match(/\/v1\/days-until\/(\d{4}-\d{2}-\d{2})/);
    
    if (!pathMatch) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Invalid path format. Expected: /v1/days-until/yyyy-mm-dd',
        }),
      };
    }

    const targetDateStr = pathMatch[1];
    
    // Parse the target date
    const targetDate = new Date(targetDateStr + 'T00:00:00Z');
    
    // Validate date
    if (Number.isNaN(targetDate.getTime())) {
      return {
        statusCode: 400,
        headers,
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
    const label = event.queryStringParameters?.label || 'Days Remaining';
    const color = event.queryStringParameters?.color || 
                  event.queryStringParameters?.colour || 
                  'blue';

    // Build badge-style response
    const response = {
      schemaVersion: 1,
      label: label,
      message: `${diffDays} days`,
      color: color,
    };

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify(response),
    };

  } catch (error) {
    console.error('Error processing request:', error);
    
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal server error',
      }),
    };
  }
};
