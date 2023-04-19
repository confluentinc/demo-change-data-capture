import os
from dotenv import load_dotenv

load_dotenv()  # take environment variables from .env.

username = os.environ.get("ORACLE_USERNAME")
password = os.environ.get("ORACLE_PASSWORD")
dsn = f'{os.environ.get("ORACLE_ENDPOINT")}/orcl'
port = int(os.environ.get("ORACLE_PORT","1521"))

if __name__=="__main__":
    for i in [username, password, dsn, port]:
        print(type(i))
        print(i)