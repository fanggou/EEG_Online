function test()
    clc;
    fprintf('========= 调试模式（客户端） =========\n');
    try
        %% 连接服务端
        fprintf('连接服务端中...');
        tcpClient = tcpip('127.0.0.1', 12345, 'Timeout', 10);
        fopen(tcpClient); 
        % 发送握手信号（激活服务端检测）
        fwrite(tcpClient, uint8(0), 'uint8');
        fprintf('\n[CLIENT] 连接成功!\n');

        %% 主循环
        test_counter = 0;
        while isvalid(tcpClient) && strcmp(tcpClient.Status, 'open')
            % 检查是否有数据到达
            if tcpClient.BytesAvailable > 0
                cmd = fread(tcpClient, 1, 'uint8');
                switch cmd
                    case 5  % 准备阶段命令
                        fprintf('\n[CLIENT] 收到准备命令\n');
                    otherwise
                        if cmd >= 3
                            true_label = cmd - 2;
                            test_counter = test_counter + 1;
                            predicted_label = mod(test_counter, 2) + 1;
                            fwrite(tcpClient, uint8(predicted_label), 'uint8');
                            fprintf('[CLIENT] 收到 MI 命令（实际标签: %d），发送预测: %d\n', true_label, predicted_label);
                        else
                            fprintf('[CLIENT] 收到未知命令: %d\n', cmd);
                        end
                end
            end
            pause(0.1);
        end
        fclose(tcpClient);
        delete(tcpClient);
    catch ME
        fprintf('程序终止: %s\n', ME.message);
        if exist('tcpClient', 'var') && isvalid(tcpClient)
            fclose(tcpClient);
            delete(tcpClient);
        end
    end
end
