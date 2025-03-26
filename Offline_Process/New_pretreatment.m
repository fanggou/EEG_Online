%% 离线预处理（使用在线相同的预处理流程）
clear; clc;

%% 添加必要路径
addpath('E:\桌面\BCI_Project\EEG_Data\Raw_data\fangfang')
addpath('D:\Neuro\neuracle-eegfile-reader-master')

%% 导入bdf数据
[filename, pathname] = uigetfile({'*.bdf';'*.*'}, '请选择需要转换的文件','MultiSelect', 'on');
disp('Importing data...');
try
    EEG = readbdfdata(filename, pathname);
catch Exception
    if strcmp(Exception.identifier, 'MATLAB:UndefinedFunction')
        error('请确认EEGLAB路径已添加到MATLAB中');
    end
end
disp('Import finished.');

%% 事件提取：以事件 '5' 为标记，提取0~10秒的epoch
EEG = pop_epoch(EEG, {'5'}, [0 8]);

%% 根据事件标签和用户选择的通道进行数据切割
EEG_S = EEG_splice(EEG.data, EEG.event);
EEG.data = EEG_S.data;
EEG.labels = EEG_S.labels';

%% 统一预处理方式（调用 pre_eeg_online）
[nchan, pnts, ntrials] = size(EEG.data);
processed_data = zeros(pnts / 4, nchan, ntrials);  % 预分配存储空间（降采样后）

for i = 1:ntrials
    trial_data = double(EEG.data(:,:,i));  % 取当前trial数据
    processed_trial = pre_four_online(trial_data);  % 调用在线预处理
%     processed_trial = trial_data';
    processed_data(:,:,i) = processed_trial;  % 存入数组
end

%% 更新 EEG 结构体信息
EEG.data = processed_data;
EEG.srate = 250;  % 处理后的采样率
EEG.pnts = size(processed_data, 1);
EEG.trials = ntrials;

%% 提取MI时段（例如：从2秒到6秒）
start_time = 2;  
end_time   = 6;  
start_sample = round(start_time * EEG.srate);  % 2*250 = 500
end_sample   = round(end_time * EEG.srate);    % 6*250 = 1500

data_MI = EEG.data(start_sample+1:end_sample, :, :);  % 选取MI时段
data_transformed = permute(data_MI, [1, 2, 3]);  % 转换格式为[通道 × 采样点 × trial]

%% 保存数据
data = double(data_transformed);
sampleRate = EEG.srate;
labels = EEG.labels;

matFileName = 'yun_newpre_test04.mat';  
filePath = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\new';  
matFilePath = fullfile(filePath, matFileName);
save(matFilePath, 'data', 'sampleRate', 'labels');
disp(['数据已成功保存为: ', matFilePath]);

