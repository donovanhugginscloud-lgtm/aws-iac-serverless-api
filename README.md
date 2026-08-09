# Serverless API Architecture (IaC)

A Terraform-managed configuration that provisions a serverless microservice architecture utilizing an API Gateway ingress layer and a decoupled NoSQL persistence tier.

## Architectural Overview
This architecture processes incoming application traffic using fully managed cloud services, completely removing the operational overhead of persistent virtual server instances.
* Amazon API Gateway: Exposes a public HTTP API to route client traffic to downstream compute services.
* AWS Lambda: Executes business logic statelessly inside a managed Python runtime that scales automatically with request volume.
* Amazon DynamoDB: A fully managed NoSQL database providing single-digit millisecond latency data storage.

## Tech Stack
* API Layer: Amazon API Gateway (HTTP API v2)
* Compute Layer: AWS Lambda (Python 3.11)
* Database Layer: Amazon DynamoDB
* IaC Tooling: Terraform v1.5+

## Prerequisites
* AWS CLI configured with administrative or programmatic access permissions
* Terraform CLI (v1.5+) installed locally

## Deployment Instructions
1. Initialize the project directory and download required providers:
   ```bash
   terraform init
   ```
2. Generate and review the infrastructure execution plan:
   ```bash
   terraform plan
   ```
3. Provision the architecture on AWS:
   ```bash
   terraform apply --auto-approve
   ```
4. Destroy the resources when testing is complete:
   ```bash
   terraform destroy --auto-approve
   ```

## Infrastructure Configuration Details
* Automated Code Packaging: Uses the native Terraform archive provider to compress backend application script assets during runtime cycles, ensuring infrastructure and application states deploy together.
* Least-Privilege IAM Execution Roles: Implements a custom IAM execution policy restricting the Lambda function to specific table actions (`dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:Scan`) explicitly tied to the targeted DynamoDB resource ARN.
