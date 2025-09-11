#ifndef MAIN_SERIAL_H
#define MAIN_SERIAL_H

#include <iostream>
#include <iomanip>
#include <vector>
#include <fstream>
#include <float.h>

// 串行版本的 softmax 函数声明
void solve_serial(const float* input, float* output, int N);

#endif
