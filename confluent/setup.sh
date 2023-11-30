#!/bin/bash

sleep_time=2
current_dir=$(pwd)
parent_dir=$(dirname "$current_dir")

env_file="${parent_dir}/.env"
resources_file="${parent_dir}/resources.json"

# Use confluent environment
confluent login --save
export CCLOUD_ENV_ID=$(confluent environment list -o json \
    | jq -r '.[] | select(.name | contains('\"${CCLOUD_ENV_NAME:-Demo_Change_Data_Capture}\"')) | .id')

confluent env use $CCLOUD_ENV_ID

# Use kafka cluster
export CCLOUD_CLUSTER_ID=$(confluent kafka cluster list -o json \
    | jq -r '.[] | select(.name | contains('\"${CCLOUD_CLUSTER_NAME:-demo_kafka_cluster}\"')) | .id')

confluent kafka cluster use $CCLOUD_CLUSTER_ID

# Get cluster bootstrap endpoint
export CCLOUD_BOOTSTRAP_ENDPOINT=$(confluent kafka cluster describe -o json | jq -r .endpoint)
STRIPPED_CCLOUD_BOOTSTRAP_ENDPOINT=$(echo $CCLOUD_BOOTSTRAP_ENDPOINT | sed 's/SASL_SSL:\/\///')

# use sed to replace kafka-cluster-endpoint with the replacement string
sed -i .bak "s/kafka-cluster-endpoint/$STRIPPED_CCLOUD_BOOTSTRAP_ENDPOINT/g" "$env_file"
echo "Added Kafka cluster endpoint to $env_file"
sleep $sleep_time

# Create an API key pair to use for connectors
echo "Creating Kafka cluster API key"
CREDENTIALS=$(confluent api-key create --resource $CCLOUD_CLUSTER_ID --description "demo-change-data-capture" -o json)
kafka_api_key=$(echo $CREDENTIALS | jq -r '.api_key')
kafka_api_secret=$(echo $CREDENTIALS | jq -r '.api_secret')
sleep $sleep_time

# use sed to replace all instances of $kafka_api_key with the replacement string
sed -i .bak "s^api-key^\"$kafka_api_key\"^g" "$env_file"
sed -i .bak "s^api-secret^\"$kafka_api_secret\"^g" "$env_file" 
echo "Added Kafka API key and secret to $env_file"

sleep $sleep_time

# Get schema registry info
export CCLOUD_SCHEMA_REGISTRY_ID=$(confluent sr cluster describe -o json | jq -r .cluster_id)
export CCLOUD_SCHEMA_REGISTRY_ENDPOINT=$(confluent sr cluster describe -o json | jq -r .endpoint_url)

echo ""
echo "Creating schema registry API key"
SR_CREDENTIALS=$(confluent api-key create --resource $CCLOUD_SCHEMA_REGISTRY_ID --description "demo-change-data-capture" -o json)
sr_api_key=$(echo $SR_CREDENTIALS | jq -r '.api_key')
sr_api_secret=$(echo $SR_CREDENTIALS | jq -r '.api_secret')
sleep $sleep_time

# use sed to replace all instances of $sr_api_key and $sr_api_secret with the replacement string
sed -i .bak "s^sr-key^\"$sr_api_key\"^g" "$env_file" 
sed -i .bak "s^sr-secret^\"$sr_api_secret\"^g" "$env_file"
sed -i .bak "s^sr-cluster-endpoint^$CCLOUD_SCHEMA_REGISTRY_ENDPOINT^g" "$env_file"
sleep $sleep_time

# source the $env_file file
source "$env_file"

# Create tags for topics
echo ""
echo "Creating tags"
curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "PII","description" : "Personally Identifiable Information."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

echo ""
echo "Creating tags"
curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "Private","description" : "Private data that are not to be made public."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

echo ""
echo "Creating tags"
curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "Sensitive","description" : "Confidential information that must be kept safe and out of reach from all outsiders unless they have permission to access it."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "DataProduct","description" : "Enriched customer data."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "RAW","description" : "Real-time raw data streamed from a data source."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data '[ { "entityTypes" : [ "cf_entity" ],"name" : "DLQ","description" : "Dead letter queue for sink connector."} ]' \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .

# Create business metadata for topics
echo ""
echo "Creating business metadata"
curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET  -X POST -H "Content-Type: application/json" \
--data @team.txt "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/businessmetadatadefs" | jq .

# Read values from resources.json and update the $env_file file.
# These resources are created by Terraform
json=$(cat "$resources_file")

oracle_endpoint=$(echo "$json" | jq -r '.oracle_endpoint.value.address')
postgres_products=$(echo "$json" | jq -r '.postgres_instance_products_public_endpoint.value')

raw_snowflake_svc_private_key=$(echo "$json" | jq -r '.snowflake_svc_private_key.value')
snowflake_svc_private_key=$(echo "$raw_snowflake_svc_private_key" | sed '/-----BEGIN RSA PRIVATE KEY-----/d; /-----END RSA PRIVATE KEY-----/d' | tr -d '\n')

redshift_endpoint=$(echo "$json" | jq -r '.redshift_endpoint.value')
redshift_address=$(echo $redshift_endpoint | sed 's/:5439//')

# Updating the $env_file file with sed command
sed -i .bak "s^oracle-endpoint^$oracle_endpoint^g" "$env_file" 
sed -i .bak "s^postgres-products^$postgres_products^g" "$env_file" 
sed -i .bak "s^snowflake-private-key^\"$snowflake_svc_private_key\"^g" "$env_file" 
sed -i .bak "s^redshift-address^$redshift_address^g" "$env_file" 

echo "Added Oracle endpoint to $env_file"
echo "Added PostgreSQL endpoint to $env_file"
echo "Added Snowflake private key to $env_file"
echo "Added Amazon Redshift address to $env_file"
