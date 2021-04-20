#!/bin/bash

source ./variables.sh

# Zip function up
echo Zipping up the Lambda function
zip -r $LAMBDA_FUNCTION . -x \*.git \*.sh .env .env.sample app.json yarn.lock README.md $ZIP_NAME >/dev/null 2>&1

# Check if Lambda function exists
aws lambda get-function \
  --function-name $LAMBDA_FUNCTION \
  --profile $PROFILE \
  --region $AWS_REGION >/dev/null 2>&1

if [ 0 -eq $? ]; then

  echo Lambda function $LAMBDA_FUNCTION exists

  echo Updating it...

  aws lambda update-function-configuration \
    --function-name $LAMBDA_FUNCTION \
    --environment "{\"Variables\": {\"YOUR_VARIABLE_1\": \"${YOUR_VARIABLE_1}\", \"YOUR_VARIABLE_2\": \"${YOUR_VARIABLE_2}\"}}" \
    --timeout $LAMBDA_TIMEOUT \
    --memory-size $LAMBDA_MEMORY \
    --profile $PROFILE \
    --region $AWS_REGION

  aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION \
    --zip-file fileb://${LAMBDA_FUNCTION}.zip \
    --publish \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Updated Lambda function ${LAMBDA_FUNCTION}

else

  echo Setting up new Lambda function

  # echo List all role policies

  #aws iam list-attached-role-policies \
  #  --role-name ${LAMBDA_FUNCTION}-lambda-role \
  #  --profile $PROFILE \
  #  --region $AWS_REGION


  # Delete existing role policy if any
  #aws iam detach-role-policy \
  #  --role-name ${LAMBDA_FUNCTION}-lambda-role \
  #  --policy-arn arn:aws:iam::aws:policy/AWSLambdaFullAccess \
  #  --profile $PROFILE \
  #  --region $AWS_REGION

  aws iam detach-role-policy \
    --role-name ${LAMBDA_FUNCTION}-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    --profile $PROFILE \
    --region $AWS_REGION >/dev/null 2>&1

  # Delete existing lambda role if any
  aws iam delete-role \
    --role-name ${LAMBDA_FUNCTION}-lambda-role \
    --profile $PROFILE \
    --region $AWS_REGION >/dev/null 2>&1

  readonly ASSUME_ROLE_POLICY='{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal":
          {
            "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'

  readonly LAMBDA_ROLE=($(aws iam create-role \
    --role-name ${LAMBDA_FUNCTION}-lambda-role \
    --profile $PROFILE \
    --region $AWS_REGION \
    --assume-role-policy-document "$ASSUME_ROLE_POLICY" | jq -r ".Role.Arn"))

  if [ "$LAMBDA_ROLE" == "" ]; then
    echo Failed to create Lambda role, abort
    exit
  fi

  # Wait for the role to be created
  sleep 10

  echo Created Lambda role ${LAMBDA_ROLE}

  # Create custom SES policy
  readonly SES_POLICY="{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [
          \"ses:SendEmail\",
          \"ses:SendRawEmail\"
        ],
        \"Resource\": \"*\"
      }
    ]
  }"

  readonly SES_POLICY_ARN=($(aws iam create-policy \
    --policy-name ${LAMBDA_FUNCTION}-lambda-ses-policy \
    --policy-document "$SES_POLICY" \
    --profile $PROFILE \
    --region $AWS_REGION | jq -r ".Policy.Arn"))

  echo Created SES policy ARN: $SES_POLICY_ARN

  # Attach managed AWSLambdaBasicExecutionRole policy
  aws iam attach-role-policy \
    --role-name ${LAMBDA_FUNCTION}-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Attached AWSLambdaBasicExecutionRole policy to the role

  # Attach SES policy
  aws iam attach-role-policy \
    --role-name ${LAMBDA_FUNCTION}-lambda-role \
    --policy-arn $SES_POLICY_ARN \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Attached SES policy to the role

  aws lambda create-function \
    --function-name $LAMBDA_FUNCTION \
    --zip-file fileb://${LAMBDA_FUNCTION}.zip \
    --handler index.handler \
    --environment "{\"Variables\": {\"YOUR_VARIABLE_1\": \"${YOUR_VARIABLE_1}\", \"YOUR_VARIABLE_2\": \"${YOUR_VARIABLE_2}\"}}" \
    --runtime nodejs12.x \
    --timeout $LAMBDA_TIMEOUT \
    --memory-size $LAMBDA_MEMORY \
    --publish \
    --role $LAMBDA_ROLE \
    --profile $PROFILE \
    --region $AWS_REGION

  echo Created Lambda function ${LAMBDA_FUNCTION}
fi

# Clean up
rm -rf ${LAMBDA_FUNCTION}.zip
