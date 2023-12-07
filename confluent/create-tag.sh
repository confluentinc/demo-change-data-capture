TAGFILE=$1

source ../.env

curl -u $CCLOUD_SCHEMA_REGISTRY_API_KEY:$CCLOUD_SCHEMA_REGISTRY_API_SECRET \
--header 'Content-Type: application/json' \
--data @$TAGFILE \
--url "{$CCLOUD_SCHEMA_REGISTRY_URL}/catalog/v1/types/tagdefs" | jq .
