echo "Starting up airflow"
# Sanity check the dags
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
python -m pip install boto3==1.14.38 --user
python -m pip install awscli==1.18.192 --user

# Intall python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "requirements.txt provided, installing it with pip"
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi
# Run the airflow webserver
exec airflow scheduler