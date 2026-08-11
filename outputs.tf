output "api_endpoint" {
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/items"
  description = "The live endpoint URL used to trigger and test the serverless backend function"
}