function processed_data = pre_four_online(raw_data)
    % 输入 raw_data：二维数据，尺寸为 [通道×采样点]，采样率1000Hz
    % 输出 processed_data：二维数据，尺寸为 [采样点×通道]，采样率250Hz
    % 精简版EEGLAB结构体初始化
    EEG = struct('data', raw_data, 'srate', 1000, 'pnts', size(raw_data,2),...
        'nbchan', size(raw_data,1), 'trials',1, 'xmin',0, 'xmax', size(raw_data,2)/1000);
    
    % 使用 persistent 避免重复设计滤波器
    persistent resampleFilter bpFilter notchFilter
    if isempty(resampleFilter)
        resampleFilter = designfilt('lowpassfir', 'PassbandFrequency',125,...
            'StopbandFrequency',150, 'SampleRate',1000, 'DesignMethod','kaiserwin');
        bpFilter = designfilt('bandpassiir', 'FilterOrder',4,...
            'HalfPowerFrequency1',8, 'HalfPowerFrequency2',40, 'SampleRate',250);
        notchFilter = designfilt('bandstopiir','FilterOrder',4,...
            'HalfPowerFrequency1',49, 'HalfPowerFrequency2',51, 'SampleRate',250);
    end
    
    % 1. 降采样（使用预设计滤波器）
    EEG.data = filtfilt(resampleFilter, EEG.data')';  % 双向零相位滤波（需转置）
    EEG.data = EEG.data(:, 1:4:end);  % 取每4个采样点 (1000Hz→250Hz)
    EEG.srate = 250;
    
    % 2. 带通滤波（8–40 Hz）
    EEG.data = filtfilt(bpFilter, EEG.data')';
    
    % 3. 陷波滤波（50 Hz）
    EEG.data = filtfilt(notchFilter, EEG.data')';
    
    % 4. 平均参考：减去每个采样点所有通道的均值
    EEG.data = EEG.data - mean(EEG.data, 1);
    
    % 5. 基线校正：取最后1秒（250个采样点）的均值作为基线
    baseline_start = max(1, size(EEG.data,2) - 250);
    baseline = mean(EEG.data(:, baseline_start:end), 2);
    EEG.data = EEG.data - baseline;
    
    % 输出数据转换为【采样点×通道】
    processed_data = permute(EEG.data, [2, 1]);
end

%% 自定义函数：EEG_splice
function [EEG_S, indx] = EEG_splice(EEG_DATA, EEG_EVENT)
    % 通道选择对话框（列表可根据需要调整）
    list = {'Fpz', 'Fp1', 'Fp2', 'AF3', 'AF4', 'AF7', 'AF8', 'Fz', 'F1', ...
            'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'FCz', 'FC1', ...
            'FC2', 'FC3', 'FC4', 'FC5', 'FC6', 'FT7', 'FT8', 'Cz', ...
            'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'T7', 'T8', 'CP1', ...
            'CP2', 'CP3', 'CP4', 'CP5', 'CP6', 'TP7', 'TP8', 'Pz', ...
            'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'POz', 'PO3', 'PO4', ...
            'PO5', 'PO6', 'PO7', 'PO8', 'Oz', 'O1', 'O2', 'ECG', ...
            'HEOR', 'HEOL', 'VEOU', 'VEOL'};
    [indx, tf] = listdlg('PromptString', {'请选择需要提取的通道', ...
        '按住shift区域多选', 'ctrl单个多选'}, 'ListString', list);
    if ~tf
        error('未选择通道，操作已取消。');
    end

    % 参数定义：每个epoch持续10秒（已通过pop_epoch提取）
    target_duration_seconds = 8;  
    srate = 1000;  % 注意：这里数据原始采样率为1000Hz
    duration = target_duration_seconds * srate; 
    EEG_MI = [];
    EEG_labels = [];
    EEG_DATA_FIRST = [];  % 用于存储第一次提取的数据

    % 遍历所有事件，提取事件类型为 '5' 对应的epoch
    for i = 1:length(EEG_EVENT)
        if EEG_EVENT(i).type == '5'
            index_start = EEG_EVENT(i).latency;
            index_end = EEG_EVENT(i).latency + duration - 1;
            if isempty(EEG_MI)
                if ~isempty(EEG_DATA_FIRST)
                    EEG_MI = cat(3, EEG_DATA_FIRST, EEG_DATA(indx, index_start:index_end));
                else
                    EEG_DATA_FIRST = EEG_DATA(indx, index_start:index_end);
                end
            else
                EEG_MI(:, :, end+1) = EEG_DATA(indx, index_start:index_end); 
            end
            % 如果下一个事件存在，将其type转换为数字作为标签
            if i+1 <= length(EEG_EVENT)
                next_event_type = EEG_EVENT(i+1).type;
                EEG_labels(end + 1) = str2double(next_event_type);
            end
        end
    end

    EEG_S = struct();
    EEG_S.data = EEG_MI;
    EEG_S.labels = EEG_labels;
    EEG_S.srate = srate;
end
