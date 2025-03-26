### **1. 使用场景**

#### **第一段代码（`FBCSP` 函数）：**

- 用于 **离线特征提取**。
- 输入的是 **训练数据** 和对应的 **标签**，直接从数据计算 CSP 投影矩阵。
- 适合在数据预处理阶段使用，完成特征提取后用于训练分类器。

#### **第二段代码（`FBCSPOnline` 函数）：**

- 用于 **在线特征提取**。
- 输入的是 **待处理的数据** 和 **已计算的 CSP 投影矩阵**。
- 投影矩阵 `projMAll` 是离线阶段预先计算好的，用于在线处理实时数据或新数据。
- 不需要重新计算 CSP 投影矩阵，直接利用现有矩阵提取特征



### **总结**

| **特点**         | **FBCSP（离线版）**                       | **FBCSPOnline（在线版）** |
| ---------------- | ----------------------------------------- | ------------------------- |
| **场景**         | 离线训练阶段                              | 在线特征提取              |
| **CSP 投影矩阵** | 每次运行重新计算                          | 使用已有的 `projMAll`     |
| **输入数据维度** | 仅支持三维数据 `[q, p, k]`                | 支持二维和三维数据        |
| **计算复杂度**   | 高（包含投影矩阵计算）                    | 低（直接特征提取）        |
| **实时性**       | 不适合实时处理                            | 适合在线或实时处理        |
| **输出**         | `features_train`, `projM_All`, `classNum` | 仅 `features_train`       |

这两个代码可以配合使用：

1. 使用离线版本 `FBCSP` 预先计算 CSP 投影矩阵 `projM_All`。
2. 使用在线版本 `FBCSPOnline` 提取实时数据的特征。



### main

```matlab
% 离线版本：训练 SVM 模型并保存
% 加载训练数据
load('D:\Software\MATLAB\R2019b\bin\workspace\Dataset\BCIIV-2a\BCIIV_2a_mat\changedatashape\pre_A01T3.mat');
X_train = double(data); % 训练集
Y_train = label; % 训练集标签

% 进行 FBCSP 特征提取
CSPm = 2; % 定义 CSP-m 参数
sampleRate = 250;
k = 30; % 定义 Mutual Select K values
freq = [4 10 16 22 28 34 40]; % 设置子频带频率
[FBtrainf, proj, classNum] = FBCSP(X_train, Y_train, sampleRate, CSPm, freq);

% 特征选择
rank = all_MuI(FBtrainf, Y_train);
selFeaTrain = FBtrainf(:, rank(1:k, 2));

% 训练 SVM 模型
model = svmtrain(Y_train, selFeaTrain, '-c 2 -g 0.1250');

% 保存训练好的模型
save('svm_model.mat', 'model');
fprintf('离线训练完成并保存模型\n');

```

```matlab
% 在线版本：加载训练好的 SVM 模型并进行实时预测

% 加载训练好的模型
load('svm_model.mat'); % 假设你已经保存了 'svm_model.mat'

% 假设你有一个实时EEG信号数据流（`newEEGData`）
% 这里是一个示例，表示每次获取一段新的EEG信号

while true
    % 获取实时EEG信号段
    % newEEGData = 获取新的一段EEG数据
    
    % 对新一段数据进行 FBCSP 特征提取
    fbTestf = FBCSPOnline(newEEGData, proj, classNum, sampleRate, CSPm, freq);
    
    % 特征选择：选择与离线训练相同的特征（前k个特征）
    selFeaTest = fbTestf(:, rank(1:k, 2));
    
    % 使用训练好的SVM模型进行预测
    [predictlabel, ac, decv] = svmpredict([], selFeaTest, model); % 无需传入Y值
    fprintf('预测标签：%d，准确率：%6.2f%%\n', predictlabel, ac(1));
    
    % 在此处加入你需要的实时处理逻辑
    % 如果有需要，添加数据存储、报警、结果输出等
end

```

