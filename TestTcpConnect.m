
function TestTcpConnect()
    clc;
    fprintf('========= 启动调试模式 =========\n');
    try
        tcpManager = TCPManager(12345);
        fprintf('等待客户端连接...');
        while ~tcpManager.IsConnected
            pause(1);
            fprintf('.');
        end
        fprintf('\n[SERVER] 客户端已连接!\n');

        test_counter = 0;
        while true
            if tcpManager.TrialPhase == 2
                test_counter = test_counter + 1;
                predicted_label = mod(test_counter,2)+1; % 1/2交替
                tcpManager.sendPrediction(predicted_label);
                fprintf('[SERVER] 模拟预测: %d\n', predicted_label);
                pause(4); % MI阶段保持4秒
                tcpManager.TrialPhase = 0; % 重置阶段
            end
            pause(0.1); % 降低CPU占用
        end
    catch ME
        fprintf('程序终止: %s\n', ME.message);
        delete(tcpManager);
    end
end