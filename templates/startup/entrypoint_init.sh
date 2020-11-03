echo "starting the init"
airflow initdb

# add admin user if not exists
if [[ "${RBAC_AUTH}" == "true" ]]; then
    # todo if no users add admin user
    amount_of_users=$(python -c 'import sys;print((sys.argv.count("│") // 7) - 1)' $(airflow list_users))
    if [[ "$amount_of_users" == "0" ]]; then
        echo "Adding admin users, users list is empty!"
        airflow create_user -r Admin -u admin -e admin@admin.com -f Admin -l airflow -p admin
    else
        echo "No admin user added, users already exists!"
    fi
fi