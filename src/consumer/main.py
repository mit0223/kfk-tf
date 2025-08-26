import os
import base64
from fastavro import reader
from io import BytesIO
import boto3
import json

OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
s3 = boto3.client('s3')

def handler(event, context):
    print("Received event:", json.dumps(event))

    for topic, records in event['records'].items():
        for record in records:
            # Kafka message value is base64 encoded by the Lambda event source mapping
            message_bytes_b64 = record['value']
            message_bytes = base64.b64decode(message_bytes_b64)
            
            bytes_reader = BytesIO(message_bytes)
            
            # Deserialize Avro message
            for data in reader(bytes_reader):
                print("Deserialized data for key:", data['key'])
                
                file_content = data['content']
                # Use the original file key for the output object
                output_key = data['key']
                
                try:
                    # Put the file content into the output S3 bucket
                    s3.put_object(Bucket=OUTPUT_BUCKET, Key=output_key, Body=file_content)
                    print(f"Successfully wrote s3://{OUTPUT_BUCKET}/{output_key}")
                except Exception as e:
                    print(f"Error writing to S3: {e}")
                    raise e

    return {'status': 'success'}
