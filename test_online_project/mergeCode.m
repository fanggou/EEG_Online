%% 初始化
clear; clc;
[files, path] = uigetfile('*.mat', '选择需要拼接的.mat文件', 'MultiSelect', 'on');
if ischar(files), files = {files}; end  % 统一为cell格式

%% 预加载检查
sampleRate = [];  % 用于验证采样率一致性
all_data = [];
all_labels = [];

for i = 1:length(files)
    % 加载数据
    file_path = fullfile(path, files{i});
    loaded = load(file_path);
    
    % 检查字段是否存在
    if ~isfield(loaded, 'data') || ~isfield(loaded, 'labels') || ~isfield(loaded, 'sampleRate')
        error('文件 %s 缺少 data、labels 或 sampleRate 字段', files{i});
    end
    
    % 验证采样率一致性
    if isempty(sampleRate)
        sampleRate = loaded.sampleRate;
    elseif loaded.sampleRate ~= sampleRate
        error('文件 %s 的 sampleRate 不一致', files{i});
    end
    
    % 检查 data 维度（假设为 [时间点×通道×试次]）
    if ndims(loaded.data) ~= 3
        error('文件 %s 的 data 维度应为 3 维', files{i});
    end
    
    % 拼接数据
    all_data = cat(3, all_data, loaded.data);  % 沿试次维度拼接
    all_labels = [all_labels; loaded.labels];  % 沿行拼接标签
end

%% 保存合并后的数据
data = all_data;
labels = all_labels;
sampleRate = sampleRate;

savepath = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\new';
save_path = fullfile(savepath, 'yun_merged_1_3.mat');
save(save_path, 'data', 'labels', 'sampleRate', '-v7.3');

%% 输出结果
disp('===== 合并结果 =====');
disp(['数据维度: ', num2str(size(data))]);
disp(['标签数量: ', num2str(length(labels))]);
disp(['采样率: ', num2str(sampleRate)]);
disp(['保存路径: ', save_path]);