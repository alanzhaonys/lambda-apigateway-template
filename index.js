"use strict";

const axios = require("axios");

//const allowMethods = "GET, POST";
const allowMethods = "POST";
const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  Allow: allowMethods,
  "Access-Control-Allow-Methods": allowMethods,
  "Access-Control-Allow-Headers": "*",
};

const aws = require("aws-sdk");
const ses = new aws.SES({ region: "us-east-1" });

exports.handler = async (event, context, callback) => {
  // Log request here
  console.log("Full Event: " + JSON.stringify(event));
  console.log("Context: " + JSON.stringify(context));

  const your_variable_1 = process.env.YOUR_VARIABLE_1;
  const your_variable_2 = process.env.YOUR_VARIABLE_2;

	const emailSender = process.env.EMAIL_SENDER;
	const emailRecipients = process.env.EMAIL_RECIPIENTS;

  if (!your_variable_1 || !your_variable_2) {
    return callback(
      null,
      createResponse(400, {
        requestId: context.awsRequestId,
        error: "At least one parameter is missing",
      })
    );
  }

  try {
    let payload = {
      variable_1: your_variable_1,
      variable_2: your_variable_2,
    };

    const res = await axios.post(
      "https://www.google.com",
      JSON.stringify(payload),
      {
        auth: {
          username: "username",
          password: "password"
        },
        headers: {
          "Content-Type": "application/json",
        },
      }
    );


    		var nyTime = new Date().toLocaleString("en-US", {
			timeZone: "America/New_York",
		});
		nyTime = new Date(nyTime);

		let emailSubject = "Email test " + nyTime.toLocaleString() + " EST";

		let emailMessage = emailSubject + "\n\n";
		emailMessage += "\ntesting\n";
		emailMessage += "=============\n";

		var sesParams = {
			Destination: {
				ToAddresses: emailRecipients.split(","),
			},
			Message: {
				Body: {
					Text: {
						Data: emailMessage,
					},
				},
				Subject: {
					Data: emailSubject,
				},
			},
			Source: emailSender,
			ReplyToAddresses: [emailSender],
			ReturnPath: emailSender,
		};

		await ses.sendEmail(sesParams, function (error, data) {
			if (error) {
				return callback(
					null,
					createResponse(400, {
						requestId: context.awsRequestId,
						error: "Failed to send email: " + error,
					})
				);
			} else {
				return callback(
					null,
					createResponse(200, {
						message: "Email sent successful",
					})
				);
			}
		}).promise();


    return callback(
      null,
      createResponse(200, {
        message: "API call successful",
      })
    );
  } catch (error) {
    return callback(
      null,
      createResponse(400, {
        requestId: context.awsRequestId,
        error: "API call failed. " + error,
      })
    );
  }

  function getVar(name) {
    // For GET
    //return event[name] ? event[name] : event.queryStringParameters[name];
    // For POST
    if (event[name]) {
      return event[name];
    }
    var body = JSON.parse(event.body);
    return body[name];
  }

  function createResponse(status, body) {
    return {
      headers: headers,
      statusCode: status,
      body: JSON.stringify(body),
    };
  }
};
