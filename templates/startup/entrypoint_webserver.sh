#!/bin/bash
echo "[INFO] Starting up airflow webserver"
# sanity check the dags
echo "[INFO] Available dags:"
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
echo "[INFO] Installing awscli"
python -m pip install awscli --user

# Install python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/startup/requirements.txt" ]]; then
    echo "[INFO] requirements.txt provided. Installing requirements.txt dependencies with pip."
    python -m pip install -r ${AIRFLOW_HOME}/startup/requirements.txt --user
fi

export AIRFLOW__WEBSERVER__SECRET_KEY=$(openssl rand -hex 30)

# Run the airflow webserver
echo "[INFO] Running airflow webserver"
airflow webserver