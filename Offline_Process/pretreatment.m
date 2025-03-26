%% 
clear;clc;

addpath('E:\桌面\BCI_Project\EEG_Data\Raw_data\fangfang')
addpath('D:\Neuro\neuracle-eegfile-reader-master')


%% 导入数据
[filename, pathname] = uigetfile({'*.bdf';'*.*'}, '请选择需要转换的文件','MultiSelect', 'on');
disp('importing');
try
    EEG = readbdfdata(filename, pathname);
catch Exception
    if (strcmp(Exception.identifier,'MATLAB:UndefinedFunction'))
        error('Please confirm your eeglab path is contained for matlab')
    end
end 
disp('import finish');
%% 数据预处理

% EEG = pop_resample( EEG, 250);   %降采样
% EEG = filterEEG(EEG, [1 40], 'bandpass'); %4阶巴特沃斯带通滤波器
% EEG = filterEEG(EEG, [49 51], 'stop');  %50 Hz陷波滤波器  
%% epoch
EEG = pop_epoch(EEG, {5}, [0 10]); % 以事件5为中心，时间窗口从0s到10s
%% 将原始数据、事件标签读取出来根据triggerbox标注的event标签进行切割操作
EEG_origin = EEG.data;
EEG_event = EEG.event;
disp('spliceing');
EEG_S = EEG_splice(EEG_origin,EEG_event);
EEG.data = EEG_S.data;
EEG.labels = EEG_S.labels';
%% 往结构体当中添加必要的字段、基线校正
EEG.trials = size(EEG.data, 3);  % 试验个数
EEG.xmin = 0;  % 设置xmin
EEG.pnts = size(EEG.data, 2);  % 数据点数量
EEG.srate = 1000;  % 设置采样率
EEG.xmax = EEG.pnts / EEG.srate;  % xmax根据采样率计算
EEG = eeg_checkset( EEG );%检查EEG结构体
% EEG = pop_rmbase(EEG, [0 4000]);%基线矫正
% EEG = pop_reref( EEG, []);    %全脑平均重参考 ，在ICA之前

%% 保存
start_time = 2;  % 提取MI，开始时间在第4s
end_time = 6;    % 结束时间在第8s
start_sample = round(start_time * EEG.srate);  % MI开始采样点
end_sample = round(end_time * EEG.srate);  % MI结束采样点
data = EEG.data(:, (start_sample+1):end_sample, :);
data_transformed = [];
data_transformed = permute(data, [2, 1, 3]);
data = double(data_transformed);
data = double(data);
sampleRate = EEG.srate;
labels = EEG.labels; 
matFileName = 'CQQ_newnopre_test06.mat';  
filePath = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\CQQ\nopre';  
matFilePath = fullfile(filePath, matFileName);
save(matFilePath, 'data', 'sampleRate','labels');
disp(['数据已成功保存为: ', matFilePath]);