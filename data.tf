provider "aws" {
  region = "eu-central-1"
}
resource "aws_sns_topic" "mytopic_p" {
  name = "my-topic_p"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

resource "aws_cloudwatch_metric_alarm" "alarm" {
  alarm_name = "MyAlarmm"
  evaluation_periods = 1
  namespace = "AWS/Lambda"
  alarm_actions = [aws_sns_topic.mytopic_p.arn]
  metric_name = "NumberOfMessagesReceived"

  period = 300
  statistic = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold = 0
  unit = "Count"
  treat_missing_data = "notBreaching"
  dimensions = {
    name = "FunctionName",
    value = aws_lambda_function.nflplayer_lambda.function_name
  }
}
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:eu-west-1:111122223333:rule/RunDaily"
  qualifier     = "ime"
}
resource "aws_api_gateway_authorizer" "authorizer" {
  name = "authorizer"
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  authorizer_uri = aws_lambda_function.auth.invoke_arn
  authorizer_credentials = aws_iam_role.lambda_exec.arn
}
resource "aws_lambda_function" "auth" {
  function_name = "ime"
  handler = "authorizer.authorizer"
  role = aws_iam_role.lambda_exec.arn
  runtime = "nodejs10.x"
  s3_bucket = "testing-bucket-create-2021-25-02"
  s3_key = "/auth/authorizer.zip"
  timeout = 60
}

resource "aws_lambda_function" "nflplayer_lambda" {
  function_name = "NFLPlayerUsageModelEndpoint"
  handler = "main.handler"
  role = aws_iam_role.lambda_exec.arn
  runtime = "nodejs10.x"
  s3_bucket = "testing-bucket-create-2021-25-02"
  s3_key = "/main/main.zip"
  timeout = 60
}



resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_api_gateway_api_key" "key" {
  name = "demo"
}

resource "aws_api_gateway_usage_plan" "my_usage_plan" {
  name = "my_usage_plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.rest_api.id
    stage = aws_api_gateway_deployment.deploy.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "my_usage_plan_key"{
  key_id = aws_api_gateway_api_key.key.id
  key_type = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.my_usage_plan.id
}

#Configure APIGateway
resource "aws_api_gateway_rest_api" "rest_api" {
  name = "ServerlessExample_Pepi"
  description = "Terraform Serverless example"

}

#path_path is the fucking part of the url user/{proxy+}
# resource is like one endpoint of the api ( this is what I think )
resource "aws_api_gateway_resource" "proxy" {
  parent_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part = "purvi"
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
}

resource "aws_api_gateway_method_response" "method_response" {
  http_method = aws_api_gateway_method.proxy.http_method
  resource_id = aws_api_gateway_resource.proxy.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}




# mapping the resource endpoint ({proxy+) with method
resource "aws_api_gateway_method" "proxy" {
  authorization = "NONE"
  http_method = "GET"
  resource_id = aws_api_gateway_resource.proxy.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  api_key_required = true


}


# from our api ( gateway_rest_api )  our resource ( the path {proxy} ) with method ( method.proxy ) to our lambda
resource "aws_api_gateway_integration" "lambda" {
  http_method = aws_api_gateway_method.proxy.http_method
  resource_id = aws_api_gateway_resource.proxy.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id


  type = "AWS_PROXY"
  integration_http_method = "POST"

  #Where we are directing the request
  uri = aws_lambda_function.nflplayer_lambda.invoke_arn
}


# deploy our rest_api
#stage_name is wwww.something/test/something
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name = "test"
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_method.proxy,

  ]
}


#Grant access for lambda to be invoked by api_gateway
resource "aws_lambda_permission" "lambda_perm" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nflplayer_lambda.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}



output "base_url" {
  value = aws_api_gateway_deployment.deploy.invoke_url
}


#Resource:Configuration
#Method:Specify
#Integration:Respond