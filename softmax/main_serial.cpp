#include "main_serial.h"
#include <algorithm>
#include <cmath>
#include <cfloat>

// 串行实现的 softmax 函数
void solve_serial(const float* input, float* output, int N) {
    // Step 1: 找到最大值（数值稳定性）
    float max_val = -FLT_MAX;
    for (int i = 0; i < N; i++) {
        max_val = std::max(max_val, input[i]);
    }
    
    // Step 2: 计算 exp(x_i - max) 和总和
    double total_sum = 0.0;
    for (int i = 0; i < N; i++) {
        float exp_val = expf(input[i] - max_val);
        output[i] = exp_val;  // 临时存储 exp 值
        total_sum += (double)exp_val;  // 使用双精度累加
    }
    
    // Step 3: 计算最终的 softmax 值
    for (int i = 0; i < N; i++) {
        output[i] = (float)((double)output[i] / total_sum);
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

    std::vector<float> input(N), output(N);

    for(int i = 0; i < N; ++i) {
        input_file >> input[i];
    }

    input_file.close();

    // 调用串行实现
    solve_serial(input.data(), output.data(), N);

    for(int i = 0; i < N; ++i) {
        std::cout << output[i];
        if (i < N - 1) std::cout << " ";
    }
    std::cout << " " << std::endl;
    
    return 0;
}
