%% 配置参数
save_dir = 'E:\桌面\BCI_Project\formal_project\test_online_project\yun_sequential_samples';  % 存储目录
if ~exist(save_dir, 'dir') 
    mkdir(save_dir);
end

% 每类取前10个样本

%% 加载数据并验证维度
% load('E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\new\yun_newpre_test04.mat', 'data', 'labels');
% classNum = 4;
% samples_per_class = 15;   

load('E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\nopre\yunyun_nopre_test04.mat', 'data', 'labels');
classNum = 2;
labels = labels - 2;
samples_per_class = 60; 

disp(['原始数据维度: ', mat2str(size(data))]); % 显示 1000×59×240
% 重组数据为 [样本数 × 特征1 × 特征2]
data = permute(data, [3 1 2]); % 新维度: 240×1000×59
assert(size(data,1) == size(labels,1), '样本数不匹配'); % 验证240=240

%% 创建存储目录
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

%% 按类别顺序切割
for target_label = 1:classNum
    % 获取当前类别所有样本索引
    class_idx = find(labels == target_label); % 自动按出现顺序排列
    
    % 取前N个样本（按原始数据顺序）
    selected_idx = class_idx(1:samples_per_class);
    
    % 逐个保存样本
    for i = 1:length(selected_idx)
        sample_data = squeeze(data(selected_idx(i), :, :)); % 提取1000×59矩阵
        
        % 生成文件名（格式：LabelX_OriginalIndexY.mat）
        filename = fullfile(save_dir,...
            sprintf('Label%d_Idx%03d.mat', target_label, selected_idx(i)));
        
        save(filename, 'sample_data');
    end
end

disp(['成功保存 ', num2str(classNum*samples_per_class), ' 个样本']);