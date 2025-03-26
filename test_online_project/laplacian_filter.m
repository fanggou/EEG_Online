function EEG_data_filtered = laplacian_filter(EEG_data)
    % EEG_data: 输入EEG数据 (通道 x 采样点)
    % EEG_data_filtered: 经过Laplacian 参考的EEG数据

    [num_channels, num_samples] = size(EEG_data);
    EEG_data_filtered = EEG_data;

    for ch = 1:num_channels
        neighbors = get_neighbors(ch, num_channels);
        
        if ~isempty(neighbors)
            % **中心通道 - 相邻通道均值**
            EEG_data_filtered(ch, :) = EEG_data(ch, :) - mean(EEG_data(neighbors, :), 1);
        end
    end
end


function neighbors = get_neighbors(channel, num_channels)
    % 这里需要根据你的 EEG 电极排列方式来定义相邻通道
    % 以 64 频道标准 10-20 系统为例：
    standard_10_20_neighbors = {
        [2, 3, 8],  % Fpz
        [1, 3, 4, 9],  % Fp1
        [1, 2, 5, 10],  % Fp2
        [2, 9, 11, 6],  % AF3
        [3, 10, 12, 7], % AF4
        [4, 11, 13],  % F3
        [5, 12, 14],  % F4
        % ...
    };

    % 如果当前通道在列表内，返回邻居索引
    if channel <= length(standard_10_20_neighbors)
        neighbors = standard_10_20_neighbors{channel};
    else
        neighbors = [];
    end
end
