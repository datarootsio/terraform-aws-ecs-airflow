import boto3

client = boto3.client('datasync', region_name='eu-west-1')

def handler(event,context):
    response = client.start_task_execution(TaskArn='arn:aws:lambda:eu-west-1:681718253798:function:datasync-dags')