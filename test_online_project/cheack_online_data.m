clc;


%加载数据
scriptDir = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun';
dataPath = fullfile(scriptDir, 'yun_pre_04.mat'); 
load(dataPath);
X_test = double(data); % 训练集pre_A01.mat
Y_test = labels - 2;        % 训练集标签

%加载模型与参数
model_dir = 'E:\桌面\BCI_Project\formal_project\Offline_model_data';
load(fullfile(model_dir,'MI_BCI_TWO_model.mat'), 'model');
load(fullfile(model_dir,'FBCSP_ProcessData.mat'), 'rank', 'proj', 'classNum');

% 参数设置
CSPm = 2;        % 定义 CSP-m 参数
sampleRate = 250;
k = 30;           % 定义 Mutual Select K 值
freq = [4 10 16 22 28 34 40]; % 子频带频率
m = 2;         

%检查数据
disp('检查训练数据是否有NaN/Inf:');
disp(['数据中NaN数量: ', num2str(sum(isnan(X_test(:))))]);
disp(['数据中Inf数量: ', num2str(sum(isinf(X_test(:))))]);
disp(['标签范围: ', num2str(unique(Y_test)')]); % 应为 [1 2] 或 [0 1]

% 测试集处理
fbtestf = FBCSPOnline(X_test(:,:,:), proj, classNum, sampleRate, CSPm, freq);
selFeaTest = fbtestf(:, rank(1:k, 2)); 


%% 预测并输出结果
predictlabel = predict(model, selFeaTest);
ac_1 = sum(predictlabel == Y_test) / numel(Y_test) * 100;
fprintf('分类准确率是%6.2f%%\n', ac_1);