provider "aws" {
  region = var.aws_region
}

# ==============================================================================
# PERSISTENCE TIER (DYNAMODB)
# ==============================================================================

resource "aws_dynamodb_table" "db" {
  name         = "ProductInventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  tags = {
    Environment = "Production"
    Project     = "Serverless-API"
  }
}

# ==============================================================================
# SECURITY & IDENTITY TIER (IAM)
# ==============================================================================

resource "aws_iam_role" "lambda_role" {
  name = "lambda_dynamo_api_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_dynamo_minimum_policy"
  description = "Provides precise minimal cloud permissions for DynamoDB access and CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.db.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ==============================================================================
# COMPUTE TIER (AWS LAMBDA)
# ==============================================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  
  source {
    content  = <<-EOF
      import json, boto3, os
      dynamodb = boto3.resource('dynamodb')
      table = dynamodb.Table(os.environ['TABLE_NAME'])
      def lambda_handler(event, context):
          return {
              'statusCode': 200,
              'headers': {'Content-Type': 'application/json'},
              'body': json.dumps({'status': 'success', 'message': 'Hello from Serverless IaC backend!'})
          }
      EOF
    filename = "index.py"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/ServerlessApiHandler"
  retention_in_days = 7
}

resource "aws_lambda_function" "api_backend" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ServerlessApiHandler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = { TABLE_NAME = aws_dynamodb_table.db.name }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# ==============================================================================
# INGRESS TIER (API GATEWAY V2)
# ==============================================================================

resource "aws_apigatewayv2_api" "http_api" {
  name          = "serverless-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_backend.invoke_arn
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
