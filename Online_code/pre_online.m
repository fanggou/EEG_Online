% function [preprocess_eeg, filter_states] = pre_online(raw_data, srate_original, filter_states)
%     % 输入参数校验
%     assert(srate_original > 0, '原始采样率必须 > 0');
%     assert(size(raw_data,2) == 4000, '输入数据必须为4秒长度');
% 
%     target_srate = 250;  % 目标采样率固定为250Hz
%     [n_channels, n_samples] = size(raw_data);
%     
%     % --- 初始化滤波器 ---
%     if isempty(filter_states) || ~isfield(filter_states, 'antialias_b')
%         % 抗混叠滤波器 (截止频率125Hz)
%         antialias_freq = 125/(srate_original/2);
%         assert(antialias_freq > 0 && antialias_freq < 1, '抗混叠频率异常: %.2f', antialias_freq);
%         [filter_states.antialias_b, filter_states.antialias_a] = butter(4, antialias_freq, 'low');
%         
%         % 带通滤波器 (8-30Hz)
%         bp_low = 8/(target_srate/2);
%         bp_high = 30/(target_srate/2);
%         assert(bp_low > 0 && bp_high < 1, '带通频率异常: [%.2f, %.2f]', bp_low, bp_high);
%         [filter_states.bp_b, filter_states.bp_a] = butter(4, [bp_low, bp_high], 'bandpass');
%         
%         % 陷波滤波器 (48-52Hz)
%         notch_low = 48/(target_srate/2);
%         notch_high = 52/(target_srate/2);
%         assert(notch_low > 0 && notch_high < 1, '陷波频率异常: [%.2f, %.2f]', notch_low, notch_high);
%         [filter_states.notch_b, filter_states.notch_a] = butter(4, [notch_low, notch_high], 'stop');
%         
%         % 初始化滤波器状态变量
%         filter_states.antialias_zi = zeros(max(length(filter_states.antialias_b), length(filter_states.antialias_a))-1, n_channels);
%         filter_states.bp_zi = zeros(max(length(filter_states.bp_b), length(filter_states.bp_a))-1, n_channels);
%         filter_states.notch_zi = zeros(max(length(filter_states.notch_b), length(filter_states.notch_a))-1, n_channels);
%     end
%     
%     % --- 数据转置为 [时间点 × 通道] ---
%     raw_data = raw_data';
%     
%     % --- 抗混叠滤波 + 降采样 ---
%     [filtered_antialias, filter_states.antialias_zi] = filter(...
%         filter_states.antialias_b, filter_states.antialias_a, raw_data, filter_states.antialias_zi, 1);
%     downsampled_data = filtered_antialias(1:4:end, :);  % 降采样
%     
%     % --- 带通滤波 ---
%     [filtered_bp, filter_states.bp_zi] = filter(...
%         filter_states.bp_b, filter_states.bp_a, downsampled_data, filter_states.bp_zi, 1);
%     
%     % --- 陷波滤波 ---
%     [filtered_notch, filter_states.notch_zi] = filter(...
%         filter_states.notch_b, filter_states.notch_a, filtered_bp, filter_states.notch_zi, 1);
%     
%     % --- 全脑平均参考 ---
%     avg_ref = mean(filtered_notch, 2);
%     preprocess_eeg = (filtered_notch - avg_ref)';
% end
% 


% function processed_data = pre_online(raw_data)
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
% %     EEG = filterEEG(EEG, [1 40], 'bandpass'); %4阶巴特沃斯带通滤波器
% %     EEG = filterEEG(EEG, [49 51], 'stop');  %50 Hz陷波滤波器
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
function processed_data = pre_online(raw_data)
    % 精简版EEGLAB结构体初始化
    EEG = struct('data', raw_data, 'srate', 1000, 'pnts', size(raw_data,2),...
        'nbchan', size(raw_data,1), 'trials',1, 'xmin',0, 'xmax', size(raw_data,2)/1000);
    
    % 预计算滤波器系数（避免重复设计）
    persistent resampleFilter bpFilter notchFilter
    if isempty(resampleFilter)
        resampleFilter = designfilt('lowpassfir', 'PassbandFrequency',125,...
            'StopbandFrequency', 150, 'SampleRate',1000, 'DesignMethod','kaiserwin');
        bpFilter = designfilt('bandpassiir', 'FilterOrder',4,...
            'HalfPowerFrequency1',1, 'HalfPowerFrequency2',40, 'SampleRate',250);
        notchFilter = designfilt('bandstopiir','FilterOrder',4,...
            'HalfPowerFrequency1',49, 'HalfPowerFrequency2',51, 'SampleRate',250);
    end
    
    % 1. 降采样 (使用预设计滤波器)
    EEG.data = filtfilt(resampleFilter, EEG.data')'; % 需要转置适应滤波器
    EEG.data = EEG.data(:, 1:4:end);
    EEG.srate = 250;
    
    % 2. 带通滤波
    EEG.data = filtfilt(bpFilter, EEG.data')'; 
    
    % 3. 陷波滤波
    EEG.data = filtfilt(notchFilter, EEG.data')';
    
    % 4. 平均参考
    EEG.data = EEG.data - mean(EEG.data, 1);
    
    % 5. 基线校正（直接矩阵运算）
    baseline = mean(EEG.data(:,1:500), 2); % 前2秒@250Hz
    EEG.data = EEG.data - baseline;
    
    processed_data = permute(EEG.data, [2,1,3]);
end