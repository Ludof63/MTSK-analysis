import os
import time
from csv import DictReader
from datetime import datetime, timezone
import argparse
import psycopg as pg 


DEFUALT_PRICES_FOLDER= "../../data/prices"
DEFAULT_SPEED_FACTOR = 1

PRICES_TABLE="prices"
PORT=5432


USER, USER_PSWD, DB = os.getenv('CEDAR_USER'),os.getenv('CEDAR_PASSWORD'), os.getenv('CEDAR_DB')
if not all([USER,USER_PSWD, DB]):
    print("Missing env variables")
    exit(1)
    

CONN_STR = f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}"


def insert_row(row : dict[str,str]) -> str:
    return f"""
            INSERT INTO {PRICES_TABLE} (
                time, station_uuid, diesel, e5, e10, diesel_change, e5_change, e10_change
            ) VALUES (
                '{row['date']}', '{row['station_uuid']}', 
                {row['diesel']}, {row['e5']}, {row['e10']}, 
                {row['dieselchange']}, {row['e5change']}, {row['e10change']}
            );
        """


def transactional_workload(files : list[str], speed_factor : int, start_time : datetime):
    print(f"Similating Workload: from {files[0]} to {files[-1]}")   

    start_time = start_time.replace(tzinfo=timezone.utc)
    found_start = False
    with pg.connect(CONN_STR) as conn:
        for file in files:
            print(f"\nReading file: {file}")
            with open(file, 'r') as f:
                reader = DictReader(f)

                to_insert = []  # Buffer rows to insert
                for row in reader:
                    row_time = datetime.fromisoformat(row['date'])

                    if not found_start:
                        if row_time > start_time:
                            found_start = True
                            base_time = row_time
                            current_time = row_time
                            real_start_time = time.time()
                            print(f"Starting Worload from {current_time}  with speed factor {speed_factor}X")
                    else:
                        if row_time <= current_time:
                            to_insert.append(row)
                        else:
                            if len(to_insert) > 0:
                                for entry in to_insert:
                                    conn.execute(insert_row(entry))  # type: ignore
                                conn.commit()
                                
                                print(f"Inserted {len(to_insert)} updates at {current_time}")
                                to_insert.clear()

                            current_time = row_time #move time to next row time

                            
                            elapsed_real = time.time() - real_start_time
                            elapsed_fake = (current_time - base_time).total_seconds() 
                            time_to_sleep = (elapsed_fake / speed_factor) - elapsed_real
                            if time_to_sleep > 0:
                                print(f"Elapsed fake: {elapsed_fake}, Elapsed real: {elapsed_real}, -> sleep for {round(time_to_sleep,4)}s\n")
                                time.sleep(time_to_sleep)

                            to_insert.append(row)

                for entry in to_insert:
                    conn.execute(insert_row(entry))  # type: ignore
                conn.commit()

    print("Transactional workload simulation finished")



def main():
    parser = argparse.ArgumentParser(description="Process an optional price folder argument.")
    parser.add_argument("-p", "--price-folder", type=str, help="Path to the price folder", default=DEFUALT_PRICES_FOLDER)
    parser.add_argument("-s", "--speed", type=int, help="Speed Factor", default=DEFAULT_SPEED_FACTOR)

    args = parser.parse_args()

    with pg.connect(CONN_STR) as conn:
        with conn.cursor() as cur:
            record = cur.execute("select max(time) from prices;").fetchone()

   
    max_time : datetime | None = record[0] if record else None
    print(max_time)
    max_time_str : str = max_time.strftime("%Y-%m-%d") if max_time else ""

    price_files = []
    for root, _, files in os.walk(args.price_folder):
        for file in files:
            if file.endswith("-prices.csv"):
                if file.split("-prices.csv")[0] >= max_time_str:
                    price_files.append(os.path.join(root, file))

    price_files = sorted(price_files)
    if len(price_files) == 0:
        print(f"0 files found in {args.price_folder}")       
    else:
        transactional_workload(price_files, args.speed,max_time)
    
main()