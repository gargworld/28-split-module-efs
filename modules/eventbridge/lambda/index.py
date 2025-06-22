mport os
import boto3

def lambda_handler(event, context):
    print("Lambda triggered with event:", event)

    try:
        project_name = os.environ['PROJECT_NAME']
        print(f"Starting CodeBuild project: {project_name}")
        client = boto3.client('codebuild')
        response = client.start_build(projectName=project_name)
        print(f"Started CodeBuild: {response['build']['id']}")
    except Exception as e:
        print("Error:", str(e))
        raise
