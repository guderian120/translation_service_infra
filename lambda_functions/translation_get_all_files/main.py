import json
import boto3
import os
import traceback
from datetime import datetime, timedelta

# Initialize the S3 client
s3 = boto3.client('s3')

BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    """
    AWS Lambda function handler for retrieving CSV files from S3.
    
    This function:
    - Handles CORS preflight OPTIONS requests
    - Lists CSV objects from the specified S3 bucket
    - Optionally filters by last modified time
    - Returns the CSV file metadata in a JSON response
    - Includes comprehensive error handling
    
    Args:
        event (dict): AWS Lambda event object containing request data
        context (object): AWS Lambda context object with runtime information
        
    Returns:
        dict: Response object with status code, headers, and body
    """
    
    # CORS headers configuration
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Methods": "GET, OPTIONS"
    }

    # Handle CORS preflight OPTIONS request
    if event.get("httpMethod") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"message": "CORS preflight OK"})
        }

    try:
        # Parse query parameters if provided
        query_params = event.get('queryStringParameters', {})
        
        # Calculate time threshold if 'hours' parameter is provided
        hours_threshold = int(query_params.get('hours', 0))
        time_threshold = datetime.now() - timedelta(hours=hours_threshold) if hours_threshold else None
        
        print(f"Listing CSV files from bucket: {BUCKET_NAME}")
        if time_threshold:
            print(f"Filtering files modified in last {hours_threshold} hours")
        
        # List objects in the S3 bucket
        response = s3.list_objects_v2(
            Bucket=BUCKET_NAME,
            MaxKeys=100  # Increase limit for CSV files
        )
        
        # Process the files
        csv_files = []
        for obj in response.get('Contents', []):
            # Filter for CSV files
            if not obj['Key'].lower().endswith('.csv'):
                continue
                
            # Apply time filter if requested
            if time_threshold and obj['LastModified'].replace(tzinfo=None) < time_threshold:
                continue
                
            # Collect file metadata
            csv_files.append({
                "fileName": obj['Key'],
                "lastModified": obj['LastModified'].isoformat(),
                "size": obj['Size'],
                "storageClass": obj['StorageClass'],
                "etag": obj['ETag'].strip('"')
            })
        
        print(f"Found {len(csv_files)} CSV files matching criteria")
        
        # Successful response
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "csvFiles": csv_files,
                "count": len(csv_files),
                "bucket": BUCKET_NAME
            })
        }

    except Exception as e:
        print("Exception occurred:")
        traceback.print_exc()
        
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({
                "error": "Failed to load CSV files",
                "details": str(e)
            })
        }