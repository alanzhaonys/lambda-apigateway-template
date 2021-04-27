#!/bin/bash

source ./variables.sh

API_KEY=$1

if [ "$API_KEY" == "" ] ; then
  API_KEY=($(aws apigateway get-api-keys \
    --include-values \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}-api-key\").value"))
fi

if [ "$API_KEY" == "" ]; then
  echo Unable to test API, API key is not found
  exit
fi

API_GATEWAY_ID=($(aws apigateway get-rest-apis \
  --profile $PROFILE \
  --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}\").id"))

if [ "$API_GATEWAY_ID" == "" ]; then
  echo API gateway not found
  exit
fi

API_URL=https://${API_GATEWAY_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}/${API_RESOURCE}

echo API URL: $API_URL
echo API key: $API_KEY

curl -i -X $API_METHOD --header "x-api-key:${API_KEY}" $API_URL
