# Softmax 函数计算

## 题目描述

实现一个GPU程序，计算一维浮点数数组的**softmax**函数。
给定输入向量$\mathbf{x} = [x_1, x_2, \dots, x_N]$，产生$\mathbf{y} = [y_1, y_2, \dots, y_N]$，其中：

$$
y_i = \frac{e^{x_i}}{\sum_{j=1}^{N} e^{x_j}}
$$

由于朴素指数计算可能溢出/下溢，您**必须**使用数值稳定形式：

$$
m = \max_i x_i, \quad
t_i = e^{x_i - m}, \quad
S = \sum_{i=1}^{N} t_i, \quad
y_i = \frac{t_i}{S}
$$

## 要求

* `solve`函数签名必须保持不变
* 使用上述数值稳定公式
* 只允许**单GPU**实现（不允许多GPU）

## 代码结构

```
.
├── main.cpp        # 读取输入，调用solve()，打印结果
├── kernel.hip      # GPU内核 + solve()实现
├── main.h          # 共享头文件 + solve()声明
├── Makefile
├── README.md
└── testcases       # 本地验证用样例测试用例
```

## 构建和运行

### 构建

```bash
make
```

生成可执行文件：`softmax`。

### 运行

```bash
./softmax input.txt
```

---

## 测试用例

`testcases/`文件夹包含**10个**样例输入文件和对应的输出。

运行样例：

```bash
./softmax testcases/1.in
```

容差：

* 绝对容差：$1\times 10^{-6}$
* 相对容差：$1\times 10^{-5}$
* 最小分母：$1\times 10^{-12}$

---

### 输入格式

* 第一行包含单个整数$N$，数组的长度
* 第二行包含$N$个用空格分隔的浮点数

**示例**

```
3
1.0 2.0 3.0
```

**约束条件**

* $1 \le N \le 100{,}000{,}000$
* $\text{input}[i]$为浮点数

---

### 输出格式

* 输出$N$个浮点数，表示**softmax**值$y_1, y_2, \dots, y_N$
* 每个数字应满足给定的容差要求
* 数字用空格分隔，后跟换行符

**示例**

```
0.090 0.244 0.665
```

---

## 提交

您提交的文件夹必须命名为`softmax`

包含所有必需的源文件（`main.cpp`, `kernel.hip`, `main.h`, `Makefile`），以便可以直接用以下命令构建：

```bash
make
```

评分器应该能够：

```bash
cd $HOME/hip_programming_contest/softmax
make
./softmax <hidden_testcase.txt>
```

---