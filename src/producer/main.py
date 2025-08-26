import os
import boto3
import json
from kafka import KafkaProducer
from fastavro import writer, parse_schema
from io import BytesIO
import urllib.parse

# MSK Bootstrap Servers are passed as environment variables
BOOTSTRAP_SERVERS = os.environ['BOOTSTRAP_SERVERS']
TOPIC_NAME = os.environ['TOPIC_NAME']

s3 = boto3.client('s3')

# Define Avro schema
schema = {
    'doc': 'S3 file information',
    'name': 'S3File',
    'namespace': 'kfk.tf',
    'type': 'record',
    'fields': [
        {'name': 'bucket', 'type': 'string'},
        {'name': 'key', 'type': 'string'},
        {'name': 'last_modified', 'type': 'string'},
        {'name': 'content', 'type': 'bytes'},
    ],
}
parsed_schema = parse_schema(schema)

def get_kafka_producer():
    # When using IAM authentication, KafkaProducer handles credentials automatically
    # from the Lambda execution environment.
    return KafkaProducer(
        bootstrap_servers=BOOTSTRAP_SERVERS,
        security_protocol='SASL_SSL',
        sasl_mechanism='AWS_MSK_IAM',
    )

def serialize_avro(data):
    bytes_writer = BytesIO()
    writer(bytes_writer, parsed_schema, [data])
    return bytes_writer.getvalue()

def handler(event, context):
    print("Received event:", json.dumps(event))

    # Get the object from the event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')

    try:
        # Get file from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read()
        last_modified = response['LastModified'].isoformat()

        # Prepare data for Avro serialization
        data_to_serialize = {
            'bucket': bucket,
            'key': key,
            'last_modified': last_modified,
            'content': content,
        }

        # Serialize data
        avro_message = serialize_avro(data_to_serialize)

        # Send message to MSK
        producer = get_kafka_producer()
        producer.send(TOPIC_NAME, value=avro_message)
        producer.flush()
        print(f"Successfully sent message for s3://{bucket}/{key} to topic {TOPIC_NAME}")
        return {'status': 'success'}

    except Exception as e:
        print(f"Error processing file s3://{bucket}/{key}")
        print(e)
        raise e
    finally:
        if 'producer' in locals() and producer:
            producer.close()
