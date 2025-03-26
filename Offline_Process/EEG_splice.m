


function [EEG_S, indx] = EEG_splice(EEG_DATA, EEG_EVENT)
    % 通道选择对话框（保持不变）
    list = {'Fpz', 'Fp1', 'Fp2', 'AF3', 'AF4', 'AF7', 'AF8', 'Fz', 'F1', ...
            'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'FCz', 'FC1', ...
            'FC2', 'FC3', 'FC4', 'FC5', 'FC6', 'FT7', 'FT8', 'Cz', ...
            'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'T7', 'T8', 'CP1', ...
            'CP2', 'CP3', 'CP4', 'CP5', 'CP6', 'TP7', 'TP8', 'Pz', ...
            'P3', 'P4', 'P5', 'P6', 'P7', 'P8', 'POz', 'PO3', 'PO4', ...
            'PO5', 'PO6', 'PO7', 'PO8', 'Oz', 'O1', 'O2', 'ECG', ...
            'HEOR', 'HEOL', 'VEOU', 'VEOL'};
    [indx, tf] = listdlg('PromptString', {'请选择需要提取的通道', ...
        '按住shift区域多选', 'ctrl单个多选'}, 'ListString', list);
    if ~tf
        error('未选择通道，操作已取消。');
    end

    % 参数定义
    target_duration_seconds = 10;  
    srate = 1000;                   
    duration = target_duration_seconds * srate; 
    EEG_MI = [];      
    EEG_labels = [];  
    EEG_DATA_FIRST = [];%用于存储第一次提取的事件
    
    % 循环遍历所有事件
    for i = 1:length(EEG_EVENT)
        if EEG_EVENT(i).type == '5'
                index_start = EEG_EVENT(i).latency;
                index_end = EEG_EVENT(i).latency+duration-1;
                if isempty(EEG_MI)
                    if ~isempty(EEG_DATA_FIRST)
                        EEG_MI = cat(3,EEG_DATA_FIRST,EEG_DATA(indx,index_start:index_end));
                    else
                        EEG_DATA_FIRST = EEG_DATA(indx,index_start:index_end);
                    end
                else
                    EEG_MI(:,:,end+1) = EEG_DATA(indx,index_start:index_end); 
                end
                % 查找下一个事件类型并生成标签
                if i+1 <= length(EEG_EVENT)  % 确保不会超出边界
                    next_event_type = EEG_EVENT(i+1).type;  % 获取下一个事件类型
                    EEG_labels(end + 1) = str2double(next_event_type);  % 存储标签为数字
                end
        end
    end


    %% 将数据传入结构体
    EEG_S = struct();
    EEG_S.data = EEG_MI;  % 将提取的数据放入EEG结构体
    EEG_S.labels=EEG_labels;
end


