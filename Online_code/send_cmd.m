%%---------------main-----------------

% % 清理可能存在的串口对象，避免串口当前被占用
% HC_ClearCOM;
% %% 串口初始化
% % 串口编号，需要从设备管理器中的COM号获知
% serPort = 'COM3';
% % 通讯的波特率，固定值
% baudrate = 9600;
% % 新建一个串口对象
% serConn = serial(serPort,'BaudRate',baudrate,'Timeout',5,'DataBits',8,...
%     'StopBits',1,'Parity','none','OutputBufferSize',1024,'InputBufferSize',1024);
% 
% %% 打开串口
% try
%     fopen(serConn);
% catch e
%     msgbox('串口打开失败');
%     return;
% end
%  trails = 2;
% 
% disp('准备执行动作');
% 
% for i = 1:trails
%     send_cmd(1,serConn);
%     disp('动作组1已完成');
%     WaitSecs(1);
%     send_cmd(2,serConn);
%     disp('动作组2已完成');
%     WaitSecs(1);   
%     send_cmd(3,serConn);
%     disp('动作组3已完成');
%     WaitSecs(1);
%     send_cmd(4,serConn);
%     disp('动作组4已完成');
%     WaitSecs(1);    
% end

%% ----------send----------
%%配置：9600-8-1-No
%数据帧格式要求：
%|帧头（2byte）|数据长度（1byte）|指令（1byte）|参数。。。   |
%|0x55  0x55   |    Length       |    Cmd      |para1...paraN|
%Length不包含两个帧头，即 Length = 参数个数+2
%Cmd：CMD_FULL_ACTION_RUN    对应值：6(0x06)，数据长度 ：5（0x05）
%para1 ： 要运行的动作组编号（1-左手握拳；2-右手伸掌；3-左腿抬；4-右腿抬）
%para2：  动作组执行的次数的低八位（0x01）
%para3：  动作组执行的次数的高八位（0x00）
%%
function send_cmd(para1,serConn)
    a = [0x55,0x55,0x05,0x06,0x00,0x01,0x00];
    a(5) = para1;
    fwrite(serConn,a);
end