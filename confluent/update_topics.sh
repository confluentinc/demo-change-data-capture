
#
# This uses the Confluent Cloud CLI and Confluent Cloud APIs
# to add tags and update business metadata to select user topics
# 
# See https://docs.confluent.io/cloud/current/api.html for more
# information
#

#!/bin/bash

sleep_time=2
current_dir=$(pwd)
parent_dir=$(dirname "$current_dir")

env_file="${parent_dir}/.env"

# Function to assign description, owner, and ownerEmail to an entity
add_details() {
    local entityType="$1"
    local qualifiedName="$2"
    local description="$3"
    local owner="$4"
    local ownerEmail="$5"

    # Add description, owner, and ownerEmail
    curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request PUT --url "${CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity" --header 'Content-Type: application/json' --data '{
        "entity": {
            "typeName": "'"$entityType"'",
            "attributes": {
                "qualifiedName": "'"$qualifiedName"'",
                "description": "'"$description"'",
                "owner": "'"$owner"'",
                "ownerEmail": "'"$ownerEmail"'"
            }
        }
    }' | jq .
}
# Function to create business metadata for an entity
add_business_metadata() {
    local entity_name="$1"
    local team_owner="$2"
    local slack_contact="$3"
    local name="$4"
    local output_file="$5"

    local text_data='[ {"entityType": "kafka_topic","entityName": "'"$entity_name"'","typeName": "Domain","attributes": {"Team_owner": "'"$team_owner"'", "Slack_contact": "'"$slack_contact"'", "Name": "'"$name"'"} } ]'
    echo "$text_data" > "$output_file"

    curl --silent -u "$CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET" \
         -X POST -H "Content-Type: application/json" \
         --data @"$output_file" \
         --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/businessmetadata" | jq .
    
    sleep "$sleep_time"
}

# source the $env_file file
source "$env_file"

# Use confluent environment
confluent login --save
export CCLOUD_ENV_ID=$(confluent environment list -o json | jq -r '.[] | select(.name | contains("'"${CCLOUD_ENV_NAME:-Demo_Change_Data_Capture}"'")) | .id')
confluent env use $CCLOUD_ENV_ID

# Use kafka cluster
export CCLOUD_CLUSTER_ID=$(confluent kafka cluster list -o json | jq -r '.[] | select(.name | contains("'"${CCLOUD_CLUSTER_NAME:-demo_kafka_cluster}"'")) | .id')
confluent kafka cluster use $CCLOUD_CLUSTER_ID

# Get a list of all existing topics
topic_list_raw=$(curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request GET --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/search/basic?types=kafka_topic" | jq '.')

############################################
# Tags and details for topics
############################################

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    # Get a list of all topic names and their qualified names, excluding topics that start with _confluent
    names=($(echo "$topic_list_raw" | jq -r '.entities[].attributes.name | select(. | startswith("_confluent") | not)'))
    qualifiedNames=($(echo "$topic_list_raw" | jq -r '.entities[].attributes.qualifiedName | select(. | contains("_confluent") | not)'))

    # Iterate through the names and qualifiedNames
    for ((i=0; i<${#names[@]}; i++)); do
        name="${names[i]}"
        qualifiedName="${qualifiedNames[i]}"

        # Assign PII, DataProduct and Sensitive tags to orders_enriched topic
        if [[ $name == "orders_enriched" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "PII"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "DataProduct"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Sensitive"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Real-time stream of data that shows customers purchases across channels." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"
            orders_enriched_qualified_name=$qualifiedName

        # Assign PII, DataProduct and Sensitive tags to customers_enriched topic
        elif [[ $name == "customers_enriched" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "PII"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "DataProduct"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Sensitive"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "This stream is updated in real time to show each customer information." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"

        # Assign PII, DataProduct and Sensitive tags to rewards_status topic
        elif [[ $name == "rewards_status" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "PII"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "DataProduct"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Sensitive"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Real-time stream of data that shows customer loyalty status as they make purchases across channels." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"
            rewards_status_qualified_name=$qualifiedName

        # Assign RAW tag to postgres.products.products, products, and products_rekeyed topics
        elif [[ $name == "postgres.products.products" ]] || [[ $name == "products" ]] || [[ $name == "products_rekeyed" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "RAW"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Live product inventory across warehouses and online website replicated from PostgreSQL database." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"

        # Assign RAW and Private tags to postgres.products.orders and orders_rekeyed topics
        elif [[ $name == "postgres.products.orders" ]] || [[ $name == "orders_rekeyed" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "RAW"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Private"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Live purchase orders by each customer across physical stores and online website replicated from PostgreSQL database." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"

        # Assign RAW and PII tags to ORCL.ADMIN.CUSTOMERS and customers topics
        elif [[ $name == "ORCL.ADMIN.CUSTOMERS" ]] || [[ $name == "customers" ]]; then
        curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "RAW"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "PII"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Customer data replicated from Oracle database." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"

        # Assign RAW, Private, Sensitive tags to ORCL.ADMIN.DEMOGRAPHICS and demographics topics
        elif [[ $name == "ORCL.ADMIN.DEMOGRAPHICS" ]] || [[ $name == "demographics" ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "RAW"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Private"}, {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "Sensitive"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Customer demographics data replicated from Oracle database." "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"
        
        elif [[ $name == "dlq"* ]]; then
            curl --silent -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET --request POST --url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/entity/tags" --header 'Content-Type: application/json' --data '[ {  "entityType" : "kafka_topic",  "entityName" : "'"$qualifiedName"'", "typeName" : "DLQ"} ]' | jq .
            add_details "kafka_topic" "$qualifiedName" "Dead letter queue topic for sink connector" "$CONFLUENT_CLOUD_USER_FULL_NAME" "$CONFLUENT_CLOUD_EMAIL"

        fi
    done
else
    echo "Error: Curl command failed."
fi

############################################
# Business metadata for topics
############################################

echo "Creating business metadata and adding them to relevant topics"

# Create business metadata for orders_enriched topic
entity_name="$orders_enriched_qualified_name"
team_owner="customer_support"
slack_contact="#customer_support"
name="Customers orders."
output_file="team_customer_support.txt"
add_business_metadata "$entity_name" "$team_owner" "$slack_contact" "$name" "$output_file"

# Create business metadata for rewards_status topic
entity_name="$rewards_status_qualified_name"
team_owner="marketing_analytics"
slack_contact="#marketing_analytics"
name="Customer loyalty status."
output_file="team_marketing_analytics.txt"
add_business_metadata "$entity_name" "$team_owner" "$slack_contact" "$name" "$output_file"