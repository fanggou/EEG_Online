% clear;clc;
% 
% addpath('E:\桌面\BCI_Project\EEG_Data\Raw_data\fangfang')
% addpath('D:\Neuro\neuracle-eegfile-reader-master')
% 
% 
% %% 导入数据
% [filename, pathname] = uigetfile({'*.bdf';'*.*'}, '请选择需要转换的文件','MultiSelect', 'on');
% disp('importing');
% try
%     EEG = readbdfdata(filename, pathname);
% catch Exception
%     if (strcmp(Exception.identifier,'MATLAB:UndefinedFunction'))
%         error('Please confirm your eeglab path is contained for matlab')
%     end
% end 
% disp('import finish');
% 
% EEG = pop_epoch(EEG, {5}, [0 8]); % 以事件5为中心，时间窗口从0s到10s
% 
% list = {'Fpz', 'Fp1', 'Fp2', 'AF3', 'AF4', 'AF7', 'AF8', 'Fz', 'F1', ...
%         'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'FCz', 'FC1', ...
%         'FC2', 'FC3', 'FC4', 'FC5', 'FC6', 'FT7', 'FT8', 'Cz', ...
%         'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'T7', 'T8', 'CP1', ...
%         'CP2', 'CP3', 'CP4', 'CP5', 'CP6', 'TP7', 'TP8', 'Pz', ...
%         'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'POz', 'PO3', 'PO4', ...
%         'PO5', 'PO6', 'PO7', 'PO8', 'Oz', 'O1', 'O2', 'ECG', ...
%         'HEOR', 'HEOL', 'VEOU', 'VEOL'};
% [indx, tf] = listdlg('PromptString', {'请选择需要提取的通道', ...
%     '按住shift区域多选', 'ctrl单个多选'}, 'ListString', list);
% if ~tf
%     error('未选择通道，操作已取消。');
% end
% 
% EEG.data = EEG.data(indx, :, :);
% EEG.chanlocs = EEG.chanlocs(indx); % 更新通道信息
% EEG.nbchan = length(indx); % 更新通道数
% 
% data = double(EEG.data);
% sampleRate = EEG.srate;
% labels = {EEG.labels}; % 以 cell 数组形式存储通道标签
% 
% matFileName = 'yun_simulate_04.mat';  
% filePath = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\nopre';  
% matFilePath = fullfile(filePath, matFileName);
% save(matFilePath, 'data', 'sampleRate','labels');
% disp(['数据已成功保存为: ', matFilePath]);


%% save_raw_data.m
clear; clc;
addpath('D:\Neuro\neuracle-eegfile-reader-master');

%% 1. 导入原始EEG数据（无标签处理）
[filename, pathname] = uigetfile({'*.bdf';'*.*'}, '选择BDF文件');
EEG = readbdfdata(filename, pathname); % 仅读取数据，不处理事件

%% 2. 手动通道选择
list = {EEG.chanlocs.labels}; 
[indx, tf] = listdlg('PromptString', {'请选择通道（按住Ctrl多选）'}, 'ListString', list);
if ~tf, error('未选择通道！'); end
data = EEG.data(indx, :, :); % 维度: [通道×时间×试验]

%% 3. 保存为连续数据流
matFileName = 'fang_simulate_03.mat';  
filePath = 'E:\桌面\BCI_Project\EEG_Data\pre_for_mat_data\yunyun\nopre'; 
matFilePath = fullfile(filePath, matFileName);
save(matFilePath, 'data','-v7.3');
% save('raw_eeg_stream.mat', 'data', '-v7.3');
disp('数据已保存: data维度=[通道×时间×试验]');
disp(['数据已成功保存为: ', matFilePath]);



