METADATA_FILE=$1

source ../.env

curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET  -X POST -H "Content-Type: application/json" \
--data @$METADATA_FILE "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/businessmetadatadefs" | jq .
