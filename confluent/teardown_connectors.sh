#!/bin/bash

# Source the .env file
current_dir=$(pwd)
parent_dir=$(dirname "$current_dir")

env_file="${parent_dir}/.env"

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

# Get the ID for all connectors
oracle_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("OracleCdcSourceConnector")) | .id')
postgres_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("PostgresCdcSource_Products")) | .id')
snowflake_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("SnowflakeSinkConnector")) | .id')
redshift_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("RedshiftSinkConnector")) | .id')

# Delete all connectors
echo "Deleting connectors..."
confluent connect cluster delete --force "$oracle_id"
confluent connect cluster delete --force "$postgres_id"
confluent connect cluster delete --force "$snowflake_id"
confluent connect cluster delete --force "$redshift_id"