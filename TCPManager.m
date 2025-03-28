classdef TCPManager < handle
    properties
        Server
        IsConnected = false
        TrialPhase = 0
        CurrentLabel = 0
    end
    
    methods
        function obj = TCPManager(port)
            obj.Server = tcpserver('0.0.0.0', port);
            configureCallback(obj.Server, "byte", 1, @obj.DataCallback);
            obj.Server.ConnectionChangedFcn = @obj.ConnectionCallback;
            fprintf('TCP服务器已启动，监听端口: %d\n', port);
        end
        
        function DataCallback(obj, ~, ~)
            % 读取1字节数据（与configureCallback配置一致）
            raw = read(obj.Server, 1, 'uint8');
            fprintf('[SERVER] 收到原始数据: ');
            disp(raw);
            
            cmd = raw(1);
            switch cmd
                case 5
                    obj.TrialPhase = 1;
                    fprintf('[SERVER] 收到试次开始命令\n');
                case {3,4}
                    obj.TrialPhase = 2;
                    obj.CurrentLabel = cmd - 2;
                    fprintf('[SERVER] 收到MI标签: %d\n', obj.CurrentLabel);
                otherwise
                    fprintf('[SERVER] 收到未知命令: %d\n', cmd);
            end
        end
        
        function ConnectionCallback(obj, ~, ~)
            obj.IsConnected = obj.Server.Connected;
            if obj.IsConnected
                fprintf('[SERVER] 客户端已连接\n');
            else
                fprintf('[SERVER] 客户端断开\n');
                obj.TrialPhase = 0;
            end
        end
        
        function sendPrediction(obj, label)
            if obj.IsConnected
                write(obj.Server, uint8(label), "uint8");
                fprintf('[SERVER] 已发送预测: %d\n', label);
            end
        end
        
        function delete(obj)
            delete(obj.Server);
        end
    end
end