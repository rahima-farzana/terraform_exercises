import json
import os
import time
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# ==============================================================================
# CONFIGURATION & ENVIRONMENT VARIABLES
# ==============================================================================
# You can set these in your terminal environment OR fallback to the defaults below
os.environ["AWS_ACCESS_KEY_ID"] = os.getenv("AWS_ACCESS_KEY_ID", "YOUR_ACCESS_KEY_ID")
os.environ["AWS_SECRET_ACCESS_KEY"] = os.getenv("AWS_SECRET_ACCESS_KEY", "YOUR_SECRET_ACCESS_KEY")
# Optional: Required only if using AWS SSO or temporary STS credentials
if os.getenv("AWS_SESSION_TOKEN"):
    os.environ["AWS_SESSION_TOKEN"] = os.getenv("AWS_SESSION_TOKEN")

AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
os.environ["AWS_REGION"] = AWS_REGION

KAFKA_BROKER = os.getenv(
    "KAFKA_BROKER",
    "YOUR_KAKFA_SERVER"
)

# ==============================================================================
# MSK IAM TOKEN PROVIDER
# ==============================================================================
class MSKTokenProvider:
    """Generates short-lived OAuth bearer tokens signed by AWS IAM."""
    def token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token(AWS_REGION)
        return token

print(f"Connecting to MSK Cluster: {KAFKA_BROKER}")
print(f"Using AWS Region:          {AWS_REGION}")

# ==============================================================================
# PRODUCER INITIALIZATION
# ==============================================================================
tp = MSKTokenProvider()

try:
    producer = KafkaProducer(
        bootstrap_servers=[KAFKA_BROKER],
        security_protocol="SASL_SSL",
        sasl_mechanism="OAUTHBEARER",
        sasl_oauth_token_provider=tp,
        # Prevents NoBrokersAvailable error during automatic version negotiation
        api_version=(2, 8, 1),
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )
except Exception as e:
    print(f"\n❌ Failed to connect to Kafka Broker: {e}")
    print("Check your AWS Credentials, VPC Security Groups, or Broker Endpoint.")
    exit(1)

# ==============================================================================
# EVENT PUBLISHING
# ==============================================================================
print("\nSending transactions to MSK...")
topic_name = "fraud-events"

for i in range(50):
    payload = {
        "amount": 150.0 + (i * 10),
        "is_international": i % 2,
        "failed_login_attempts": i % 3,
        "velocity_1h": i + 1,
        "card_present": 1
    }
    
    # Asynchronously send payload
    producer.send(topic_name, payload)
    print(f"Sent ({i+1}/50): {payload}")
    time.sleep(0.2)

# Ensure all messages in buffer are flushed before exiting
producer.flush()
print("\n✅ Finished publishing batch successfully!")
