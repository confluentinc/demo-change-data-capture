import oracledb
import os
import csv
import config
from pathlib import Path
from time import sleep

def execute_file(connection: oracledb.Connection, sql_file: str) -> None:
    cursor = connection.cursor()
    with open(sql_file) as statements:
        for statement in statements:
            statement = statement.strip().rstrip(";")
            if statement.startswith("--") or not statement:
                continue
            print("\nexecuting statement:")
            print(f"{statement};")
            try:
                if "rdsadmin" in statement:
                    cursor.execute(f"{statement};")
                else:
                    cursor.execute(statement)
            except oracledb.DatabaseError as e:
                error, = e.args
                print(error.message)
                print("skipping\n")
    connection.commit()

def create_demographics_table(connection: oracledb.Connection) -> None:
    cursor = connection.cursor()
    # cursor.execute(""" DROP TABLE IF EXISTS DEMOGRAPHICS""")
    sleep(2)
    cursor.execute(""" CREATE TABLE DEMOGRAPHICS (id VARCHAR(255) PRIMARY KEY, street_address VARCHAR2(255), state VARCHAR2(255), zip_code VARCHAR2(255), country VARCHAR2(255), country_code VARCHAR2(255))  """)
    connection.commit()
    cursor.close()
    # If the database connection is still open, then close it
    if (connection.ping()==False):
        connection.close()

def create_customers_table(connection: oracledb.Connection) -> None:
    cursor = connection.cursor()
    # cursor.execute(""" DROP TABLE IF EXISTS CUSTOMERS""")
    sleep(2)
    cursor.execute(""" CREATE TABLE CUSTOMERS (id VARCHAR(255) PRIMARY KEY, first_name VARCHAR2(255), last_name VARCHAR2(255), email VARCHAR2(255), phone VARCHAR2(255), dob VARCHAR2(255))  """)
    connection.commit()
    cursor.close()
    # If the database connection is still open, then close it
    if (connection.ping()==False):
        connection.close()


def populate_demographics_table(connection: oracledb.Connection, data_dir) -> None:
    # open the csv file
    data_file = os.path.join(data_dir, "data", "demographics.csv")

    with open(data_file, 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        # Iterate through CSV rows and insert data into database
        for row in reader:
            cursor = connection.cursor()
            cursor.execute("""
                INSERT INTO DEMOGRAPHICS (id, street_address, state, zip_code, country, country_code)
                VALUES (:id, :street_address, :state, :zip_code, :country, :country_code)
            """, {
                'id': row['id'],
                'street_address': row['street_address'],
                'state': row['state'],
                'zip_code': row['zip_code'],
                'country': row['country'],
                'country_code': row['country_code']
            })

            connection.commit()
            print("Successfully added a new row: "+row['id']+","+row['street_address']+","+row['state']+","+row['zip_code']+","+row['country']+","+row['country_code'])
            cursor.close()
            # sleep(0.1)

    # # If the database connection is still open, then close it
    if (connection.ping()==False):
        connection.close()


def populate_customers_table(connection: oracledb.Connection, data_dir) -> None:
    # open the csv file
    data_file = os.path.join(data_dir, "data", "customers.csv")

    with open(data_file, 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        # Iterate through CSV rows and insert data into database
        for row in reader:
            cursor = connection.cursor()
            cursor.execute("""
                INSERT INTO CUSTOMERS (id, first_name, last_name, email, phone, dob)
                VALUES (:id, :first_name, :last_name, :email, :phone, :dob)
            """, {
                'id': row['id'],
                'first_name': row['first_name'],
                'last_name': row['last_name'],
                'email': row['email'],
                'phone': row['phone'],
                'dob': row['dob']
            })

            connection.commit()
            print("Successfully added a new row: "+row['id']+","+row['first_name']+","+row['last_name']+","+row['email']+","+row['phone']+","+row['dob'])
            cursor.close()
            # sleep(0.1)

    # # If the database connection is still open, then close it
    if (connection.ping()==False):
        connection.close()

if __name__=="__main__":

    sql_enable_cdc = Path(__file__).absolute().with_name("enable_cdc.sql")
    python_prepare_database = Path(__file__).absolute().with_name("prepare_database.py")
    parent_directory = os.path.dirname(python_prepare_database)
    
    with oracledb.connect(
        user=config.username,
        password=config.password,
        dsn=config.dsn,
        port=config.port) as connection:

        print("Creating DEMOGRAPHICS table")
        create_demographics_table(connection)
        print("Populating DEMOGRAPHICS table")
        populate_demographics_table(connection, parent_directory)

        print("Creating CUSTOMERS table")
        create_customers_table(connection)
        print("Populating CUSTOMERS table")
        populate_customers_table(connection, parent_directory)

        print("\nEnabling Change Data Capture on DEMOGRAPHICS and CUSTOMERS table")
        execute_file(connection, sql_enable_cdc)