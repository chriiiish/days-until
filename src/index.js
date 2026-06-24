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

  const MS_PER_DAY = 1000 * 60 * 60 * 24;

  const parseDateString = (dateStr) => {
    const match = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) {
      return null;
    }

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const date = new Date(Date.UTC(year, month - 1, day));

    if (
      date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day
    ) {
      return null;
    }

    return { year, month, day };
  };

  const toEpochDay = ({ year, month, day }) => {
    return Math.floor(Date.UTC(year, month - 1, day) / MS_PER_DAY);
  };

  const isValidTimezone = (timezone) => {
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: timezone }).format(new Date());
      return true;
    } catch {
      return false;
    }
  };

  const getTodayInTimezone = (timezone) => {
    const now = new Date();
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });

    const parts = formatter.formatToParts(now);
    const year = Number(parts.find((part) => part.type === 'year').value);
    const month = Number(parts.find((part) => part.type === 'month').value);
    const day = Number(parts.find((part) => part.type === 'day').value);

    return { year, month, day };
  };

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
    // Extract date and optional timezone from path: /v1/yyyy-mm-dd[/timezone]
    const pathMatch = uri.match(/^\/v1\/(\d{4}-\d{2}-\d{2})(?:\/([A-Za-z0-9_+\-/]+))?\/?$/);
    
    if (!pathMatch) {
      return {
        status: '400',
        statusDescription: 'Bad Request',
        headers: {
          'content-type': [{ key: 'Content-Type', value: 'application/json' }],
          'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        },
        body: JSON.stringify({
          error: 'Invalid path format. Expected: /v1/yyyy-mm-dd or /v1/yyyy-mm-dd/timezone',
        }),
      };
    }

    const targetDateStr = pathMatch[1];
    const timezoneSegment = pathMatch[2];
    const timezone = timezoneSegment || 'UTC';

    if (!isValidTimezone(timezone)) {
      return {
        status: '400',
        statusDescription: 'Bad Request',
        headers: {
          'content-type': [{ key: 'Content-Type', value: 'application/json' }],
          'access-control-allow-origin': [{ key: 'Access-Control-Allow-Origin', value: '*' }],
        },
        body: JSON.stringify({
          error: 'Invalid timezone. Use a valid IANA timezone (e.g. Pacific/Auckland)',
        }),
      };
    }
    
    // Parse and validate target date strictly
    const targetDate = parseDateString(targetDateStr);
    
    // Validate date
    if (!targetDate) {
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

    // Calculate days until target date based on selected timezone's current date
    const today = getTodayInTimezone(timezone);
    const diffDays = toEpochDay(targetDate) - toEpochDay(today);

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
