import boto3, os

client = boto3.client('datasync', region_name=os.environ['REGION'])

def handler(event,context):
    task_arn = 'arn:aws:datasync:{region}:{account_id}:task/{task_id}'.format(region=os.environ['REGION'], account_id=os.environ['ACCOUNT_ID'], task_id=os.environ['TASK_ID'])
    response = client.start_task_execution(TaskArn=task_arn)