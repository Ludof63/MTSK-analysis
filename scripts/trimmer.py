import csv
import sys

columns_to_keep = ['uuid', 'name', 'brand', 'street', 'house_number', 'post_code', 'city', 'latitude', 'longitude']

class Graph:
    def __init__(self):
        self.adj_list : dict[str, set[str]] = {}

    def add_edge(self, node1 : str, node2 : str):
        if node1 not in self.adj_list:
            self.adj_list[node1] = set()
        
        if node2 not in self.adj_list:
            self.adj_list[node2] = set()
        
        self.adj_list[node1].add(node2)
        self.adj_list[node2].add(node1)


    def compute_mappings(self, freq : dict[str, int]) -> dict[str, str]:
        component_mapping : dict[str,str] = {}
        visited = set()

        def find_representative(nodes : set[str]) -> str:
            max_frequency = max(freq[node] for node in nodes)
            candidates = [node for node in nodes if freq[node] == max_frequency]
            return min(
                (node for node in candidates if len(node) >0 and node[0].isupper()),
                key=len,
                default=min(nodes)
            ).title()

        def dfs(node):
            stack = [node]
            component = []
            while stack:
                current = stack.pop()
                if current not in visited:
                    visited.add(current)
                    component.append(current)
                    stack.extend(self.adj_list[current] - visited)
            return set(component)
        
        
        
        for node in self.adj_list:
            if node not in visited:
                component = dfs(node)
                assert len(component) > 0
                leader = find_representative(component)
                for member in component:
                    component_mapping[member] = leader

        return component_mapping

    def __str__(self):
        result = []
        for node in sorted(self.adj_list):
            neighbors = sorted(self.adj_list[node])
            result.append(f"{node}: {neighbors}")
        return "\n".join(result)


def trim_stations(input_file : str, output_file : str):
    graph = Graph()
    with open(input_file, mode='r', newline='') as infile:  #iterate once to spot conflict between cities (same post code but different city name)
        reader = csv.DictReader(infile) 
        post_code_conflicts : dict[str, list[str]] = {}
        cities_freq : dict[str, int] = {}

        for row in reader:
            assert isinstance(post_code := row.get('post_code'), str)
            assert isinstance(city := row.get('city'), str)

            if city in cities_freq:
                cities_freq[city] += 1
            else:
                cities_freq[city] = 1
            
            if post_code in post_code_conflicts:
                if city not in post_code_conflicts[post_code]:
                    for city2 in post_code_conflicts[post_code]:
                        graph.add_edge(city, city2)
                    post_code_conflicts[post_code].append(city)
            else:
                post_code_conflicts[post_code] = [city]

    conflicts_mapping = graph.compute_mappings(cities_freq)
    # for key, value in sorted(conflicts_mapping.items(), key=lambda item: (item[1], item[0])):
    #     print(f"{value} <- {key}")
        
    
    with open(input_file, mode='r', newline='') as infile, open(output_file, mode='w', newline='') as outfile:
        reader = csv.DictReader(infile)  
        writer = csv.DictWriter(outfile, fieldnames=columns_to_keep) 

        writer.writeheader()
        for row in reader:
            filtered_row = {key: row.get(key, '') for key in columns_to_keep}   
            if  filtered_row['city'] in conflicts_mapping:
                filtered_row['city'] =  conflicts_mapping[filtered_row['city']]     
            writer.writerow(filtered_row) 



def main():
    if len(sys.argv) != 3:
        print(f"Usage: python {sys.argv[0]} <input_csv> <output_csv>")
        sys.exit(1)


    trim_stations(sys.argv[1],sys.argv[2])


if __name__ == "__main__":
    main()