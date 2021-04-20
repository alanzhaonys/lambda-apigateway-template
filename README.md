Author: Alan Zhao
Email: azhao6060@gmail.com

### app.json

*profile*
This is the AWS profile that `awscli` uses to create and deploy Lambda and API gateway.

The IAM user of the profile should have these permissions:
- AmazonAPIGatewayAdministrator (for API gateway creation)
- AWSLambda_FullAccess (for Lambda function creation)
- IAMFullAccess (for Lambda role and policy creation)

The file `~/.aws/credentials` should have an entry like this:
[your-profile-name]
aws_access_key_id=XXXXXXXXXX
aws_secret_access_key=XXXXXXXXXXX

*accountId*
The AWS account ID that you're using.

*awsRegion*
The AWS region you're using. For example, us-east-1

*API Throttling*
- apiBurstLimit - The maximum number of concurrent requests that can occur at one time
Note that the Lambda function has a default maximum conconurrency level of 1000. If the burst rate limit is greater than 1000, you want to increase the Lmabda concurrency level as well
- apiRateLimit - The maximum number of requests that can occurs within one second
- apiQuotaLimit - Total number of request you can perform in a period of time
- apiQuotaPeriod - Period of time quota limit is applied, valid values are "DAY", "WEEK" or "MONTH". 

The throttling setting will apply to both method level and API key level

## CORS Support
You have to enable the CORS support by going to API endpoint, select method and Enable CORS. This enables the OPTIONS method.
https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/OPTIONS

After you manually enabled CORS, run `./deploy-api.sh` to take effect. It will take a few mins. You only need to do it once.
