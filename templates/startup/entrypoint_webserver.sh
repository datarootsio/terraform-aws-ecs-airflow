#!/bin/bash
echo "Starting up airflow webserver"
# sanity check the dags
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
python -m pip install awscli --user

# Intall python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "requirements.txt provided, installing it with pip"
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi

export AIRFLOW__WEBSERVER__SECRET_KEY=$(openssl rand -hex 30)

# Run the airflow webserver
airflow webserver