function [preprocess_eeg, filter_states] = pre_eeg_online(raw_data, srate_original, filter_states)
    % 输入参数校验
    assert(srate_original > 0, '原始采样率必须 > 0');
    assert(size(raw_data,2) == 4000, '输入数据必须为4秒长度');

    target_srate = 250;  % 目标采样率固定为250Hz
    [n_channels, ~] = size(raw_data);
    
    % --- 初始化滤波器 ---
    if isempty(filter_states) || ~isfield(filter_states, 'antialias_b')
        % 抗混叠滤波器 (截止频率125Hz)
        antialias_freq = 125/(srate_original/2);
        assert(antialias_freq > 0 && antialias_freq < 1, '抗混叠频率异常: %.2f', antialias_freq);
        [filter_states.antialias_b, filter_states.antialias_a] = butter(4, antialias_freq, 'low');
        
        % 带通滤波器 (1-40Hz) - 与离线处理一致
        bp_low = 1/(target_srate/2);
        bp_high = 40/(target_srate/2);
        assert(bp_low > 0 && bp_high < 1, '带通频率异常: [%.2f, %.2f]', bp_low, bp_high);
        [filter_states.bp_b, filter_states.bp_a] = butter(4, [bp_low, bp_high], 'bandpass');
        
        % 陷波滤波器 (49-51Hz) - 与离线处理一致
        notch_low = 49/(target_srate/2);
        notch_high = 51/(target_srate/2);
        assert(notch_low > 0 && notch_high < 1, '陷波频率异常: [%.2f, %.2f]', notch_low, notch_high);
        [filter_states.notch_b, filter_states.notch_a] = butter(4, [notch_low, notch_high], 'stop');
        
        % 初始化滤波器状态变量
        filter_states.antialias_zi = zeros(max(length(filter_states.antialias_b), length(filter_states.antialias_a))-1, n_channels);
        filter_states.bp_zi = zeros(max(length(filter_states.bp_b), length(filter_states.bp_a))-1, n_channels);
        filter_states.notch_zi = zeros(max(length(filter_states.notch_b), length(filter_states.notch_a))-1, n_channels);
    end
    
    % --- 数据转置为 [时间点 × 通道] ---
    raw_data = raw_data';
    
    % --- 抗混叠滤波 + 降采样 ---
    [filtered_antialias, filter_states.antialias_zi] = filter(...
        filter_states.antialias_b, filter_states.antialias_a, raw_data, filter_states.antialias_zi, 1);
    downsampled_data = filtered_antialias(1:4:end, :);  % 降采样
    
    % --- 带通滤波 (使用零相位滤波) ---
    filtered_bp = filtfilt(filter_states.bp_b, filter_states.bp_a, downsampled_data);
    
    % --- 陷波滤波 (使用零相位滤波) ---
    filtered_notch = filtfilt(filter_states.notch_b, filter_states.notch_a, filtered_bp);
    
    % --- 基线校正 (使用前2秒数据作为基线) ---
    baseline_samples = round(2 * target_srate); % 2秒基线样本数
    if size(filtered_notch, 1) >= baseline_samples
        baseline_mean = mean(filtered_notch(1:baseline_samples, :), 1);
        baseline_corrected = filtered_notch - baseline_mean;
    else
        baseline_corrected = filtered_notch;
    end
    
    % --- 全脑平均参考 ---
    avg_ref = mean(baseline_corrected, 2);
    referenced_data = baseline_corrected - avg_ref;
    
    % --- 输出转置回 [通道 × 时间点] ---
    preprocess_eeg = referenced_data';
end