from common import *
import argparse

#plotting
import matplotlib.pyplot as plt
import numpy as np

OUTPUT_FILENAME="prices_brand_{fuel}.png"

AVG_COL="avg_price"
N_STATION_COL="n_stations"
TIME = '2024-11-01 12:00'


QUERY="../sql/PriceAtBrands.sql"
PARAMS ={'time' : TIME}



def plot_hg(fuel : str):
    df = run_query(QUERY,fuel,PARAMS)
    df = df.sort_values(by='avg_price', ascending=False)
    print(f"Fuel: {fuel} -> Query done")

    print(f"Available columns: {df.columns}")
    
    fig, ax1 = plt.subplots(figsize=(10, 6))


    y = np.arange(len(df['brand']))
    bar_width = 0.4

    bars1 = ax1.barh(y - bar_width / 2, df['n_stations'], bar_width, label='Number of Stations', color='skyblue')
    ax1.set_ylabel('Top 10 Brands')
    ax1.set_xlabel('Number of Stations')
    ax1.tick_params(axis='y')

    ax2 = ax1.twiny()
    bars2 = ax2.barh(y + bar_width / 2, df['avg_price'], bar_width, label='Average Price', color='orange')
    ax2.set_xlabel(f'Average {fuel.title()} Price')

    for i, avg_price in enumerate(df['avg_price']):
        ax2.text(avg_price + 0.01, y[i] + bar_width, f'{avg_price:.2f}', va='center', ha='left', fontsize=10)

    ax1.set_yticks(y)
    ax1.set_yticklabels(df['brand'])

    handles1, labels1 = ax1.get_legend_handles_labels()
    handles2, labels2 = ax2.get_legend_handles_labels()
    handles = handles1 + handles2
    labels = labels1 + labels2

    ax1.legend(handles, labels, loc='upper right')
    ax1.set_ylim(-1, len(df['brand']) + 1)

    plt.title(f'Price by Brand for {fuel.title()} at {TIME}')
    
    plot_file = OUTPUT_FILENAME.format(fuel=fuel)
    plt.savefig(os.path.join(OUTPUT_FOLDER,plot_file))
    print(f"Plot saved in {plot_file}")



def main():
    parser = argparse.ArgumentParser(description="Plot prices distribution")
    parser.add_argument('fuel', nargs='?', default='diesel')    
    args = parser.parse_args()

    if args.fuel not in POSSIBLE_FUELS:
        print(f"{args.fuel} is not a valid fuel")
        exit(1)
    
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    plot_hg(args.fuel)

main()