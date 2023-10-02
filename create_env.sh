#!/bin/bash

accounts_file=".accounts"
env_file=".env"

# Check if .accounts file exists
if [ ! -f "$accounts_file" ]; then
    echo "$accounts_file not found."
    exit 1
fi

# Define the environment variable content
env_content=$(cat <<EOF
CCLOUD_API_KEY=api-key
CCLOUD_API_SECRET=api-secret
CCLOUD_BOOTSTRAP_ENDPOINT=kafka-cluster-endpoint

ORACLE_USERNAME=admin
ORACLE_PASSWORD=demo-cdc-c0nflu3nt!
ORACLE_ENDPOINT=oracle-endpoint
ORACLE_PORT=1521

POSTGRES_PRODUCTS_ENDPOINT=postgres-products
REDSHIFT_ADDRESS=redshift-address

SF_PVT_KEY=snowflake-private-key

export SNOWFLAKE_USER="tf-snow"
export SNOWFLAKE_PRIVATE_KEY_PATH="../snowflake/snowflake_tf_snow_key.p8"
EOF
)

# Combine the environment variable content with .accounts and write to .env
echo "$env_content" | cat - "$accounts_file" > "$env_file"

echo "Created an environment file named: $env_file"
