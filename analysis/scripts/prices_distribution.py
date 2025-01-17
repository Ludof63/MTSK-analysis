from common import *
import argparse

#plotting
import matplotlib.pyplot as plt
import numpy as np


OUTPUT_FILENAME="prices_dist_{fuel}.png"

VALUE_COL="price"
N_BINS= 50
TIME = '2024-11-01 12:00'
PARAMS ={'time' : TIME}

def plot_hg(fuel : str, remove_outliers : bool):
    print(f"Fuel: {fuel}; remove_outliers: {remove_outliers}")
    df = query_priceat(fuel,remove_outliers, PARAMS)

    mean_value, std_dev = df[VALUE_COL].mean(),df[VALUE_COL].std()
    print(f"Fuel: {fuel} -> Mean: {mean_value} | StdDev: {std_dev}")
   
    counts, bin_edges = np.histogram(df[VALUE_COL], bins=N_BINS)
    bin_midpoints = (bin_edges[:-1] + bin_edges[1:]) / 2

    plt.figure(figsize=(10, 6))
    plt.hist(df[VALUE_COL], bins=N_BINS, color='skyblue', edgecolor='black')
    plt.plot(bin_midpoints, counts, marker='o', linestyle='-', color='b')

    plt.xlabel(f'{fuel} Price')
    plt.ylabel('Number of Stations')
    plt.title(f'Number of Stations by {fuel} Price at {TIME}')
    
    plot_label = f"{fuel}{'_no_outliers' if remove_outliers else ''}"
    plot_file = OUTPUT_FILENAME.format(fuel=plot_label)
    plt.savefig(os.path.join(OUTPUT_FOLDER,plot_file))
    print(f"Plot saved in {plot_file}")



def main():
    parser = argparse.ArgumentParser(description="Plot prices distribution")
    parser.add_argument('fuel', nargs='?', default='diesel')
    parser.add_argument('-o', action='store_true',help="Remove outliers")
    
    args = parser.parse_args()

    if args.fuel not in POSSIBLE_FUELS:
        print(f"{args.fuel} is not a valid fuel")
        exit(1)
    
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    plot_hg(args.fuel,args.o)

main()