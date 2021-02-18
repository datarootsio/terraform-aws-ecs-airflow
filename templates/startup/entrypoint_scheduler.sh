echo "Starting up airflow scheduler"
# Sanity check the dags
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
python -m pip install awscli --user

# Intall python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "requirements.txt provided, installing it with pip"
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi
# Run the airflow webserver
airflow scheduler