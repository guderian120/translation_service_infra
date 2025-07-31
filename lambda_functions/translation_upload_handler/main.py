import boto3
import os
import json
import uuid
import base64
import csv
import io
from datetime import datetime
from botocore.exceptions import ClientError

class TranslationService:
    def __init__(self):
        self._initialize_clients()
        self._load_environment_variables()
        self.api_keys_table = self.dynamodb.Table('ApiKeyMetadata') 
        
    def _initialize_clients(self):
        """Initialize AWS clients with error handling"""
        try:
            self.s3 = boto3.client('s3')
            self.sqs = boto3.client('sqs')
            self.dynamodb = boto3.resource('dynamodb')
            self.translate = boto3.client('translate')
        except Exception as e:
            raise RuntimeError(f"Client initialization failed: {str(e)}")
    
    def _load_environment_variables(self):
        """Load required environment variables"""
        try:
            self.metadata_table = os.environ['METADATA_TABLE']
            self.sqs_queue_url = os.environ['SQS_QUEUE_URL']
            self.input_bucket = os.environ['INPUT_BUCKET']
            self.output_bucket = os.environ['OUTPUT_BUCKET']
            self.source_lang = os.environ.get('SOURCE_LANG', 'auto')
            self.target_lang = os.environ.get('TARGET_LANG', 'es')
            
            self.table = self.dynamodb.Table(self.metadata_table)
        except KeyError as e:
            raise RuntimeError(f"Missing environment variable: {str(e)}")

    def _get_user_from_api_key(self, api_key):
        """Query the ApiKeyIndex GSI correctly"""
        try:
            if not api_key:
                print("Empty API key received")
                return {}

            response = self.api_keys_table.query(
                IndexName='ApiKeyIndex',
                KeyConditionExpression='api_key = :api_key',
                ExpressionAttributeValues={
                    ':api_key': api_key
                },
                Limit=1
            )
            
            print(f"Query response: {response}")  # Debug output
            
            if not response.get('Items'):
                print(f"No user found for API key: {api_key}")
                return {}
                
            user_data = response['Items'][0]
            
            # Verify required fields
            if not all(k in user_data for k in ['user_id', 'user_email']):
                print(f"Malformed user data: {user_data}")
                return {}
                
            return user_data
            
        except ClientError as e:
            print(f"DynamoDB error: {e.response['Error']['Message']}")
            return {}
    def handle_event(self, event, context):
        """Main entry point for Lambda function"""
        try:
            print("Raw event:", json.dumps(event, indent=2))
            
            if 'requestContext' in event:
                return self._handle_api_request(event)
            elif 'Records' in event:
                return self._handle_s3_sqs_event(event)
            else:
                return self._create_response(400, {'error': 'Unsupported event type'})
                
        except Exception as e:
            print(f"Top-level error: {str(e)}")
            return self._create_response(500, {'error': str(e)})

    def _handle_api_request(self, event):
        """Handle API Gateway requests with API key authentication"""
        try:
            # Extract API key from headers
            api_key = event.get('headers', {}).get('x-api-key') or event.get('headers', {}).get('X-API-Key')
            
            if not api_key:
                return self._create_response(401, {'error': 'API key is required'})
            
            # Get user info from DynamoDB using API key
            user_info = self._get_user_from_api_key(api_key)
            if not user_info:
                return self._create_response(403, {'error': 'Invalid API key'})
            
            user_id = user_info.get('user_id')
            user_email = user_info.get('user_email')
            
            if not user_id or not user_email:
                return self._create_response(403, {'error': 'API key not associated with valid user'})

            content_type = event.get('headers', {}).get('Content-Type', '').lower()
            content_length = int(event.get('headers', {}).get('content-length', '0'))
            MAX_SIZE = 102400
            
            if content_length > MAX_SIZE:
                return self._create_response(413, {
                    'error': f'Payload size exceeds limit of {MAX_SIZE} bytes',
                    'max_size': MAX_SIZE,
                    'received_size': content_length
                })

            if not event.get('body'):
                return self._create_response(400, {'error': 'Request body is empty'})

            # Try to detect CSV content regardless of Content-Type
            file_content = self._extract_file_content(event)
            
            # First try to parse as CSV
            try:
                sample_lines = file_content.split('\n')[:3]
                csv.Sniffer().sniff('\n'.join(sample_lines))
                result = self.process_csv_content(file_content, user_id, user_email)
                return self._create_response(200, result)
            except csv.Error:
                # Not CSV, try JSON
                try:
                    if 'application/json' in content_type:
                        body = json.loads(file_content)
                        if 'file_key' in body:
                            result = self.process_file_upload(
                                self.input_bucket, body['file_key'], user_id, user_email
                            )
                        elif 'text' in body:
                            translated_text = self.translate_text(
                                body['text'],
                                body.get('source_lang', self.source_lang),
                                body.get('target_lang', self.target_lang)
                            )
                            result = {'translatedText': translated_text, 'status': 'COMPLETED'}
                        else:
                            return self._create_response(400, {'error': 'Invalid JSON structure'})
                        return self._create_response(200, result)
                except json.JSONDecodeError:
                    pass

            return self._create_response(400, {
                'error': 'Could not determine content type. Please specify valid Content-Type header',
                'suggested_types': ['text/csv', 'application/json']
            })

        except Exception as e:
            print(f"API request error: {str(e)}")
            return self._create_response(500, {'error': str(e)})
    def _get_user_info_from_tags(self, bucket, key):
            """Extract user information from S3 object tags"""
            try:
                response = self.s3.get_object_tagging(
                    Bucket=bucket,
                    Key=key
                )
                tags = {t['Key']: t['Value'] for t in response.get('TagSet', [])}
                
                user_email = tags.get('user_email')
                user_id = tags.get('user_id')
                
                if not user_email or not user_id:
                    print(f"Missing user tags in object {bucket}/{key}")
                    return 'system@s3_upload.com', 'SYSTEM_UPLOAD'
                    
                return user_email, user_id
                
            except ClientError as e:
                print(f"Error getting tags: {str(e)}")
                return 'system@s3_upload.com', 'SYSTEM_UPLOAD'
    def _handle_s3_sqs_event(self, event):
        """Handle events from S3 or SQS with proper user email extraction"""
        results = []
        for record in event['Records']:
            try:
                if 's3' in record:
                    bucket = record['s3']['bucket']['name']
                    key = record['s3']['object']['key']
                    
                    # Try to get user info from S3 object metadata
                    try:
                        user_email, user_id = self._get_user_info_from_tags(bucket, key)
                        print(f"Processing file for user: {user_email} (ID: {user_id})")
                        metadata = self.s3.head_object(
                            Bucket=bucket,
                            Key=key
                        )['Metadata']
                     
                        if not user_email or not user_id:
                            # Fall back to extracting from API key if available
                            api_key = metadata.get('x-amz-meta-api-key')
                            if api_key:
                                user_info = self._get_user_from_api_key(api_key)
                                user_email = user_info.get('user_email')
                                user_id = user_info.get('user_id')
                    except ClientError as e:
                        print(f"Error getting object metadata: {str(e)}")
                        user_email = None
                        user_id = None
                    
                    # If we still don't have user info, use SYSTEM as fallback
                    if not user_email or not user_id:
                        user_email = 'system@s3_upload.com'
                        user_id = 'SYSTEM_UPLOAD'
                    
                    result = self.process_file_upload(
                        bucket, key, user_id, user_email
                    )
                    
                elif 'body' in record:
                    message = json.loads(record['body'])
                    result = self._process_sqs_message(message)
                else:
                    continue
                    
                results.append(result)
            except Exception as e:
                print(f"Error processing record: {str(e)}")
                continue

        return self._create_response(200, {
            'message': 'Event processed',
            'processed_count': len(results),
            'results': results
        })

    def process_file_upload(self, bucket, key, user_id, user_email):
        """Handle file upload process with proper user email"""
        file_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        
        try:
            # Create DynamoDB record with actual user email
            self._create_dynamo_record(file_id, user_id, user_email, timestamp, key, bucket)
            self._send_sqs_message(bucket, key, file_id)
            
            return {
                'file_id': file_id,
                'status': 'QUEUED',
                'user_email': user_email  # Include email in response for tracking
            }
            
        except Exception as e:
            print(f"File upload error: {str(e)}")
            raise   

    def _process_sqs_message(self, message):
        """Process message from SQS queue"""
        result = self.process_csv_file(message['bucket'], message['key'])
        
        self.table.update_item(
            Key={'file_id': message['file_id']},
            UpdateExpression='SET #status = :status, translated_file = :translated_file',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': result['status'],
                ':translated_file': result.get('translated_file')
            }
        )
        
        return result

  

    def process_csv_content(self, csv_content, user_id, user_email):
        """Process CSV content from request body"""
        print("processing csv")
        file_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        print("got file id", file_id)
        try:
            translated_rows, output_content = self._translate_csv_content(csv_content)
            output_key = f"translated_{timestamp}_direct_upload.csv"
            
            self.s3.put_object(
                Bucket=self.output_bucket,
                Key=output_key,
                Body=output_content.encode('utf-8'),
                ContentType='text/csv'
            )
            
            self.table.put_item(
                Item={
                    'file_id': file_id,
                    'user_id': user_id,
                    'email': user_email,
                    'timestamp': timestamp,
                    'status': 'COMPLETED',
                    'original_file': 'direct_upload',
                    'translated_file': f"s3://{self.output_bucket}/{output_key}",
                    'bucket': self.output_bucket
                }
            )
            
            return {
                'status': 'COMPLETED',
                'file_id': file_id,
                'content': translated_rows,
                'translated_file': f"s3://{self.output_bucket}/{output_key}"
            }
            
        except Exception as e:
            print(f"CSV processing error: {str(e)}")
            raise

    def process_csv_file(self, bucket, key):
        """Process CSV file from S3"""
        try:
            content = self.s3.get_object(Bucket=bucket, Key=key)['Body'].read().decode('utf-8')
            translated_rows, output_content = self._translate_csv_content(content)
            
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            output_key = f"translated_{timestamp}_{os.path.basename(key)}"
            
            self.s3.put_object(
                Bucket=self.output_bucket,
                Key=output_key,
                Body=output_content.encode('utf-8'),
                ContentType='text/csv'
            )
            
            return {
                'status': 'COMPLETED',
                'content': translated_rows,
                'original_file': f"s3://{bucket}/{key}",
                'translated_file': f"s3://{self.output_bucket}/{output_key}",
                'source_lang': self.source_lang,
                'target_lang': self.target_lang
            }
            
        except Exception as e:
            print(f"File processing error: {str(e)}")
            return {'status': 'FAILED', 'error': str(e)}

    def translate_text(self, text, source_lang, target_lang):
        """Translate text using AWS Translate"""
        try:
            response = self.translate.translate_text(
                Text=text,
                SourceLanguageCode=source_lang,
                TargetLanguageCode=target_lang
            )
            return response['TranslatedText']
        except Exception as e:
            print(f"Translation error: {str(e)}")
            return text

    def _translate_csv_content(self, csv_content):
        """Translate CSV content and return rows and output string"""
        try:
            # Ensure we have proper line endings
            csv_content = csv_content.replace('\r\n', '\n').replace('\r', '\n')
            
            # Try to detect dialect
            sample = '\n'.join(csv_content.split('\n')[:5])  # Get first 5 lines for sniffing
            dialect = csv.Sniffer().sniff(sample)
            
            csv_reader = csv.reader(io.StringIO(csv_content), dialect)
            output = io.StringIO()
            csv_writer = csv.writer(output, dialect)
            
            translated_rows = []
            for row in csv_reader:
                translated_row = []
                for cell in row:
                    if not cell.strip():
                        translated_row.append(cell)
                        continue
                        
                    translated_row.append(
                        self.translate_text(cell, self.source_lang, self.target_lang)
                    )
                
                csv_writer.writerow(translated_row)
                translated_rows.append(translated_row)
                
            return translated_rows, output.getvalue()
        except Exception as e:
            print(f"CSV parsing error: {str(e)}")
            raise ValueError(f"Invalid CSV format: {str(e)}")

    def _create_dynamo_record(self, file_id, user_id, user_email, timestamp, key, bucket):
        """Create record in DynamoDB"""
        try:
            self.table.put_item(
                Item={
                    'file_id': file_id,
                    'user_id': user_id,
                    'email': user_email,
                    'timestamp': timestamp,
                    'status': 'QUEUED',
                    'original_file': key,
                    'translated_file': None,
                    'bucket': bucket
                },
                ConditionExpression='attribute_not_exists(file_id)'
            )
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                print(f"File ID {file_id} already exists, retrying...")
                self.table.put_item(
                    Item={
                        'file_id': file_id,
                        'user_id': user_id,
                        'email': user_email,
                        'timestamp': timestamp,
                        'status': 'QUEUED',
                        'original_file': key,
                        'translated_file': None,
                        'bucket': bucket
                    }
                )
            else:
                raise

    def _send_sqs_message(self, bucket, key, file_id):
        """Send message to SQS queue"""
        message = {
            'bucket': bucket,
            'key': key,
            'file_id': file_id
        }
        
        try:
            response = self.sqs.send_message(
                QueueUrl=self.sqs_queue_url,
                MessageBody=json.dumps(message)
            )
            print(f"Message sent to SQS: {response['MessageId']}")
        except Exception as e:
            self.table.update_item(
                Key={'file_id': file_id},
                UpdateExpression='SET #status = :status',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={':status': 'FAILED'}
            )
            raise

    def _parse_json_body(self, event):
        """Parse JSON body with error handling"""
        try:
            return json.loads(event.get('body', '{}'))
        except json.JSONDecodeError:
            raise ValueError('Invalid JSON format')

    def _extract_file_content(self, event):
        """Extract file content from event, handling base64 if needed"""
        content = event['body']
        if event.get('isBase64Encoded', False):
            content = base64.b64decode(content).decode('utf-8')
        return content

    def _create_response(self, status_code, body):
        """Create standardized API Gateway response"""
        return {
            'statusCode': status_code,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(body)
        }

# Lambda handler function
def lambda_handler(event, context):
    service = TranslationService()
    return service.handle_event(event, context)