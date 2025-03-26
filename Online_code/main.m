%% 系统初始化
clear; clc; close all; instrreset;

%% 串口初始化
% 串口编号，需要从设备管理器中的COM号获知
HC_ClearCOM;
serPort = 'COM16';
% 通讯的波特率，固定值
baudrate = 9600;
% 新建一个串口对象
serConn = serial(serPort,'BaudRate',baudrate,'Timeout',5,'DataBits',8,...
    'StopBits',1,'Parity','none','OutputBufferSize',1024,'InputBufferSize',1024);

% 打开串口
try
    fopen(serConn);s
catch e
    msgbox('串口打开失败');
    return;
end
disp('串口连接完成。。。。。。。');
disp('TCP连接ing。。。。。。');



%%
current_script_path = mfilename('fullpath'); % 自动获取当前脚本的完整路径
current_folder = fileparts(current_script_path); % 提取所在目录
project_root = fileparts(current_folder);
% 添加必要的子目录
addpath(fullfile(project_root, 'FBCSP'));
addpath(fullfile(project_root, 'Offline_Process'));

%% 脑机设备配置
deviceName = 'JellyFish';          
nChan = 0;                         % 通道数自动获取
srate = 0;                         % 采样率自动获取
subject_toshow = 'FangYunMeng';     % 受试者名称
sensor_toshow = 'EEG';              % 目标传感器类型
nDevice = 1;                       % 设备编号
ipData = '127.0.0.1';               % 数据服务器IP
portData = 8712;                    % 数据服务器端口

%% 用户定义的通道列表（需验证是否存在于实际数据流中）
channel_toshow = {'Fpz', 'Fp1', 'Fp2', 'AF3', 'AF4', 'AF7', 'AF8', 'Fz', 'F1', ...
             'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'FCz', 'FC1', ...
             'FC2', 'FC3', 'FC4', 'FC5', 'FC6', 'FT7', 'FT8', 'Cz', ...
             'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'T7', 'T8', 'CP1', ...
             'CP2', 'CP3', 'CP4', 'CP5', 'CP6', 'TP7', 'TP8', 'Pz', ...
             'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'POz', 'PO3', 'PO4', ...
             'PO5', 'PO6', 'PO7', 'PO8', 'Oz', 'O1', 'O2'};

%% 初始化数据服务器
try
    dataServer = DataServer(deviceName, nChan, ipData, portData, srate, 0, 5); % 保留5秒缓冲区（仅用于数据接收）
    dataServer.Open();
    pause(2); % 等待连接稳定
    
    % 获取通道信息
    DataMessage = dataServer.GetDataMessage();
    
    % 找到目标受试者
    idx_subject = find(contains({DataMessage.SubjectName}, subject_toshow));
    if isempty(idx_subject)
        error('未找到受试者: %s', subject_toshow);
    end
    
    % 找到目标传感器 (EEG)
    sensor_list = DataMessage(idx_subject).SensorName;
    idx_sensor = find(strcmp(sensor_list, sensor_toshow));
    if isempty(idx_sensor)
        error('未找到传感器: %s', sensor_toshow);
    end
    
    % 提取实际通道列表
    all_channels = DataMessage(idx_subject).SensorChannelName{1, idx_sensor};
    disp('=======================');
    disp('【实际通道列表】');
    disp(all_channels);
    
    %验证用户配置的通道是否存在
    [~, idx_chan] = ismember(channel_toshow, all_channels);
    missing_channels = channel_toshow(idx_chan == 0);
    
    if ~isempty(missing_channels)
        disp('=======================');
        disp('【错误】以下通道未找到:');
        disp(missing_channels);
    else
        disp('=======================');
        disp('【成功】所有配置通道均存在!');
    end
    
catch ME
    disp('程序终止:');
    disp(ME.message);
    
    % 确保关闭连接
    if exist('dataServer', 'var')
        dataServer.Close();
    end
    return;
end

%% 调用离线保存的model和参数

loadDir =   'E:\桌面\BCI_Project\formal_project\Offline_model_data';
load(fullfile(loadDir,'MI_BCI_TWO_model.mat'), 'model');          % 加载分类模型
load(fullfile(loadDir, 'FBCSP_ProcessData.mat'), 'rank', 'proj', 'classNum'); 

