import boto3
import random
import os
import json
import string
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
apigateway = boto3.client('apigateway')

# Configuration
API_KEY_TABLE_NAME = os.environ['API_METADATA_TABLE']
API_GATEWAY_ID = os.environ['API_GATEWAY_ID']  
STAGE_NAME = os.environ['STAGE_NAME']  
API_KEY_PREFIX_LENGTH = 8  
API_KEY_LENGTH = 40
DEFAULT_EXPIRATION_DAYS = 365

# Rate limiting configuration
THROTTLE_RATE_LIMIT = 10  # Requests per second
THROTTLE_BURST_LIMIT = 50  # Burst capacity
QUOTA_LIMIT = 100  # Requests per day
QUOTA_PERIOD = 'DAY'

def generate_api_key(email):
    """Generate API key with email prefix"""
    email_prefix = email.split('@')[0][:API_KEY_PREFIX_LENGTH].lower()
    random_part = ''.join(random.choices(string.ascii_letters + string.digits, 
                                     k=API_KEY_LENGTH - len(email_prefix)))
    return f"{email_prefix}_{random_part}"

def ensure_usage_plan():
    """Create or get usage plan with strict limits"""
    plan_name = f"StrictPlan-{API_GATEWAY_ID}-{STAGE_NAME}"
    
    # Check if plan exists
    existing_plans = apigateway.get_usage_plans().get('items', [])
    for plan in existing_plans:
        if plan['name'] == plan_name:
            return plan['id']
    
    # Create new strict usage plan
    response = apigateway.create_usage_plan(
        name=plan_name,
        description="Strictly limited usage plan",
        apiStages=[{
            'apiId': API_GATEWAY_ID,
            'stage': STAGE_NAME
        }],
        throttle={
            'burstLimit': THROTTLE_BURST_LIMIT,
            'rateLimit': THROTTLE_RATE_LIMIT
        },
        quota={
            'limit': QUOTA_LIMIT,
            'period': QUOTA_PERIOD
        },
        tags={
            'auto-generated': 'true',
            'strict-limits': 'true'
        }
    )
    return response['id']

def build_response(status_code, body):
    """Build properly formatted API Gateway response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'POST,GET,OPTIONS'
        },
        'body': json.dumps(body) if isinstance(body, dict) else body
    }

def lambda_handler(event, context):
    # Initialize DynamoDB table
    table = dynamodb.Table(API_KEY_TABLE_NAME)

    # Extract user info from API Gateway request context
    try:
        claims = event['requestContext']['authorizer']['claims']
        user_id = claims['sub']
        user_email = claims['email']
    except KeyError as e:
        return build_response(400, {'error': f'Missing user information: {str(e)}'})

    # Check for existing key
    response = table.get_item(Key={'user_id': user_id})
    if 'Item' in response:
        return build_response(200, {
            'message': 'Existing API key found',
            'api_key': response['Item']['api_key'],
            'limits': {
                'rate_limit': THROTTLE_RATE_LIMIT,
                'burst_limit': THROTTLE_BURST_LIMIT,
                'daily_quota': QUOTA_LIMIT
            },
            'user_email': user_email
        })

    try:
        # Generate new API key
        api_key_value = generate_api_key(user_email)
        
        # Create or get strict usage plan
        usage_plan_id = ensure_usage_plan()
        
        # Create API key
        api_response = apigateway.create_api_key(
            name=f"strict-key-for-{user_email}",
            description=f"Strictly limited API key for {user_email}",
            enabled=True,
            value=api_key_value,
            tags={
                'user_email': user_email,
                'user_id': user_id,
                'strict_limits': 'true'
            }
        )
        key_id = api_response['id']
        
        # Attach key to usage plan
        apigateway.create_usage_plan_key(
            usagePlanId=usage_plan_id,
            keyId=key_id,
            keyType='API_KEY'
        )
        
        # Store metadata
        expires_at = (datetime.now() + timedelta(days=DEFAULT_EXPIRATION_DAYS)).isoformat()
        table.put_item(
            Item={
                'user_id': user_id,
                'user_email': user_email,
                'api_key': api_key_value,
                'api_key_id': key_id,
                'usage_plan_id': usage_plan_id,
                'limits': {
                    'rate_limit': THROTTLE_RATE_LIMIT,
                    'burst_limit': THROTTLE_BURST_LIMIT,
                    'daily_quota': QUOTA_LIMIT
                },
                'created_at': datetime.now().isoformat(),
                'expires_at': expires_at,
                'is_active': True
            }
        )

        return build_response(201, {
            'message': 'New strictly limited API key generated',
            'api_key': api_key_value,
            'limits': {
                'rate_limit': THROTTLE_RATE_LIMIT,
                'burst_limit': THROTTLE_BURST_LIMIT,
                'daily_quota': QUOTA_LIMIT
            },
            'expires_at': expires_at,
            'user_email': user_email
        })

    except Exception as e:
        return build_response(500, {'error': f'Error generating API key: {str(e)}'})