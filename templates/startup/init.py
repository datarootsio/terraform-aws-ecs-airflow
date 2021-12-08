import psycopg2
from psycopg2 import extensions
from urllib.parse import urlparse
import os

connection_string = os.environ['AIRFLOW__CORE__SQL_ALCHEMY_CONN']
url_parsed = urlparse(connection_string)
airflow_user = url_parsed.username
airflow_pass = url_parsed.password
db_name = url_parsed.path[1:]
hostname = url_parsed.hostname
port = url_parsed.port

conn = psycopg2.connect(
    # database=db_name,
    database="postgres",
    user=airflow_user,
    password=airflow_pass,
    host=hostname,
    port=port
)
curs = conn.cursor()
conn.set_isolation_level(extensions.ISOLATION_LEVEL_AUTOCOMMIT)
curs.execute(f"SELECT FROM pg_database WHERE datname = '{db_name}';")

if curs.rowcount < 1:
    curs.execute(f"CREATE DATABASE {db_name};")
    curs.execute(f"GRANT ALL PRIVILEGES ON DATABASE {db_name} TO {airflow_user};")

exit(0)