% 算法参数
k = 30;       % 特征选择数量
freq = [4 10 16 22 28 34 40]; % 子频带划分
m = 2;     % CSP参数
% classNum = 4;   % 类别数 (来自离线训练中的classNum)
%% 实时处理参数初始化
srate_actual = DataMessage(idx_subject).SensorSrate{idx_sensor}; % 实际采样率
assert(srate_actual == 1000, '【错误】实际采样率异常: %d Hz', srate_actual); % 验证采样率必须为1000Hz
fprintf('实际采样率验证通过: %d Hz\n', srate_actual); % 调试输出

nChannels = length(idx_chan);    % 通道数
fprintf('实际采样率: %d Hz, 使用通道数: %d\n', srate_actual, nChannels);

% 初始化滤波器状态（维护滤波连续性）
filter_states = struct(); 
buffer_size = 4 * srate_actual;  % 4秒数据
persistent_data_buffer = [];     % 动态缓冲区初始化

%发送信号相关
buffer = struct('labels', [], 'confidences', []);
loopCounter = 0;
sendInterval = 3;  % 4秒 / 0.2秒 = 20次循环

disp('连接完成！实验开始。。。。。。。。');

try
    dataServer.ResetnUpdate(); % 重置数据流
    
    % 初始化异步处理标志
    lastProcessedTime = 0;  % 记录上次处理完成时间
    processingDelay = 0;    % 处理延迟监控
    
    while true
        t_start = tic; 
        
        %% ==== 核心处理流程 ====
        % 1. 获取最新原始数据块
        [raw_data, ~, ~] = dataServer.GetLatestData();
        valid_data_cell = raw_data{idx_sensor, idx_subject}; 
        
        if ~isempty(valid_data_cell)
            %% 2. 发送到异步队列
            current_data = valid_data_cell(idx_chan, :); % 提取目标通道
            
            % 添加时间戳用于延迟监控
            data_pkg = struct();
            data_pkg.timestamp = now; % 记录当前系统时间
            data_pkg.data = current_data;
            
            send(dataServer.processingQueue, data_pkg); % 发送含时间戳的数据包
            
            %% 3. 检查处理结果
            if evalin('base', 'exist(''latestProcessedData'', ''var'')')
                % 从基础工作区获取处理结果
                processed_pkg = evalin('base', 'latestProcessedData');
                evalin('base', 'clear latestProcessedData'); 
                
                % 计算处理延迟（单位：秒）
                processingDelay = (processed_pkg.timestamp - data_pkg.timestamp)*86400; 
                fprintf('处理延迟: %.2f ms\n', processingDelay*1000);
                
                %% 4. 特征提取与分类
                processed_data = processed_pkg.data; % 提取预处理后的数据
                
                % 转置为 [时间点 × 通道]
                processed_data_transposed = processed_data'; 
                
                % 特征提取 (使用离线训练的proj和rank参数)
                features = FBCSPOnline(...
                    processed_data_transposed, proj, classNum, 250, m, freq); 
                
                % 特征选择
                selFeaTest = features(:, rank(1:k, 2));    
                
                %% 5. 分类决策
                [predictlabel, scores] = predict(model, selFeaTest);
                confidence = max(scores, [], 2);
                [buffer, loopCounter] = update_buffer_and_send(...
                    buffer, loopCounter, predictlabel, confidence, serConn, sendInterval);
                % 显示结果（可替换为实际反馈逻辑）
                fprintf('[%s] 类别: %d | 置信度: %.2f\n',...
                    datestr(now,'HH:MM:SS.FFF'), predictlabel, confidence);
                
                % 更新上次处理时间
                lastProcessedTime = toc(t_start); 
            end
        end
        
        %% 6. 延迟控制（动态调整）
        elapsed = toc(t_start); 
        target_interval = 0.2; % 200ms周期
        
        % 根据处理延迟动态调整等待时间
        if processingDelay > 0.1 % 延迟超过100ms
            target_interval = target_interval * 0.9; % 加快10%
        else
            target_interval = 0.2; % 恢复默认
        end
        
        pause(max(target_interval - elapsed, 0.01)); % 最小休眠10ms
    end

catch ME
    disp('程序终止:');
    disp(ME.message);
    dataServer.Close();
    return;
end

%% 清理
dataServer.Close();
disp('=======================');
disp('测试完成，连接已关闭.');