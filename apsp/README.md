# 全点对最短路径 (APSP - All-Pairs Shortest Path)

## 题目描述

在GPU上实现高效的**全点对最短路径(APSP)**求解器。

给定一个有向加权图，边权为**非负数**，计算从每个顶点$i$到每个顶点$j$的最短路径距离。

## 要求

* 您可以选择**任何**算法来解决APSP问题
* 您必须**自己实现**最短路径算法（不允许使用外部库）
* 只允许**单GPU**实现（不允许多GPU）

## 代码结构

```
.
├── main.cpp              # GPU并行实现
├── main.h                # GPU版本头文件
├── main_serial.cpp       # CPU串行实现
├── main_serial.h         # 串行版本头文件
├── Makefile              # 构建配置
├── README.md             # 本文件
├── PERFORMANCE_ANALYSIS.md  # 详细性能分析
├── performance_comparison.sh    # 综合性能测试
├── simple_performance_test.sh   # 快速性能测试
└── testcases             # 本地验证用样例测试用例
```

## 构建和运行

### 构建

```bash
make                    # 构建GPU和串行版本
make apsp              # 仅构建GPU版本
make apsp_serial       # 仅构建串行版本
```

生成可执行文件：`apsp`（GPU）和 `apsp_serial`（CPU）。

### 运行

```bash
./apsp input.txt        # 运行GPU版本
./apsp_serial input.txt # 运行串行版本
```

### 性能对比

```bash
./simple_performance_test.sh     # 快速性能对比
./performance_comparison.sh      # 综合分析（较慢）
```

---

## 实现对比

本项目包含Floyd-Warshall算法的**串行CPU**和**并行GPU**两种实现：

### 串行实现 (`main_serial.cpp`)
- **算法**：经典Floyd-Warshall三重嵌套循环
- **复杂度**：O(V³)时间，O(V²)空间
- **优势**：
  - 零GPU初始化开销
  - 适合小图（< 1000个顶点）
  - 简单易调试
- **编译器**：g++使用-O2优化

### GPU实现 (`main.cpp`)
- **算法**：使用HIP的并行Floyd-Warshall
- **平台**：AMD ROCm + HIP编程模型
- **优势**：
  - 大图的大规模并行化
  - 4000顶点图上16倍加速
  - 对密集大规模问题高效
- **编译器**：hipcc使用-O2优化

### 性能总结
| 图大小 | 最佳实现 | 加速比 |
|------------|-------------------|---------|
| < 100个顶点 | 串行CPU | 1x（GPU开销占主导） |
| 100-1000个顶点 | 相当 | ~1x |
| > 1000个顶点 | 并行GPU | 高达16x |

详细性能分析请参见`PERFORMANCE_ANALYSIS.md`。

---

## 测试用例

`testcases/`文件夹包含**10个**样例输入文件和对应的输出。

运行样例：

```bash
./apsp testcases/1.in
```

评分时将使用隐藏测试用例；请确保您的解决方案能处理边界情况和大图。

---

### 输入格式

* 图是有向的，边权为非负数
* 所有值都是**32位整数**（在C/C++中使用`int`）
* 前两个整数是顶点数和边数：$(V, E)$
* 然后是$E$条边；每条边由三个整数给出：

$$
\mathrm{src}_i\ \ \mathrm{dst}_i\ \ \mathrm{w}_i \quad\text{for } i=0,1,\dots,E-1 .
$$

* 顶点ID为$0,1,\dots,V-1$

**示例**

```
2 1
0 1 5
```

**约束条件**

* $2 \le V \le 40{,}000$
* $0 \le E \le V \times (V-1)$
* $0 \le \mathrm{src}_i, \mathrm{dst}_i < V$
* $\mathrm{src}_i \ne \mathrm{dst}_i$（输入中没有自环）
* 如果$\mathrm{src}_i=\mathrm{src}_j$则$\mathrm{dst}_i \ne \mathrm{dst}_j$（相同源和目标的边不重复）
* $0 \le \mathrm{w}_i \le 1000$

---

### 输出格式

您必须向**标准输出**打印$V^2$个整数，表示距离矩阵$D$，其中：

$$
D[i,j] = d(i,j)
$$

是从顶点$i$到顶点$j$的最短路径距离。

* 距离必须按**源顶点的行优先顺序**打印：

$d(0,0),\, d(0,1),\, \ldots,\, d(0,V-1);\quad
d(1,0),\, \ldots,\, d(1,V-1);\quad \ldots;\quad
d(V-1,0),\, \ldots,\, d(V-1,V-1).$

* 对角线条目必须满足：

$$
d(i,i) = 0 \quad \forall\, i .
$$

* 如果从$i \to j$**没有路径**，输出：

$$
d(i,j) = 2^{30} - 1 = 1073741823 .
$$

**示例**

```
0 5
1073741823 0
```

---

## 提交

您提交的文件夹必须命名为`apsp`：

包含所有必需的源文件（`main.cpp`, `main.h`, `Makefile`），以便可以直接用以下命令构建：

```bash
make
```

评分器将使用以下命令测试：

```bash
cd $HOME/hip_programming_contest/apsp
make
./apsp <hidden_testcase.txt>
```

确保您的程序按指定格式读取输入，并按要求的顺序精确打印$V^2$个整数。

---

## 提示：分块Floyd-Warshall算法
设$B$为块大小。$V \times V$距离矩阵被划分为$\lceil V/B \rceil \times \lceil V/B \rceil$个大小为$B \times B$的方形瓦片。

对于每个块索引$k$（从$0$到$\lceil V/B \rceil - 1$）：

1. **更新主块**$(k,k)$ — 计算主块内的最短路径，将块内顶点作为中间点
2. **更新主行和主列块** — 使用新计算的主块距离更新同行或同列的块中的距离
3. **更新剩余块**$(i,j)$ — 对于所有$i \ne k$和$j \ne k$，更新：

$$
D_{i,j} \leftarrow \min\!\bigl(D_{i,j},\ D_{i,k} + D_{k,j}\bigr)
$$

这里$D_{i,k}$和$D_{k,j}$来自更新后的主行/列瓦片。

这种分块通过在移动之前多次重用子矩阵来减少缓存未命中，相比朴素Floyd-Warshall算法提高了性能。

---
