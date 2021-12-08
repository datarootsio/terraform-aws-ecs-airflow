#!/bin/bash
echo "[INFO] Starting up airflow init"

# commands change between version so get the major version here
airflow_major_version=$(echo ${AIRFLOW_VERSION} | awk -F. '{ print $1 }')

# prepare database if needed
echo "[INFO] Check and prepare database"
if ! python ./startup/init.py ; then
  exit 1
fi

# airflow
echo "[INFO] Running airflow db init"
if [[ "$airflow_major_version" == "1" ]]; then
    airflow initdb
else
    airflow db init
fi

# add admin user if rbac enabled and not exists
if [[ "${RBAC_AUTH}" == "true" ]]; then
  echo "[INFO] Enabling RBAC authentication"
    # get the amount of users to see if we need to add a default user
    amount_of_users="-9999"
    if [[ "$airflow_major_version" == "1" ]]; then
        amount_of_users=$(python -c 'import sys;print((sys.argv.count("│") // 7) - 1)' $(airflow list_users))
    else
        amount_of_users=$(python -c 'import sys;cmd_in = " ".join(sys.argv);print((cmd_in.count("|") // 5) - 1 if "No data found" not in cmd_in else 0)' $(airflow users list))  
    fi

    if [[ "$amount_of_users" == "0" ]]; then
        echo "[INFO] Adding admin users, users list is empty!"
        if [[ "$airflow_major_version" == "1" ]]; then
            airflow create_user -r Admin -u ${RBAC_USERNAME} -e ${RBAC_EMAIL} -f ${RBAC_FIRSTNAME} -l ${RBAC_LASTNAME} -p ${RBAC_PASSWORD}
        else
            airflow users create -r Admin -u ${RBAC_USERNAME} -e ${RBAC_EMAIL} -f ${RBAC_FIRSTNAME} -l ${RBAC_LASTNAME} -p ${RBAC_PASSWORD}  
        fi
    else
        echo "[INFO] No admin user added, users already exists!"
    fi
else
  airflow users create --role Admin --username admin --email admin --firstname admin --lastname admin --password admin
fi