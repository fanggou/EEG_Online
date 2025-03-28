function BCI_Client()
    clear; clc;
    
    %% TCP配置
    tcp_ip = '127.0.0.1';
    tcp_port = 12345;
    tcp = tcpip(tcp_ip, tcp_port, 'Timeout', 10);
    fopen(tcp);
    
    try
        %% 连接验证
        fprintf('正在连接服务器...');
        while ~strcmp(get(tcp, 'Status'), 'open')
            pause(0.5);
        end
        fprintf('连接成功！\n');
        
        %% 创建界面
        fig = figure('Name','BCI实验', 'Position',[100 100 1200 600],...
            'MenuBar','none', 'NumberTitle','off', 'Resize','off');
        
        % 左侧图像区
        img_ax = axes('Parent',fig, 'Position',[0 0 0.70 1],...
            'XTick',[], 'YTick',[], 'Color','k');
        
        % 右侧信息区（使用列表框）
        info_panel = uipanel('Parent',fig, 'Position',[0.70 0 0.30 1],...
            'BackgroundColor',[0.9 0.9 0.9]);
        info_text = uicontrol('Parent',info_panel, 'Style','listbox',...
            'Position',[10 10 320 580], 'FontName','SimHei',...
            'FontSize',12, 'HorizontalAlignment','left',...
            'String',{'实验信息：'}, 'Max',2);
        
        %% 实验参数
        num_trials = 30;
        arrow_images = {'3.jpg', '4.jpg'};
        trial_seq = mod(randperm(num_trials),2)+1;
        data = struct('trial',num2cell(1:num_trials),...
            'true_label',num2cell(trial_seq), 'pred_label',[], 'correct',[]);
        
        %% 主循环
        for trial = 1:num_trials
            % 准备阶段
            send_command(tcp, 5);
            update_display(img_ax, info_text, trial, '准备阶段', 'dot.jpg');
            precise_wait(2);
            
            % MI阶段
            true_label = data(trial).true_label;
            send_command(tcp, true_label + 2);
            update_display(img_ax, info_text, trial, 'MI阶段', arrow_images{true_label});
            precise_wait(4);
            
            % 接收结果
            update_display(img_ax, info_text, trial, '等待结果', 'wait.jpg');
            [predicted, ~] = receive_prediction(tcp, 4);
            data(trial).pred_label = predicted;
            data(trial).correct = (predicted == true_label);
            precise_wait(4);
            % 更新界面
            update_info_text(info_text, data(trial));
        end
        
        %% 显示统计结果
        show_final_result(info_text, data);
        
    catch ME
        handle_error(fig, tcp, ME);
    end
end

%% 辅助函数
function send_command(tcp, cmd)
    fwrite(tcp, uint8(cmd), 'uint8');
    fprintf('[CLIENT] 已发送命令: %d\n', cmd);
end

function [predicted, latency] = receive_prediction(tcp, timeout)
    start_time = tic;
    predicted = NaN;
    while toc(start_time) < timeout
        if tcp.BytesAvailable > 0
            predicted = fread(tcp, 1, 'uint8');
            latency = toc(start_time);
            fprintf('[CLIENT] 收到预测: %d\n', predicted);
            return;
        end
        pause(0.01);
    end
    latency = timeout;
end

function update_display(ax, info, trial, phase, img_path)
    if ~isempty(img_path)
        img = imread(img_path);
        imshow(img, 'Parent', ax, 'XData',[0.2 0.8], 'YData',[0.2 0.8]);
    else
        cla(ax);
    end
    
    curr_text = get(info, 'String');
    new_line = sprintf('[%s] 试次%03d %s',...
        datestr(now,'HH:MM:SS'), trial, phase);
    if ischar(curr_text)
        curr_text = cellstr(curr_text);
    end
    set(info, 'String', [curr_text; {new_line}]);
    scroll_to_bottom(info); % 确保滚动到底部
end

function update_info_text(info, data)
    new_line = sprintf('试次%03d | 实际:%-2d | 预测:%-2d | 正确:%-2d',...
        data.trial, data.true_label, data.pred_label, data.correct);
    
    curr_text = get(info, 'String');
    if ischar(curr_text)
        curr_text = cellstr(curr_text);
    end
    set(info, 'String', [curr_text; {new_line}]);
    scroll_to_bottom(info); % 确保滚动到底部
end

function show_final_result(info, data)
    accuracy = mean([data.correct])*100;
    final_text = {
        ' '
        '==== 实验结束 ===='
        sprintf('总试次: %d', numel(data))
        sprintf('正确数: %d', sum([data.correct]))
        sprintf('准确率: %.1f%%', accuracy)
    };
    
    curr_text = get(info, 'String');
    set(info, 'String', [curr_text; final_text]);
    scroll_to_bottom(info); % 确保滚动到底部
end

function scroll_to_bottom(info)
    try
        % 使用Java对象强制滚动到底部
        jScrollPane = findjobj(info);
        jScrollPane.getVerticalScrollBar().setValue(jScrollPane.getVerticalScrollBar().getMaximum());
    catch
        % 备用方法：设置ListboxTop属性
        set(info, 'ListboxTop', length(get(info, 'String')));
    end
end

function precise_wait(duration)
    t = tic;
    while toc(t) < duration
        pause(0.001);
    end
end

function handle_error(fig, tcp, ME)
    try
        if ishandle(fig), close(fig); end
        fclose(tcp);
        delete(tcp);
    catch
    end
    fprintf('程序异常终止: %s\n', ME.message);
end