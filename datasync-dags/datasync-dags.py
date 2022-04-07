import boto3, os

client = boto3.client('datasync', region_name=os.environment['REGION'])
def handler(context, event):
    response = client.start_task_execution(TaskArn=os.environ['TASK_ID'])