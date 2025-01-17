import os
from typing import Callable, List

#query cedardb
import psycopg as pg 
import pandas as pd 

def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432


POSSIBLE_FUELS= ['diesel', 'e5', 'e10']
OUTPUT_FOLDER = get_real_path("../plots")


def transform_query(query : str, overwrite_f : List[Callable[[str],str]] = []) -> str:
    for transformation in overwrite_f:
        query = transformation(query)
    return query

def read_query(query_file : str, overwrite_f : List[Callable[[str],str]] = []) -> str:
    query = open(get_real_path(query_file),"r").read()
    return transform_query(query, overwrite_f)

def execute_statement(stmt : str):
     with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        conn.execute(stmt) #type: ignore

def run_query(query : str) -> pd.DataFrame:
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        return pd.read_sql(query,conn)


# standard transformations -------------

def insert_params_gen(params : dict[str,str]) -> Callable[[str],str]:
    def f(q: str) -> str:
        for name in params:
            q = q.replace(f":'{name}'",f"'{params[name]}'")
        return q
    return f

def replace_fuel_gen(fuel : str) -> Callable[[str],str]:
    return lambda q: q.replace("diesel",fuel)


def query_priceat(fuel : str, remove_outliers : bool, params : dict[str,str]) -> pd.DataFrame:
    overwrite_f = [replace_fuel_gen(fuel), insert_params_gen(params)]
    if remove_outliers:
        overwrite_f.append(lambda q: q.replace(";", " where abs(z_score) < 3;"))    
    
    return run_query(read_query("../sql/PriceAt.sql",overwrite_f)) 