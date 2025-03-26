function filter_states = init_online_filter(srate_original, numChannels)
% 滤波器状态初始化 (修正版)
% 输入：
%   srate_original - 原始采样率
%   numChannels - 通道数
% 输出：
%   filter_states - 初始化的滤波器状态结构

% 初始化状态结构
filter_states = struct(...
    'bpState',    zeros(4-1, numChannels),... % 带通滤波器状态
    'notchState', zeros(2-1, numChannels));   % 陷波滤波器状态

% 验证采样率兼容性
if mod(srate_original, 250) ~= 0
    warning('原始采样率 %d Hz 无法被250整除，可能导致重采样误差', srate_original);
end
end