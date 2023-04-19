#! /bin/bash

echo "generating connector configuration json files from .env"
echo

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../.env

for i in example_postgres_products_source.json example_oracle_cdc.json example_snowflake_sink.json example_redshift_sink.json; do
    sed -e "s|<add_your_api_key>|${CCLOUD_API_KEY}|g" \
    -e "s|<add_your_api_secret_key>|${CCLOUD_API_SECRET}|g" \
    -e "s|<add_your_postgres_products_hostname>|${POSTGRES_PRODUCTS_ENDPOINT}|g" \
    -e "s|<add_your_rds_endpoint>|${ORACLE_ENDPOINT}|g" \
    -e "s|<add_your_redshift_address>|${REDSHIFT_ADDRESS}|g" \
    -e "s|<add_snowflake_private_key>|${SF_PVT_KEY}|g" \
    -e "s|<add_snowflake_account>|${SNOWFLAKE_ACCOUNT}|g" \
    ${DIR}/$i > ${DIR}/actual_${i#example_}
done