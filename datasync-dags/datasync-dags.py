import base64, logging, urllib3, json

def handler(context, event):
    http = urllib3.PoolManager()
    # TODO: temporary solution for the username and pass
    userpass = 'admin' + ':' + 'admin'
    encoded_u = base64.b64encode(userpass.encode()).decode()
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': "Basic %s" % encoded_u
    }

    logging.info('Triggering Airflow DAG {dag_id}'.format(dag_id='0_sync_dags_in_s3_to_local_airflow_dags_folder'))
    airflow_url = "airflow-base-airflow-shared-351165443.us-west-2.elb.amazonaws.com"
    url = 'http://{airflow_url}/api/v1/dags/{dag_id}/dagRuns'.format(airflow_url=airflow_url, dag_id='0_sync_dags_in_s3_to_local_airflow_dags_folder')
    
    response = http.request('POST',
        url=url,
        body=json.dumps({}),
        headers=headers,
        retries = False
    )
    print(response.status)
    print(json.dumps(json.loads(response.data)))
    return {
            'statusCode': response.status,
            'body': json.dumps(json.loads(response.data))
        }