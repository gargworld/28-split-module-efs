import os
import boto3

def lambda_handler(event, context):
    project_name = os.environ['PROJECT_NAME']
    client = boto3.client('codebuild')

    response = client.start_build(projectName=project_name)
    print(f"Started CodeBuild: {response['build']['id']}")

