#include "main.h"

// Use the solve wrapper which chooses CPU or GPU based on N
extern "C" void solve(const float* input, float* output, int N);

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }
    
    std::ifstream input_file;
    std::string filename = argv[1];
    
    input_file.open(filename);
    if (!input_file.is_open()) {
        std::cerr << "fileopen error" << filename << std::endl;
        return 1;
    }
    int N;
    input_file >> N;

    std::vector<float> input(N), output(N);

    for(int i = 0; i < N; ++i) input_file >> input[i];

    input_file.close();

    solve(input.data(), output.data(), N);

    for(int i = 0; i < N; ++i) {
        std::cout << output[i];
        if (i < N - 1) std::cout << " ";
    }
    std::cout << " " << std::endl;
    
    return 0;
}
