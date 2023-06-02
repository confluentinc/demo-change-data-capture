import oracledb
import config
from time import sleep

def update_country_code(connection: oracledb.Connection, country_code: str = "US") -> None:

    # First retrieve all rows that have "US" as country_code 
    cursor = connection.cursor()
    statement = """
        SELECT * 
        FROM ADMIN.DEMOGRAPHICS demographics
        WHERE  demographics.COUNTRY_CODE = :1
    """
    cursor.execute(statement, [country_code])
    results = cursor.fetchall()

    # Update country_codes for all customers from US to USA

    for result in results:
        statement = """ 
            UPDATE ADMIN.DEMOGRAPHICS demographics
            SET demographics.COUNTRY_CODE = 'USA'
            WHERE demographics.ID = :1
        """
        cursor.execute(statement, [result[0]])
        connection.commit()
        print("Updated country code for customer id: "+result[0])
        sleep(5)
    cursor.close()

if __name__=="__main__":
  
    with oracledb.connect(
        user=config.username,
        password=config.password,
        dsn=config.dsn,
        port=config.port) as connection:
    
        update_country_code(connection)
