# MI-BCI-online
基于运动想象的在线脑机接口

1、滑动窗口实现滑动12分钟的实验数据

2、人机交互界面、在线实验范式（可不同程序）

四分类：

验证离线模型、数据



## git 更新代码

**后续代码更新提交**

当你更新代码后，可以按照以下流程提交代码到 GitHub：

1. **查看当前仓库状态**

   ```bash
   git status
   ```

   这会显示哪些文件被修改、添加或删除。

2. **添加修改的文件**

   ```bash
   git add .
   ```

   或者只添加特定文件：

   ```bash
   git add filename.py
   ```

3. **提交代码**

   ```bash
   git commit -m "描述本次修改内容"
   ```

4. **推送到 GitHub**

   ```bash
   git push origin main
   ```

   这样你的代码就会更新到远程仓库。

------

**回退到某个版本**

Git 允许你回退到历史版本，具体方式如下：

**1. 查看提交历史**

```bash
git log --oneline
```

你会看到类似这样的输出：

```
a1b2c3d 修复数据处理 bug
f4e5d6c 添加新的特征提取方法
d7f8g9h 初始提交
```

每个提交都有一个唯一的哈希值（如 `a1b2c3d`）。

**2. 软回退（仅回退 commit，不影响代码文件）**

如果你只是想撤销 `git commit` 但不影响文件：

```bash
git reset --soft HEAD~1
```

这会回退到上一个提交，但文件的更改仍然保留，你可以重新提交。

**3. 硬回退（回退到某个版本，删除之后的提交记录）**

如果你想彻底回退到某个版本：

```bash
git reset --hard a1b2c3d
```

这会将你的仓库回退到 `a1b2c3d` 这个版本，所有之后的更改都会被删除。

**4. 回退到某个版本但保留更改**

如果你想回退，但希望保留代码变更：

```bash
git reset --mixed a1b2c3d
```

这样 Git 只回退 `commit`，但不会丢失代码，你可以重新修改并提交。

**5. 强制推送回退后的版本**

如果你已经推送到了远程仓库，并且想同步回退：

```bash
git push --force origin main
```

⚠ **注意**：强制推送会覆盖远程仓库，需谨慎操作。

------

**解决冲突**

当你在执行 `git pull` 时，如果本地修改与远程代码有冲突，你会看到类似这样的错误：

```
CONFLICT (content): Merge conflict in filename.py
Automatic merge failed; fix conflicts and then commit the result.
```

**1. 查看冲突文件**

```bash
git status
```

Git 会列出冲突的文件，例如：

```
both modified:   filename.py
```

**2. 手动解决冲突**

打开冲突的文件，会看到类似这样的内容：

```python
<<<<<<< HEAD
print("本地代码")
=======
print("远程代码")
>>>>>>> origin/main
```

- `HEAD` 部分是你本地的代码
- `origin/main` 是远程仓库的代码
- 你需要手动修改代码，保留正确的版本。

**3. 标记冲突已解决**

解决冲突后，运行：

```bash
git add filename.py
git commit -m "解决 filename.py 冲突"
```

**4. 继续合并**

如果是 `git pull` 触发的冲突，解决后执行：

```bash
git pull --rebase
```

然后再推送：

```bash
git push origin main
```

------

**2. 如果本地已经有仓库（更新代码）**

如果你已经在 `formal_project` 目录下，并且想同步远程仓库的最新代码：

```
bash


复制编辑
git pull origin main
```

这样，你本地的 `main` 分支就会获取并合并远程仓库的最新更新。

------

**3. 处理可能的冲突**

如果 `git pull` 失败，可能会遇到冲突。这时，你可以：

1. **查看冲突文件**：

   ```
   bash
   
   
   复制编辑
   git status
   ```

   Git 会显示哪些文件有冲突。

2. **手动解决冲突**： 打开有冲突的文件，手动修改冲突部分，然后运行：

   ```
   bash复制编辑git add .
   git commit -m "解决冲突"
   ```

3. **完成合并后推送**：

   ```
   bash
   
   
   复制编辑
   git push origin main
   ```

