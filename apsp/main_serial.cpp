#include "main_serial.h"

// Initialize distance matrix with INF and 0 on diagonal
void initialize_distance_matrix(int* dist, int V) {
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            if (i == j) {
                dist[i * V + j] = 0;
            } else {
                dist[i * V + j] = INF;
            }
        }
    }
}

// Add edge to distance matrix
void add_edge(int* dist, int V, int src, int dst, int weight) {
    dist[src * V + dst] = weight;
}

// Serial Floyd-Warshall algorithm implementation
void solve_apsp_serial(int* dist, int V) {
    // Floyd-Warshall algorithm: for each intermediate vertex k
    for (int k = 0; k < V; k++) {
        // For each source vertex i
        for (int i = 0; i < V; i++) {
            // For each destination vertex j
            for (int j = 0; j < V; j++) {
                // Check if path through k is shorter
                if (dist[i * V + k] != INF && dist[k * V + j] != INF) {
                    int new_dist = dist[i * V + k] + dist[k * V + j];
                    if (new_dist < dist[i * V + j]) {
                        dist[i * V + j] = new_dist;
                    }
                }
            }
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }
    
    std::ifstream input(argv[1]);
    if (!input) {
        std::cerr << "Error: Cannot open input file " << argv[1] << std::endl;
        return 1;
    }
    
    int V, E;
    input >> V >> E;
    
    // Allocate distance matrix
    int* dist = new int[V * V];
    
    // Initialize distance matrix
    initialize_distance_matrix(dist, V);
    
    // Read edges
    for (int i = 0; i < E; i++) {
        int src, dst, weight;
        input >> src >> dst >> weight;
        add_edge(dist, V, src, dst, weight);
    }
    
    input.close();
    
    // Solve APSP using serial algorithm
    solve_apsp_serial(dist, V);
    
    // Output result
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            std::cout << dist[i * V + j];
            if (j < V - 1) std::cout << " ";
        }
        std::cout << std::endl;
    }
    
    delete[] dist;
    return 0;
}
