function processed_data = pre_eeg_offline(raw_data, origin_rate, target_rate)
    assert(size(raw_data,2) == 4000, '输入数据长度必须为4000点(4秒@1000Hz)');
    
    %% 初始化EEGLAB结构体
    EEG = eeg_emptyset();
    EEG.data = raw_data;
    EEG.srate = origin_rate;
    EEG.nbchan = size(raw_data,1);
    EEG.pnts = size(raw_data,2);
    EEG.trials = 1;
    
    %% 处理流程
    % 1. 50Hz陷波滤波（使用零相位）
    EEG = pop_eegfiltnew(EEG, 'locutoff',49, 'hicutoff',51, 'revfilt',1); % 陷波
    
    % 2. 带通滤波1-40Hz（零相位）
    EEG = pop_eegfiltnew(EEG, 'locutoff',1, 'hicutoff',40); 
    
    % 3. 降采样至250Hz
    EEG = pop_resample(EEG, 250);
    
    % 4. 全脑平均重参考
    EEG = pop_reref(EEG, []);
    
    % 5. 基线校正（按需启用）
    % baseline_window = [0 2];
    % EEG = pop_rmbase(EEG, baseline_window * 1000);
    
    %% 输出
    processed_data = struct();
    processed_data.data = permute(EEG.data, [2,1,3]);
    processed_data.sampleRate = 250;
    processed_data.labels = 1; 
end