```matlab
classdef DataServer < handle
%
% Syntax:  
%     
%
% Inputs:
%     
%
% Outputs:
%     
%
% Example:
%     
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% Author: Xiaoshan Huang, hxs@neuracle.cn
%
% Versions:
%    v0.1: 2016-11-02, orignal
%
% Copyright (c) 2016 Neuracle, Inc. All Rights Reserved. http://neuracle.cn/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Constant)
        updateInterval = 0.08; % 40ms
    end
    
    properties
        nChan;
        sampleRate;
        TCPIP;
        dataParser;
        ringBuffer;
        processingQueue = parallel.pool.DataQueue; % 新增异步处理队列
    end
    
    methods
        
        function obj = DataServer(device, nChan, ipAddress, serverPort, sampleRate, saveData_flag,bufferSize)
%             obj.pkgCount=0;
            if nargin < 7
                bufferSize = 5;
            end
            
            obj.nChan = nChan;
            obj.sampleRate = sampleRate;
            
            obj.ringBuffer = RingBuffer(bufferSize, 0);
            obj.dataParser = DataParser(device, obj.nChan,saveData_flag);
            obj.TCPIP = tcpip(ipAddress, serverPort);
            

            obj.TCPIP.InputBufferSize = obj.updateInterval*4*30*1000*10;
            obj.TCPIP.TimerPeriod = obj.updateInterval;
            obj.TCPIP.TimerFcn = {@timerCallBack,obj.TCPIP, obj.dataParser, obj.ringBuffer};
            backgroundWorker = parfeval(@asyncProcessingLoop, 0, obj.processingQueue);
        end
        
        function Open(obj)
            fopen(obj.TCPIP);
            afterEach(obj.processingQueue, @(data) handleProcessedData(data));
        end
        
        function Close(obj)
            fclose(obj.TCPIP);

        end
        
        function [data,Trigger,TS_Out,TS_Out_Trigger] = GetBufferData(obj)
            [data,Trigger,TS_Out,TS_Out_Trigger] = obj.ringBuffer.GetRingbuffer;
        end

        function [data,Trigger,TS_Out,TS_Out_Trigger] = GetLatestData(obj)
            [data,Trigger,TS_Out,TS_Out_Trigger] = obj.ringBuffer.GetLatestRingbuffer;
        end
        function ResetnUpdate(obj)
            obj.ringBuffer.ResetnUpdate;
        end
        
        function [nUpdate]=GetnUpdate(obj)
            nUpdate=obj.ringBuffer.nUpdate;
        end
        function ClearTrigger(obj, idxSensor)
            obj.ringBuffer.ClearTrigger(idxSensor);%仅删除第一个受试中的trigger
        end
        
        function [Metadata] = GetMetaData(obj)
            Metadata = obj.dataParser.MetaData_MSG_Jellyfish;
        end
        function [DataMessage] = GetDataMessage(obj)
            %提供用户使用的简化后的信息
            Metadata = obj.dataParser.MetaData_MSG_Jellyfish;
            subject_unique=Metadata(1).SubjectUnique;
            for idx_subject=1:length(subject_unique)
                subject_loc=find(strcmp({Metadata.PersonName},subject_unique{idx_subject})==1);
                sensorName_all=Metadata(subject_loc(1)).SensorName_sort(1,:);
                sensorSrate_all=Metadata(subject_loc(1)).SensorName_sort(2,:);
                sensorChannelName_all=Metadata(subject_loc(1)).ChannelName_sort(1,:);
                
                DataMessage(idx_subject).SubjectName=subject_unique{idx_subject};
                DataMessage(idx_subject).SensorName=sensorName_all;
                DataMessage(idx_subject).SensorSrate=sensorSrate_all;
                DataMessage(idx_subject).SensorChannelName=sensorChannelName_all;
            end
        end
        
        
        
    end
    
end

% 异步处理函数
function asyncProcessingLoop(queue)
    while true
        raw = poll(queue, inf); % 阻塞等待新数据
        eegStruct = pre_online(raw); % 调用优化后的预处理
        send(queue, eegStruct); % 返回处理结果
    end
end

% 处理完成回调
function handleProcessedData(eegStruct)
    assignin('base', 'latestProcessedData', eegStruct); % 存储到工作区
end

function timerCallBack(obj, event,TCPIP_in, dataParser, ringBuffer)
    if obj.BytesAvailable > 0
        raw = fread(obj, obj.BytesAvailable, 'uint8');
        dataParser.WriteData(raw,TCPIP_in, ringBuffer); 
    end
end


```

```matlab
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
    fopen(serConn);
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
```

