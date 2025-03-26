%% 修正版离线验证系统
clear; clc; close all;
rehash ;          

model_dir = 'E:\桌面\BCI_Project\formal_project\Offline_model_data';
%% 数据路径配置

data_dir = 'E:\桌面\BCI_Project\formal_project\test_online_project\yun_sequential_samples'; 

%% 加载模型和参数 (添加错误捕获)
try
    load(fullfile(model_dir, 'MI_BCI_TWO_model.mat'), 'model');
    load(fullfile(model_dir, 'FBCSP_ProcessData.mat'), 'rank', 'proj', 'classNum');
%     load(fullfile(model_dir, 'MI_BCI_FOUR_model.mat'), 'model');
%     load(fullfile(model_dir, 'FBCSP_FOUR_ProcessData.mat'), 'rank', 'proj', 'classNum');
catch ME
    error('模型加载失败: %s\n检查文件是否存在: %s', ME.message, fullfile(model_dir,'MI_BCI_TWO_model.mat'));
end 
disp(['训练时使用的classNum: ', num2str(classNum)]);
%% 算法参数
k = 30;       
freq = [4 10 16 22 28 34 40]; 
m = 2;         
srate_online = 250; 
srate_original = 1000;
%% 数据文件处理 (增强鲁棒性)
file_list = dir(fullfile(data_dir, 'Label*.mat'));
n_files = length(file_list);
assert(n_files > 0, '在目录中未找到数据文件: %s', data_dir);

%% 初始化结果存储
true_labels = zeros(n_files, 1);
pred_labels = zeros(n_files, 1);
confidences = zeros(n_files, 1);
filter_states = struct(); 
%% 主处理循环（关键修改处）
for file_idx = 1:n_files
    tic;
    fprintf('\n==== Processing %d/%d ====\n', file_idx, n_files);
    
    %% 1. 加载数据（修正变量名）
    file_path = fullfile(data_dir, file_list(file_idx).name);
    data_struct = load(file_path, 'sample_data'); % 明确加载sample_data

    % 维度验证与调整
    raw_data = data_struct.sample_data'; % 转置为 [59通道 × 1000时间点]
  
    %% 2. 标签提取（增强可靠性）
    [~, filename] = fileparts(file_list(file_idx).name);
    label_str = regexp(filename, 'Label(\d+)', 'tokens', 'once');
    true_label = str2double(label_str{1});
%     disp(['预处理前：',size(raw_data,1)]);
    %% 3. 预处理（适配离线数据）
    processed_data = pre_eeg_online(raw_data);
%     processed_data = pre_four_online(raw_data); %四分类尝试
%     [processed_data, filter_states] = pre_eeg_online(raw_data,srate_original,filter_states);
%     processed_data  = pre_eeg_offline(raw_data, srate_original,srate_online);
%     %% 4. 特征提取（添加维度验证）
%     processed_data_transposed = processed_data.data; % 转置为 [1000×59]
    processed_data_transposed = processed_data;
    disp(size(processed_data_transposed,2));
    disp(size(proj,1));

    features = FBCSPOnline(processed_data_transposed, proj, classNum, srate_online, m, freq);

  
    %% 5. 分类预测
    selFeaTest = features(:, rank(1:k, 2)); 
    [predictlabel, scores] = predict(model, selFeaTest);
%     selFeaTest_norm = (selFeaTest - train_mean) ./ train_std;%修改点
%     
%     [predictlabel, scores] = predict(model, selFeaTest_norm);


    %% 保存结果
    true_labels(file_idx) = true_label;
    pred_labels(file_idx) = predictlabel;
    confidences(file_idx) = max(scores);
    
    %% 显示进度
    fprintf('[Result] True: %d | Pred: %d | Conf: %.2f | Time: %.2fs\n',...
        true_label, predictlabel, confidences(file_idx), toc);
end

%% 性能评估（处理部分失败样本）
valid_samples = true_labels ~= 0;
fprintf('\n===== Final Results =====\n');
fprintf('Total Files: %d\nValid Samples: %d\n', n_files, sum(valid_samples));
if sum(valid_samples) > 0
    accuracy = mean(true_labels(valid_samples) == pred_labels(valid_samples)) * 100;
    conf_mat = confusionmat(true_labels(valid_samples), pred_labels(valid_samples));
    
    fprintf('Accuracy: %.2f%%\n', accuracy);
    disp('Confusion Matrix:');
    disp(conf_mat);
    
    figure;
    confusionchart(true_labels(valid_samples), pred_labels(valid_samples),...
        'Title', sprintf('Offline Validation (Acc: %.1f%%)', accuracy));
else
    warning('没有有效样本可用于评估');
end



% function processed_data = pre_four_online(raw_data)
%     % 输入：raw_data [59通道 × 4000样本] (4秒@1000Hz)
%     % 输出：processed_data 结构体，包含 data [1000×59×1], labels, sampleRate=250
%     assert(size(raw_data,2) == 4000, '输入数据长度必须为1000点(4秒)');
%     %% 初始化EEGLAB结构体
%     EEG = eeg_emptyset();
%     EEG.data = raw_data;               % 原始数据 59×4000
%     EEG.srate = 1000;  
%     EEG.pnts = size(raw_data, 2);
%     EEG.xmax = EEG.pnts / EEG.srate;                                     % 原始采样率
%     EEG.nbchan = size(raw_data, 1);     % 59通道
%            % 4000样本
%     EEG.trials = 1;
%     EEG.xmin = 0;
%         % 4秒
%     
%     %% 严格对齐离线流程
%     % 1. 降采样至250Hz → 59×1000
%     EEG = pop_resample(EEG, 250);       % 输出 59×1000
%     
%     % 2. 带通滤波 (1-40Hz, 4阶巴特沃斯)
%     EEG = filterEEG(EEG, [1 40], 'bandpass');  % 明确指定阶数
%     
%     %3. 50Hz陷波滤波
%     EEG = filterEEG(EEG, [49 51], 'stop');     % 4阶
%     
%     EEG.srate = 250;  
%     EEG.pnts = size(EEG.data, 2);
%     EEG.xmax = EEG.pnts / EEG.srate;
%     
%     % 4. 全脑平均重参考
%     EEG = pop_reref(EEG, []);
%     
%     % 5. 基线校正（对齐离线逻辑：使用前2秒作为基线）
% %     baseline_window = [0 2];            % 0-2秒为基线
%     EEG = pop_rmbase(EEG, baseline_window * 1000); % 转为毫秒
    
    %% 匹配离线数据结构
    % 离线数据维度：1000×59×60 → 在线调整为1000×59×1
%     processed_data = struct();
%     processed_data.data = permute(EEG.data, [2, 1, 3]);  % 转置为 [1000×59×1]
%     processed_data.sampleRate = 250;
%     processed_data.labels = 1;          % 模拟标签（根据实际任务修改）
%     processed_data = permute(EEG.data, [2, 1, 3]);
% end