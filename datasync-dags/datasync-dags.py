import logging, urllib3, json, os

def handler(context, event):
    http = urllib3.PoolManager()

    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': "Basic %s" % os.environ['API_KEY']
    }

    logging.info('Triggering Airflow DAG {dag_id}'.format(dag_id=os.environ['DAG_ID']))
    url = 'http://{airflow_url}/api/v1/dags/{dag_id}/dagRuns'.format(airflow_url=os.environ['AIRFLOW_URL'], dag_id=os.environ['DAG_ID'])
    
    response = http.request('POST',
        url=url,
        body=json.dumps({}),
        headers=headers,
        retries = False
    )
    return {
            'statusCode': response.status,
            'body': json.dumps(json.loads(response.data))
        }