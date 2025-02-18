import os
from typing import Callable, List

#query cedardb
import psycopg as pg 
import pandas as pd 

USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432


def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)

OUTPUT_FOLDER = get_real_path("../plots/point_in_time/")


def transform_query(query : str, overwrite_f : List[Callable[[str],str]] = []) -> str:
    for transformation in overwrite_f:
        query = transformation(query)
    return query

def replace_fuel_gen(fuel : str) -> Callable[[str],str]:
    return lambda q: q.replace("diesel",fuel)




def read_query(query_file : str, overwrite_f : List[Callable[[str],str]] = []) -> str:
    query = open(get_real_path(query_file),"r").read()
    return transform_query(query, overwrite_f)

def execute_statement(stmt : str):
     with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        with conn.cursor() as cur:
            cur.execute(stmt) #type: ignore
            print(f"Number of rows affected: {cur.rowcount}")
            conn.commit()

def run_query(query : str) -> pd.DataFrame:
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        return pd.read_sql(query,conn)



