% function [buffer, loopCounter] = update_buffer_and_send(...
%     buffer, loopCounter, predictlabel, confidence, serConn, sendInterval)
% % 功能: 更新缓冲区并每指定次数发送最高置信度结果
% % 输入:
% %   - buffer: 结构体，包含 labels 和 confidences 字段
% %   - loopCounter: 当前循环计数器
% %   - predictlabel: 本次预测标签
% %   - confidence: 本次置信度
% %   - serConn: 串口对象
% %   - sendInterval: 发送间隔次数（如20次）
% % 输出:
% %   - buffer: 更新后的缓冲区
% %   - loopCounter: 更新后的计数器
% 
% %% 更新缓冲区
% buffer.labels = [buffer.labels, predictlabel];
% buffer.confidences = [buffer.confidences, confidence];
% loopCounter = loopCounter + 1;
% 
% %% 判断是否到达发送间隔
% if loopCounter >= sendInterval
%     % 提取最高置信度结果
%     [max_confidence, idx] = max(buffer.confidences);
%     best_label = buffer.labels(idx);
%     
%     % 发送指令
%     send_cmd(best_label, serConn);
%     fprintf('[发送] 4秒内最高置信度: 类别 %d (置信度 %.2f)\n', best_label, max_confidence);
%     
%     % 重置缓冲区和计数器
%     buffer.labels = [];
%     buffer.confidences = [];
%     loopCounter = 0;
% end
% end

% function [buffer, loopCounter] = update_buffer_and_send(...
%     buffer, loopCounter, predictlabel, ~, serConn, sendInterval)
% % 功能: 连续检测到相同动作N次后发送
% % 输入:
% %   - buffer: 结构体，包含 current_label 和 current_counter
% %   - loopCounter: 兼容保留字段（可忽略）
% %   - predictlabel: 本次预测的标签
% %   - ~: 忽略置信度
% %   - serConn: 串口对象
% %   - sendInterval: 连续触发阈值N
% % 输出:
% %   - buffer: 更新后的状态结构体
% %   - loopCounter: 当前连续计数（兼容保留）
% 
% % 初始化buffer（首次调用时）
% if isempty(fieldnames(buffer)) || ~isfield(buffer, 'current_label')
%     buffer.current_label = [];
%     buffer.current_counter = 0;
% end
% 
% % 判断动作是否连续
% if isequal(predictlabel, buffer.current_label)
%     buffer.current_counter = buffer.current_counter + 1;
% else
%     % 动作不同，重置为当前动作
%     buffer.current_label = predictlabel;
%     buffer.current_counter = 1;
% end
% 
% % 检查是否达到连续阈值N
% if buffer.current_counter >= sendInterval
%     % 发送指令
%     send_cmd(buffer.current_label, serConn);
%     fprintf('[发送] 连续%d次检测到类别 %d\n', sendInterval, buffer.current_label);
%     
%     % 重置状态（清空当前动作和计数）
%     buffer.current_label = [];
%     buffer.current_counter = 0;
% end
% 
% % loopCounter 保持兼容（可删除或改为实际计数）
% loopCounter = buffer.current_counter;
% end


function [buffer, loopCounter] = update_buffer_and_send(...
    buffer, loopCounter, predictlabel, confidence, serConn, sendInterval)
% 功能: 连续N次检测到相同动作且置信度均大于阈值时发送
% 输入:
%   - buffer: 结构体，包含 current_label 和 current_counter
%   - loopCounter: 兼容保留字段（可忽略）
%   - predictlabel: 本次预测的标签
%   - confidence: 本次置信度
%   - serConn: 串口对象
%   - sendInterval: 连续触发阈值N
%   - min_confidence: 置信度阈值（如0.8）
% 输出:
%   - buffer: 更新后的状态结构体
%   - loopCounter: 当前连续计数（兼容保留）

% 初始化buffer（首次调用时）
min_confidence = 0.4;
if isempty(fieldnames(buffer)) || ~isfield(buffer, 'current_label')
    buffer.current_label = [];
    buffer.current_counter = 0;
end

% 判断动作是否连续且置信度达标
if isequal(predictlabel, buffer.current_label) && (confidence > min_confidence)
    buffer.current_counter = buffer.current_counter + 1;
else
    % 动作或置信度不满足条件，重置
    buffer.current_label = predictlabel;
    buffer.current_counter = 0;  % 注意：只有连续满足条件时才计数
end

% 检查是否达到连续阈值N
if buffer.current_counter >= sendInterval
    % 发送指令
    send_cmd(buffer.current_label, serConn);
    fprintf('[发送] 连续%d次检测到类别 %d (置信度均 > %.2f)\n', ...
        sendInterval, buffer.current_label, min_confidence);
    
    % 重置状态
    buffer.current_label = [];
    buffer.current_counter = 0;
end

% loopCounter 保持兼容（可删除或改为实际计数）
loopCounter = buffer.current_counter;
end


