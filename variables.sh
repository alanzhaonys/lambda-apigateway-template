#!/bin/bash

readonly APP_JSON_FILE=app.json

readonly ACCOUNT_ID=$(jq -r ".accountId" $APP_JSON_FILE)
readonly PROFILE=$(jq -r ".profile" $APP_JSON_FILE)
readonly LAMBDA_FUNCTION=$(jq -r ".lambdaFunction" $APP_JSON_FILE)
readonly LAMBDA_TIMEOUT=$(jq -r ".lambdaTimeout" $APP_JSON_FILE)
readonly LAMBDA_MEMORY=$(jq -r ".lambdaMemory" $APP_JSON_FILE)
readonly AWS_REGION=$(jq -r ".awsRegion" $APP_JSON_FILE)
readonly API_RATE_LIMIT=$(jq -r ".apiRateLimit" $APP_JSON_FILE)
readonly API_BURST_LIMIT=$(jq -r ".apiBurstLimit" $APP_JSON_FILE)
readonly API_QUOTA_LIMIT=$(jq -r ".apiQuotaLimit" $APP_JSON_FILE)
readonly API_QUOTA_PERIOD=$(jq -r ".apiQuotaPeriod" $APP_JSON_FILE)

readonly API_RESOURCE=$(jq -r ".apiResource" $APP_JSON_FILE)
readonly API_METHOD=$(jq -r ".apiMethod" $APP_JSON_FILE)
readonly STAGE_NAME=$(jq -r ".stageName" $APP_JSON_FILE)

readonly ENV_VARIABLE_1=$(jq -r ".env_variable_1" $APP_JSON_FILE)
readonly ENV_VARIABLE_2=$(jq -r ".env_variable_2" $APP_JSON_FILE)

# Check jq installation
if ! hash jq 2>/dev/null; then
  echo jq is not installed
  echo You can install it by running: brew install jq
  end
fi

