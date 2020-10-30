echo "Starting up airflow"
# sanity check the dags
ls /opt/airflow/dags

# Install boto for the seed dag
python -m pip install boto3==1.14.38 --user
# Intall python packages through req.txt and pip
python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
# Run the airflow webserver
exec airflow webserver