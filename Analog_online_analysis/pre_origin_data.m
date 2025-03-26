%% 加载数据
load('E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\fangfang\nopre\fang_nopre_03_online_test.mat'); % 加载 data(59×8000×120), labels(120×1), sampleRate
Fs = sampleRate; % 获取实际采样率

%% 参数设置
prep_sec = 2;      % 准备阶段时长
mi_sec = 4;        % MI阶段时长
rest_sec = 2;      % 休息阶段时长
samples_per_trial = size(data,2); % 8000样本/trial

%% 生成连续数据流和全局标签序列
continuous_data = reshape(data, 59, []); % 59×(8000×120)
label_sequence = [];

for trial = 1:size(labels,1)
    % 当前trial标签序列
    trial_labels = [...
        repmat(5, 1, prep_sec*Fs),...       % 准备阶段
        repmat(labels(trial), 1, mi_sec*Fs),... % MI阶段
        zeros(1, rest_sec*Fs)...            % 休息阶段
    ];
    label_sequence = [label_sequence trial_labels];
end

% 验证数据一致性
assert(size(continuous_data,2) == length(label_sequence), '数据与标签长度不匹配');