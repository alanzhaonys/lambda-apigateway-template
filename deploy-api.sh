#!/bin/bash

# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/apigateway/index.html
# https://github.com/awsdocs/amazon-api-gateway-developer-guide/blob/main/doc_source/create-api-using-awscli.md
# https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway-tutorial.html

source ./variables.sh

# Check if Lambda function exists
aws lambda get-function \
  --function-name $LAMBDA_FUNCTION \
  --profile $PROFILE \
  --region $AWS_REGION >/dev/null 2>&1

if [ $? -gt 0 ]; then
  echo Lambda function does not exist, run ./deploy-lambda.sh first
  exit
fi

# Get Lambda function URI
readonly LAMBDA_FUNCTION_URI=($(aws lambda get-function \
  --function-name $LAMBDA_FUNCTION \
  --profile $PROFILE \
  --region $AWS_REGION | jq -r ".Configuration.FunctionArn"))

echo Found Lambda function: $LAMBDA_FUNCTION_URI

# Check if API exists
API_ID=($(aws apigateway get-rest-apis \
  --profile $PROFILE \
  --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}\").id"))

if [ "$API_ID" == "" ]; then

  echo Setting up new API

  API_ID=($(aws apigateway create-rest-api \
    --name $LAMBDA_FUNCTION \
    --description "${LAMBDA_FUNCTION} API" \
    --endpoint-configuration '{"types": ["REGIONAL"]}' \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".id"))

  if [ "$API_ID" == "" ]; then
    echo Failed to create API
    exit
  fi

  echo Created API

  readonly ROOT_RESOURCE_ID=($(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".items[] | select(.path==\"/\").id"))

  readonly API_RESOURCE_ID=($(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part $API_RESOURCE \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".id"))

  if [ "API_RESOURCE_ID" == "" ]; then
    echo Failed to create API resource
    exit
  fi

  echo Created API resource: ${API_RESOURCE_ID}

  aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $API_RESOURCE_ID \
    --http-method $API_METHOD \
    --api-key-required \
    --authorization-type "NONE" \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Created method for API resource

  # http://docs.aws.amazon.com/apigateway/api-reference/resource/integration/#uri
  # uri parameter must be in this format: arn:aws:apigateway:{region}:lambda:path/2015-03-31/functions/{lambda function arn}/invocations

  aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $API_RESOURCE_ID \
    --http-method $API_METHOD \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_FUNCTION_URI}/invocations" \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Created integration for API resource method

  # This is the response type that your API method returns.
  aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $API_RESOURCE_ID \
    --http-method $API_METHOD \
    --status-code 200 \
    --response-models application/json=Empty \
    --profile $PROFILE \
    --region $AWS_REGION

  # This is the response type that Lambda function returns.
  # Not needed for Lambda proxy
  #aws apigateway put-integration-response \
  #  --rest-api-id $API_ID \
  #  --resource-id $API_RESOURCE_ID \
  #  --http-method $API_METHOD \
  #  --status-code 200 \
  #  --response-templates application/json="" \
  #  --profile $PROFILE \
  #  --region $AWS_REGION

  # Delete existing permission if any
  aws lambda remove-permission \
    --function-name $LAMBDA_FUNCTION \
    --statement-id api-invoke-lambda \
    --profile $PROFILE \
    --region $AWS_REGION >/dev/null 2>&1

  aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION \
    --statement-id api-invoke-lambda \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/${API_METHOD}/${API_RESOURCE} \
    --profile $PROFILE \
    --region $AWS_REGION

  # Create deployment
  aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $STAGE_NAME \
    --stage-description "This is the latest" \
    --description "The latest changes" \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Created deployment

  # Delete exsiting API key with same name if any

  API_KEY_ID=($(aws apigateway get-api-keys \
    --include-values \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}-api-key\").id"))

  if [ "$API_KEY_ID" != "" ]; then

    # Delete associated usage plan if any

    USAGE_PLAN_ID=($(aws apigateway get-usage-plans \
      --key-id $API_KEY_ID \
      --profile $PROFILE \
      --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}-usage-plan\").id"))

    if [ "$USAGE_PLAN_ID" != "" ]; then
      
      aws apigateway delete-usage-plan \
        --usage-plan-id $USAGE_PLAN_ID \
        --profile $PROFILE \
        --region $AWS_REGION

      echo Deleted old usage plan: $USAGE_PLAN_ID
    fi

    aws apigateway delete-api-key \
      --api-key $API_KEY_ID \
      --profile $PROFILE \
      --region $AWS_REGION

    echo Deleted old API key: $API_KEY_ID
  fi

  # Create API key

  API_KEY_ID=($(aws apigateway create-api-key \
    --name ${LAMBDA_FUNCTION}-api-key \
    --description "$LAMBDA_FUNCTION API key" \
    --enabled \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".id"))

  echo Created API kye ID: $API_KEY_ID

  # Create usage plan

  # --api-stages defines the METHOD level throttle
  # --throttle and --quota defines the API key level throttle
  readonly USAGE_PLAN_ID=($(aws apigateway create-usage-plan \
    --name ${LAMBDA_FUNCTION}-usage-plan \
    --description "$LAMBDA_FUNCTION usage plan" \
    --api-stages "apiId=${API_ID},stage=${STAGE_NAME},throttle={/${API_RESOURCE}/${API_METHOD}={burstLimit=${API_BURST_LIMIT},rateLimit=${API_RATE_LIMIT}}}" \
    --throttle burstLimit=$API_BURST_LIMIT,rateLimit=$API_RATE_LIMIT \
    --quota limit=$API_QUOTA_LIMIT,offset=0,period=$API_QUOTA_PERIOD \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".id"))

  echo Created usage plan ID: $USAGE_PLAN_ID

  aws apigateway create-usage-plan-key \
    --usage-plan-id $USAGE_PLAN_ID \
    --key-type "API_KEY" \
    --key-id $API_KEY_ID \
    --profile $PROFILE \
    --region $AWS_REGION

else

  echo API exists
  echo Updating

  readonly API_RESOURCE_ID=($(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".items[] | select(.path==\"/${API_RESOURCE}\").id"))

  if [ "$API_RESOURCE_ID" == "" ]; then
    echo Locator resource not found
    exit
  fi

  # Create deployment
  aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $STAGE_NAME \
    --stage-description "This is the latest" \
    --description "The latest changes" \
    --profile $PROFILE \
    --region $AWS_REGION

fi

readonly API_KEY=($(aws apigateway get-api-keys \
  --include-values \
  --profile $PROFILE \
  --region $AWS_REGION | jq -r ".items[] | select(.name==\"${LAMBDA_FUNCTION}-api-key\").value"))

if [ "$API_KEY" == "" ]; then
  echo API key is not found
  exit
fi

echo API invoke URL:
echo https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}/${API_RESOURCE}
echo API KEY: $API_KEY

# Test API
./test-api.sh $API_KEY


# Test API internally

#aws apigateway test-invoke-method \
#  --rest-api-id $API_ID \
#  --resource-id $API_RESOURCE_ID \
#  --http-method $API_METHOD \
#  --path-with-query-string "" \
#  --headers "x-api-key=${API_KEY}" \
#  --profile $PROFILE \
#  --region $AWS_REGION

# Test API externally
