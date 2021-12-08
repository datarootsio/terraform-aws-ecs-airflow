#!/bin/bash
echo "[INFO] Starting up airflow scheduler"
# Sanity check the dags
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
# Run the airflow scheduler
echo "[INFO] Running airflow scheduler"
airflow scheduler