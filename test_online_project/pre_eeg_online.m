
% function processed_data = pre_eeg_online(raw_data)
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
% %     EEG = filterEEG(EEG, [1 40], 'bandpass');  % 明确指定阶数
%     
%     % 3. 50Hz陷波滤波
% %     EEG = filterEEG(EEG, [49 51], 'stop');     % 4阶
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
% %     EEG = pop_rmbase(EEG, baseline_window * 1000); % 转为毫秒
%     
%     %% 匹配离线数据结构
%     % 离线数据维度：1000×59×60 → 在线调整为1000×59×1
%     processed_data = struct();
%     processed_data.data = permute(EEG.data, [2, 1, 3]);  % 转置为 [1000×59×1]
%     processed_data.sampleRate = 250;
%     processed_data.labels = 1;          % 模拟标签（根据实际任务修改）
% end


% function processed_data = pre_eeg_online(raw_data)
%     % 输入：raw_data [59通道 × 4000样本] (4秒@1000Hz)
%     % 输出：processed_data 结构体，包含 data [1000×59×1], labels, sampleRate=250
%     assert(size(raw_data,2) == 4000, '输入数据长度必须为4000点(4秒@1000Hz)');
%     
%     %% 初始化EEGLAB结构体
%     EEG = eeg_emptyset();
%     EEG.data = raw_data;               % 原始数据 59×4000
%     EEG.srate = 1000;  
%     EEG.pnts = size(raw_data, 2);
%     EEG.xmax = EEG.pnts / EEG.srate;  % 原始采样率
%     EEG.nbchan = size(raw_data, 1);   % 59通道
%     EEG.trials = 1;
%     EEG.xmin = 0;                     % 4秒
%     
%     %% 严格对齐离线流程
%     % 1. 降采样至250Hz → 59×1000
%     EEG = pop_resample(EEG, 250);     % 输出 59×1000
%     
%     % 2. 带通滤波 (1-40Hz, 4阶巴特沃斯)
%     EEG = pop_eegfiltnew(EEG, 'locutoff',1, 'hicutoff',40); % 使用零相位滤波
%     
%     % 3. 50Hz陷波滤波
%     EEG = pop_eegfiltnew(EEG, 'locutoff',49, 'hicutoff',51, 'revfilt',1); % 使用零相位滤波
% 
% 
%     EEG.srate = 250;  
%     EEG.pnts = size(EEG.data, 2);
%     EEG.xmax = EEG.pnts / EEG.srate;
%     
%     % 4. 全脑平均重参考
%     EEG = pop_reref(EEG, []);
%     
%     % 5. 基线校正（对齐离线逻辑：使用前2秒作为基线）
%     baseline_window = [0 2];            % 0-2秒为基线
%     EEG = pop_rmbase(EEG, baseline_window * 1000); % 转为毫秒
%     
%     %% 匹配离线数据结构
%     % 离线数据维度：1000×59×60 → 在线调整为1000×59×1
%     processed_data = struct();
%     processed_data.data = permute(EEG.data, [2, 1, 3]);  % 转置为 [1000×59×1]
%     processed_data.sampleRate = 250;
%     processed_data.labels = 1;          % 模拟标签(用不着无所谓)
% end   

% function processed_data = pre_eeg_online(raw_data)
%     % 精简版EEGLAB结构体初始化
%     EEG = struct('data', raw_data, 'srate', 1000, 'pnts', size(raw_data,2),...
%         'nbchan', size(raw_data,1), 'trials',1, 'xmin',0, 'xmax', size(raw_data,2)/1000);
%     
%     % 预计算滤波器系数（避免重复设计）
%     persistent resampleFilter bpFilter notchFilter
%     if isempty(resampleFilter)
%         resampleFilter = designfilt('lowpassfir', 'PassbandFrequency',125,...
%             'StopbandFrequency', 150, 'SampleRate',1000, 'DesignMethod','kaiserwin');
% %         bpFilter = designfilt('bandpassiir', 'FilterOrder',4,...
% %             'HalfPowerFrequency1',1, 'HalfPowerFrequency2',40, 'SampleRate',250);
%         bpFilter = designfilt('bandpassiir', 'FilterOrder',4,...
%             'HalfPowerFrequency1',8, 'HalfPowerFrequency2',40, 'SampleRate',250);
%         notchFilter = designfilt('bandstopiir','FilterOrder',4,...
%             'HalfPowerFrequency1',49, 'HalfPowerFrequency2',51, 'SampleRate',250);
%     end
%     
%     % 1. 降采样 (使用预设计滤波器)
%     EEG.data = filtfilt(resampleFilter, EEG.data')'; % 需要转置适应滤波器
%     EEG.data = EEG.data(:, 1:4:end);
%     EEG.srate = 250;
%     
%     % 2. 带通滤波
%     EEG.data = filtfilt(bpFilter, EEG.data')'; 
%     
%     % 3. 陷波滤波
%     EEG.data = filtfilt(notchFilter, EEG.data')';
%     
%     % 4. 平均参考
%     EEG.data = EEG.data - mean(EEG.data, 1);
% 
%     % 5. 基线校正（直接矩阵运算）
% %     baseline = mean(EEG.data(:,1:500), 2); % 前2秒@250Hz
% %     EEG.data = EEG.data - baseline;
% 
%     baseline_start = max(1, size(EEG.data,2) - 250); % 取最后 1s 作为基线
%     baseline = mean(EEG.data(:, baseline_start:end), 2);
%     EEG.data = EEG.data - baseline;    
% 
% 
%     processed_data = permute(EEG.data, [2,1,3]);
% end
function processed_data = pre_eeg_online(raw_data)
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