classdef EEGStreamSimulator < handle
    properties
        FullData        % 完整数据矩阵 [59×N]
        Labels         % 完整标签序列 [1×N]
        Position       % 当前读取位置（样本索引）
        WindowSize     % 滑动窗口大小（样本数）
        StepSize       % 步长（样本数）
        SampleRate     % 采样率
    end
    
    methods
        function obj = EEGStreamSimulator(data, labels, window_sec, step_sec, fs)
            obj.FullData = data;
            obj.Labels = labels;
            obj.WindowSize = window_sec * fs;
            obj.StepSize = step_sec * fs;
            obj.SampleRate = fs;
            obj.Position = 1;
        end
        
        function [data_chunk, label_chunk, has_next] = next(obj)
            % 计算当前窗口边界
            start_idx = obj.Position;
            end_idx = min(start_idx + obj.WindowSize - 1, size(obj.FullData,2));
            
            % 提取数据和标签
            data_chunk = obj.FullData(:, start_idx:end_idx);
            label_chunk = obj.Labels(start_idx:end_idx);
            
            % 更新位置指针
            obj.Position = obj.Position + obj.StepSize;
            
            % 判断是否还有后续数据
            has_next = end_idx < size(obj.FullData,2);
        end
        
        function reset(obj)
            obj.Position = 1;
        end
    end
end