import boto3, os

client = boto3.client('datasync', region_name=os.environ['REGION'])

def handler(event,context):
    response = client.start_task_execution(TaskArn=os.environ['TASK_ID'])