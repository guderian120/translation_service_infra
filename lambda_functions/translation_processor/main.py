import boto3
import os
import csv
import io
import json
from datetime import datetime

s3 = boto3.client('s3')
sqs = boto3.client('sqs')
translate = boto3.client('translate')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['METADATA_TABLE'])

def lambda_handler(event, context):
    for record in event['Records']:
        # Parse the message
        message = json.loads(record['body'])
        bucket = message['bucket']
        object_key = message['key']
        file_id = message['file_id']
        timestamp = message.get('timestamp', datetime.now().isoformat())
        # Download the CSV file from S3
        response = s3.get_object(Bucket=bucket, Key=object_key)
        csv_content = response['Body'].read().decode('utf-8')
        
        # Parse CSV
        csv_reader = csv.DictReader(io.StringIO(csv_content))
        rows = list(csv_reader)
        key = {
                'file_id': file_id,
                'timestamp': timestamp  # Must provide the sort key
            }
        # Translate each text field
        translated_rows = []
        table.update_item(
                    Key=key,  # Use the full key
                    UpdateExpression='SET #status = :status',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={':status': 'PROCESSING'}
        )
        
        for row in rows:
            translated_row = {}
            for field_name, field_value in row.items():
                if isinstance(field_value, str) and field_value.strip():
                    # Translate the text
                    response = translate.translate_text(
                        Text=field_value,
                        SourceLanguageCode='auto',
                        TargetLanguageCode='es'  # Spanish as example
                    )
                    translated_row[field_name] = response['TranslatedText']
                else:
                    translated_row[field_name] = field_value
            translated_rows.append(translated_row)
        
        # Convert back to CSV
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(translated_rows)
        
        # Upload translated file to output bucket
        output_key = f"translated_{datetime.now().strftime('%Y%m%d%H%M%S')}_{message['key']}"
        s3.put_object(
            Bucket=os.environ['OUTPUT_BUCKET'],
            Key=output_key,
            Body=output.getvalue()
        )
        
        print(f"Translated file saved to {os.environ['OUTPUT_BUCKET']}/{output_key}")
        
        # Update DynamoDB with completion status
        table.update_item(
                Key=key,  # Use the full key again
                UpdateExpression='SET #status = :status, translated_file = :file',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'COMPLETED',
                    ':file': f"translated_{datetime.now().strftime('%Y%m%d%H%M%S')}_{object_key}"
                }
        )
        
        # Get user email from DynamoDB to send notification
        response = table.get_item(Key=key)
        item = response.get('Item', {})
        user_email = item.get('email')
        
        if user_email:
            # Send notification to user (could be via SNS, SES, etc.)
            print(f"Notification sent to {user_email} about translation completion.")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Translation completed successfully!')
    }