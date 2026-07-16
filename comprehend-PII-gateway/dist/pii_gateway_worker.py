"""
Wezva Technologies - MLOps Platform Engineering Framework
Component: Centralised Ingestion Sanitisation & Real-Time PII Gateway Worker
Author: Adam, Head of Platform
"""

import urllib.parse
import boto3
import re

s3_client = boto3.client('s3')
comprehend_client = boto3.client('comprehend')

# Define global enterprise-wide redaction tokens
REDACTION_MASKS = {
    "EMAIL": "[REDACTED_EMAIL]",
    "NAME": "[REDACTED_NAME]",
    "CREDIT_DEBIT_NUMBER": "[REDACTED_CC]",
    "PHONE": "[REDACTED_PHONE]",
    "AWS_ACCESS_KEY": "[REDACTED_KEY]"
}

def lambda_handler(event, context):
    # 1. Parse the incoming real-time S3 notification event record
    try:
        record = event['Records'][0]
        bucket_name = record['s3']['bucket']['name']
        object_key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        
        print(f"⚡ Real-Time Ingest Capture: Processing object s3://{bucket_name}/{object_key}")
    except Exception as parse_err:
        print(f"❌ Failed to parse inbound S3 Event schema: {str(parse_err)}")
        return {"statusCode": 400, "body": "Invalid event metadata wrapper"}

    # 2. Fetch the raw dataset stream from S3 into execution memory
    response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
    raw_text = response['Body'].read().decode('utf-8')

    # 3. Call Amazon Comprehend NLP API to evaluate string risk patterns
    try:
        # Scopes extraction window to stay within cloud payload constraint thresholds safely
        pii_analysis = comprehend_client.detect_pii_entities(
            Text=raw_text[:95000],  
            LanguageCode='en'
        )
        entities = pii_analysis.get('Entities', [])
    except Exception as nlp_err:
        print(f"❌ NLP Analysis Engine processing failure: {str(nlp_err)}")
        return {"statusCode": 500, "body": "Comprehend processing failed"}

    # 🎯 CRITICAL ALGORITHM TRICK: Sort entities in reverse order based on text positions.
    # Modifying strings from back-to-front prevents character shifts from corrupting remaining indices.
    entities.sort(key=lambda x: x['BeginOffset'], reverse=True)
    redacted_text = raw_text

    print(f"🔍 Analysis Matrix: Comprehend detected {len(entities)} sensitive records.")

    # 4. Map entities to masks and splice replacements into the string coordinates
    for entity in entities:
        ent_type = entity['Type']
        begin = entity['BeginOffset']
        end = entity['EndOffset']
        
        mask = REDACTION_MASKS.get(ent_type, "[REDACTED_PII]")
        redacted_text = redacted_text[:begin] + mask + redacted_text[end:]

    # 5. Overwrite the file with the sanitized text payload
    s3_client.put_object(
        Bucket=bucket_name,
        Key=object_key,
        Body=redacted_text.encode('utf-8')
    )

    print(f"✅ Success: s3://{bucket_name}/{object_key} has been sanitized by central gateway.")
    return {"statusCode": 200, "body": "Sanitisation complete"}

