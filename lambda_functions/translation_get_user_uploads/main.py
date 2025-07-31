import json
import boto3
import os
import traceback
from datetime import datetime, timedelta

def log_debug(message):
    """Helper function for consistent debug logging"""
    print(f"[DEBUG] {datetime.now().isoformat()} - {message}")

# Initialize clients with debugging
try:
    log_debug("Initializing AWS clients")
    dynamodb = boto3.resource('dynamodb')
    s3 = boto3.client('s3')
    log_debug("AWS clients initialized successfully")
except Exception as e:
    log_debug(f"Failed to initialize AWS clients: {str(e)}")
    raise

# Environment variables with validation
try:
    log_debug("Loading environment variables")
    TABLE_NAME = os.environ['METADATA_TABLE']
    BUCKET_NAME = os.environ['OUTPUT_BUCKET']
    log_debug(f"Loaded TABLE_NAME: {TABLE_NAME}")
    log_debug(f"Loaded BUCKET_NAME: {BUCKET_NAME}")
except KeyError as e:
    error_msg = f"Missing required environment variable: {str(e)}"
    log_debug(error_msg)
    raise RuntimeError(error_msg)
except Exception as e:
    error_msg = f"Error loading environment variables: {str(e)}"
    log_debug(error_msg)
    raise RuntimeError(error_msg)

def lambda_handler(event, context):
    # Log the incoming event (redact sensitive info if needed)
    log_debug(f"Received event: {json.dumps({k: v for k, v in event.items() if k != 'requestContext'})}")
    
    # CORS headers configuration
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Methods": "GET, OPTIONS"
    }

    # Handle CORS preflight OPTIONS request
    if event.get("httpMethod") == "OPTIONS":
        log_debug("Handling OPTIONS request")
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"message": "CORS preflight OK"})
        }

    try:
        # Safely extract email from Cognito claims
        try:
            log_debug("Extracting user email from Cognito claims")
            claims = event.get('requestContext', {}).get('authorizer', {}).get('claims', {})
            user_email = claims.get('email')
            log_debug(f"Extracted email: {user_email}")
            
            if not user_email:
                error_msg = "Email not found in Cognito claims"
                log_debug(error_msg)
                return {
                    "statusCode": 400,
                    "headers": headers,
                    "body": json.dumps({"error": error_msg})
                }
        except Exception as e:
            error_msg = f"Failed to extract user email: {str(e)}"
            log_debug(error_msg)
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Failed to extract user email", "details": str(e)})
            }

        # Safely parse query parameters
        try:
            log_debug("Parsing query parameters")
            query_params = event.get('queryStringParameters', {}) or {}
            log_debug(f"Raw query params: {query_params}")
            
            hours_threshold = int(query_params.get('hours', '0'))
            log_debug(f"Hours threshold: {hours_threshold}")
            
            time_threshold = datetime.now() - timedelta(hours=hours_threshold) if hours_threshold else None
            if time_threshold:
                log_debug(f"Filtering files modified after: {time_threshold.isoformat()}")
        except (ValueError, AttributeError) as e:
            log_debug(f"Error parsing query params, defaulting to 0 hours: {str(e)}")
            hours_threshold = 0
            time_threshold = None

        # Query DynamoDB for files by this user
        try:
            log_debug(f"Querying DynamoDB table {TABLE_NAME} for user {user_email}")
            table = dynamodb.Table(TABLE_NAME)
            response = table.query(
                IndexName='email-index',
                KeyConditionExpression='email = :email',
                ExpressionAttributeValues={':email': user_email}
            )
            log_debug(f"DynamoDB returned {len(response.get('Items', []))} items")
        except Exception as e:
            error_msg = f"DynamoDB query failed: {str(e)}"
            log_debug(error_msg)
            return {
                "statusCode": 500,
                "headers": headers,
                "body": json.dumps({"error": "DynamoDB query failed", "details": str(e)})
            }

        # Process the files
        csv_files = []
        log_debug("Processing DynamoDB items")
        for item in response.get('Items', []):
            try:
                translated_file = item.get('translated_file', '')
                log_debug(f"Processing item with translated_file: {translated_file}")
                
                # Skip non-CSV files
                if not isinstance(translated_file, str) or not translated_file.lower().endswith('.csv'):
                    log_debug("Skipping non-CSV file")
                    continue
                
                # Extract S3 key safely
                try:
                    if f's3://{BUCKET_NAME}/' in translated_file:
                        s3_key = translated_file.split(f's3://{BUCKET_NAME}/')[-1]
                    elif translated_file.startswith('s3://'):
                        s3_key = translated_file.split('s3://')[-1]
                    else:
                        s3_key = translated_file
                    
                    log_debug(f"Extracted S3 key: {s3_key}")
                    
                    # Get file metadata from S3
                    try:
                        log_debug(f"Getting S3 object metadata for {s3_key}")
                        s3_obj = s3.head_object(Bucket=BUCKET_NAME, Key=s3_key)
                        
                        # Apply time filter if requested
                        if time_threshold and s3_obj['LastModified'].replace(tzinfo=None) < time_threshold:
                            log_debug("File filtered out by time threshold")
                            continue
                        
                        # Format response
                        file_data = {
                            "fileName": s3_key,
                            "lastModified": s3_obj['LastModified'].isoformat(),
                            "size": s3_obj['ContentLength'],
                            "storageClass": s3_obj.get('StorageClass', 'STANDARD'),
                            "etag": s3_obj['ETag'].strip('"')
                        }
                        csv_files.append(file_data)
                        log_debug(f"Added file to response: {json.dumps(file_data)}")
                        
                    except s3.exceptions.ClientError as e:
                        if e.response['Error']['Code'] != '404':
                            log_debug(f"Error accessing S3 object {s3_key}: {str(e)}")
                        continue
                except Exception as e:
                    log_debug(f"Error processing file {translated_file}: {str(e)}")
                    continue
            except Exception as e:
                log_debug(f"Unexpected error processing item: {str(e)}")
                continue
        
        log_debug(f"Returning {len(csv_files)} CSV files")
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
        error_msg = f"Unhandled exception: {str(e)}"
        log_debug(error_msg)
        traceback.print_exc()
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({
                "error": "Internal server error",
                "details": error_msg
            })
        }