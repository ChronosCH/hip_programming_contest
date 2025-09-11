#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>

// 串行前缀和算法
void solve_serial(const int* input, int* output, int N) {
    if (N <= 0) return;
    
    // 简单的顺序前缀和算法
    output[0] = input[0];
    for (int i = 1; i < N; i++) {
        output[i] = output[i - 1] + input[i];
    }
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }
    
    std::ifstream input_file;
    std::string filename = argv[1];
    
    input_file.open(filename);
    if (!input_file.is_open()) {
        std::cerr << "fileopen error " << filename << std::endl;
        return 1;
    }

    int N;
    input_file >> N;

    std::vector<int> input(N), output(N);
    for(int i = 0; i < N; ++i) 
        input_file >> input[i];
    input_file.close();

    // 计时
    auto start = std::chrono::high_resolution_clock::now();
    
    solve_serial(input.data(), output.data(), N);
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    
    // 输出结果
    for(int i = 0; i < N; ++i) 
        std::cout << output[i] << " ";
    std::cout << std::endl;
    
    return 0;
}
