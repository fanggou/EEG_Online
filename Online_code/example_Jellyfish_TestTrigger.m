

%使用方法
%在118行设置断点，
%准备，jellyfish开启转发，串口调试助手
%打开 jellyfish 数据记录，运行本程序
%待弹出figure绘制实时数据后，开启串口调试助手的重复发送，发送一段时间后，取消重复发送
    %当前脚本循环记录10s，10s后会断开连接。在10s内停止发送trigger，即能保证NDF记录、TCPIP记录的trigger数量一致
    %如果两方面的trigger数量还存在差异，则出现了丢包等问题
%当前脚本运行到断点后，立刻停止jellyfish 数据记录。将记录的数据转换为bdf格式
    %NDF读取插件可能还有问题，测试着读不出trigger，所以暂时用bdf格式
%将bdf数据路径保存到BDFdatapath，选中并运行断点之后的脚本

%% 本程序是在Jellyfish传输协议更新后，对 在线传输数据 和 离线存储数据（NDF） 进行数据一致性对比
clear all;
clc;
close all;
instrreset;

deviceName = 'JellyFish';       % deviceName must be 'JellyFish'
nChan = 0;                      % default
srate = 0;                      % default

% Modify subject, sensor, and channel info in DataMesssage: required fields
subject_toshow='1';             % type the real subject name        
sensor_toshow='EEG';          
channel_toshow='T8';   

nDevice= 1;                     % type the number of device, default

ipData = '127.0.0.1';        % type IP address of the DataServer in JellyFish
portData = 8712;   

bufferSize = 7;                 % length of ringbuffer: 5s
datasaveflag=1;                 % whether save data to bin file or not

flag_cmpModuleSandC=1;
flag_cmpJellyfishSandC=1;

%% open data server
dataServer = DataServer(deviceName,nChan, ipData, portData, srate,datasaveflag,bufferSize);
dataServer.Open();

pause(1.5);                    % waiting 1.5s for creating inner buffer
DataMessage = dataServer.GetDataMessage();
MetaMessage = dataServer.GetMetaData();
%% save data online 确定数据保存文件名
if datasaveflag==1
    timenow=datestr(now,'yyyymmdd-HHMMSS');
    filename={};
    datapath=['.\Data\' timenow];
    figurepath=['.\ResultFigure\' timenow];
    if ~isfolder(datapath)
        mkdir(datapath);
    end
    if ~isfolder(figurepath)
        mkdir(figurepath);
    end
    for idx_subject=1:length(DataMessage)
        for idx_senor=1:length(DataMessage(idx_subject).SensorName)
            Chan_num_now=length(DataMessage(idx_subject).SensorChannelName{1,idx_senor});
            filename{idx_senor,idx_subject} = [datapath '\' strcat('nbChan-',num2str(Chan_num_now,'%02d'),...
                '-','Subject',num2str(idx_subject,'%02d'),'-','Sensor',num2str(idx_senor,'%02d'),'-',timenow , '.txt')];
            filename_TS{idx_senor,idx_subject} = [datapath '\' strcat('TSnbChan-',num2str(1,'%02d'),...
                '-','Subject',num2str(idx_subject,'%02d'),'-','Sensor',num2str(idx_senor,'%02d'),'.txt')];
            fileID{idx_senor,idx_subject}= fopen(filename{idx_senor,idx_subject},'w');%将需要写入的文件结构体传输到dataParser
            fileTSID{idx_senor,idx_subject}= fopen(filename_TS{idx_senor,idx_subject},'w');
        end
    end
end


%% only obtain the latest data, without overlap signal
%只保存最新数据，而不是提取ringbuffer中的全部数据，
idx_subject_toshow=find(contains({DataMessage(:).SubjectName},subject_toshow)==1);
idx_sensor_toshow=find(strcmp([DataMessage(idx_subject_toshow).SensorName],sensor_toshow)==1);
idx_sensor_toshow=idx_sensor_toshow(1);
idx_chan_toshow=find(strcmp([DataMessage(idx_subject_toshow).SensorChannelName{1,idx_sensor_toshow(1)}],channel_toshow)==1);

dataServer.ResetnUpdate;
pause(0.2);
rawdata_all=[];
figure;
for i = 1:100 %循环
%     [raw_latest,data_out_Trigger] = dataServer.GetLatestData();%just the latest data  
    [raw_latest,~,raw_latest_TS,~] = dataServer.GetLatestData();%just the latest data  
%     raw_latest = dataServer.GetLatestRingbuffer();%just the latest data
    rawdata_plot=raw_latest{idx_sensor_toshow,idx_subject_toshow};
    
    if ~isempty(rawdata_plot)
        rawdata_all=[rawdata_all,rawdata_plot];
        plot(rawdata_plot(idx_chan_toshow,:))
        title(['Subject: ' subject_toshow '; Sensor: ' sensor_toshow '; Channel: ' channel_toshow])
        
    else
        disp('该循环为空')
    end
    
    
    %Save the data to the corresponding file 循环期间保存对应数据
    if datasaveflag==1
        for idx_subject=1:size(raw_latest,2)
            for idx_senor=1:size(raw_latest,1)
                if ~isempty(fileID{idx_senor,idx_subject})
%                     fwrite(fileID{idx_senor,idx_subject},raw_latest{idx_senor,idx_subject},'float32',0,'ieee-le'); 
%                     fwrite(fileTSID{idx_senor,idx_subject},raw_latest_TS{idx_senor,idx_subject},'float32',0,'ieee-le'); 
                    fwrite(fileID{idx_senor,idx_subject},raw_latest{idx_senor,idx_subject},'double',0,'ieee-le'); 
                    fwrite(fileTSID{idx_senor,idx_subject},raw_latest_TS{idx_senor,idx_subject},'double',0,'ieee-le'); 

                end
            end
        end
    end
    pause(0.2);
end
close gcf
figure,plot(rawdata_all(idx_chan_toshow,:))

%close file
if datasaveflag==1
    for idx_subject=1:size(fileID,2)
        for idx_senor=1:size(fileID,1)
            if ~isempty(fileID{idx_senor,idx_subject})
                status = fclose(fileID{idx_senor,idx_subject});
                if status == -1
                    fprintf('failed to colse file .......\n');
                end
                status = fclose(fileTSID{idx_senor,idx_subject});
                if status == -1
                    fprintf('failed to colse file .......\n');
                end
            end
            
        end
    end
end


%% close data server
dataServer.Close();


%% 是否需要对比探头发送与接收数据的稳定性
if flag_cmpModuleSandC
    if ~isfolder([figurepath '\转发速度稳定性'])
        mkdir([figurepath '\转发速度稳定性']);
    end
    %FileName='G:\博睿康代码维护\JellyFish_20230627_Dump原始数据包时间戳\Log-501\DumpAlertTimestamp_22053130_20230703_115744.csv';
    [FileName,PathName]=uigetfile('*.csv','以 DumpAlertTimestamp_ 开头的CSV文件');%     
    ModuleTS_client = readmatrix([PathName FileName],'Range','B:B');%接收端时间戳，以ms为单位
    ModuleTS_server=readmatrix([PathName FileName],'Range','D:D');%发送端时间戳，以ms为单位
%     ModuleTS_client = Milliseconds(2:end);
%     ModuleTS_server=TimestampFPO(2:end);

    ModuleTS_server=ModuleTS_server-ModuleTS_server(1);
    ModuleTS_client=ModuleTS_client-ModuleTS_client(1);
    figure,plot(ModuleTS_client-ModuleTS_server)
    xlabel('数据包序号')
    ylabel('接收发送时间差（ms）')
    title('探头接发时间误差')
    saveas(gca,[figurepath '\转发速度稳定性\探头接发时间误差.tiff'])
end

%% 是否需要对比 Jellyfish 发送与 C# 数据的稳定性
if flag_cmpJellyfishSandC
    if ~isfolder([figurepath '\转发速度稳定性'])
        mkdir([figurepath '\转发速度稳定性']);
    end
    %% 读取Jellyfish发送端数据
    [FileName,PathName]=uigetfile('*.csv','以 DataTransferTimeStamp_SN 开头的CSV文件');%   以 DataTransferTimeStamp_SN 开头的文件
    DateTime_server = readmatrix([PathName FileName],'Range','A:A', 'OutputType', 'string');%接收端时间戳，以ms为单位
    pkgTS_server = readmatrix([PathName FileName],'Range','C:C');%接收端时间戳，以ms为单位
    
    %转换为s
    JellyfishTS_server=[];
    for idx_time=2:size(DateTime_server,1)%发送端的时间，还要转换成ms
        DateTime_now=DateTime_server(idx_time,1);
        DateTime_now=char(DateTime_now);
        loc_colon=strfind(DateTime_now,':');
        DateTime_now_hour=str2num(DateTime_now(1:loc_colon(1)-1));
        DateTime_now_minute=str2num(DateTime_now(loc_colon(1)+1:loc_colon(2)-1));
        DateTime_now_second=str2num(DateTime_now(loc_colon(2)+1:loc_colon(3)-1));
        DateTime_now_msecond=str2num(DateTime_now(loc_colon(3)+1:end));
        JellyfishTS_server(idx_time)=3600*DateTime_now_hour+60*DateTime_now_minute+DateTime_now_second+DateTime_now_msecond/1000;
    end
    JellyfishTS_server(1)=[];%发送端的时间
    
    % 要记录数据包的时间戳
    JellyfishPkgTS_server=pkgTS_server;
    JellyfishPkgTS_server(1,:)=[];
    
   
    %% matlab/C# 接收端
    %导入以DataTransferTimeStamp_**client开头的csv文件，对齐总线之后时间戳
    %分隔符号有点问题，需要手动修改变量名称
    [FileName,PathName]=uigetfile('*.csv','包含DataTransferTimeStamp_**client的csv文件');%   
    DateTime_client = readmatrix([PathName FileName],'Range','A:A', 'OutputType', 'string');%接收端时间戳，以ms为单位
    pkgTS_client = readmatrix([PathName FileName],'Range','C:C');%接收端时间戳，以ms为单位
    
    JellyfishTS_client=[];
    for idx_time=2:size(DateTime_client,1)%发送端的时间，还要转换成ms
        DateTime_now=DateTime_client(idx_time,1);
        DateTime_now=char(DateTime_now);
        loc_colon=strfind(DateTime_now,':');
        DateTime_now_hour=str2num(DateTime_now(1:loc_colon(1)-1));
        DateTime_now_minute=str2num(DateTime_now(loc_colon(1)+1:loc_colon(2)-1));
        DateTime_now_second=str2num(DateTime_now(loc_colon(2)+1:loc_colon(3)-1));
        DateTime_now_msecond=str2num(DateTime_now(loc_colon(3)+1:end));
        JellyfishTS_client(idx_time)=3600*DateTime_now_hour+60*DateTime_now_minute+DateTime_now_second+DateTime_now_msecond/1000;
    end
    JellyfishTS_client(1)=[];%发送端的时间
    
    % 要记录数据包的时间戳
    JellyfishPkgTS_client=pkgTS_client;
    JellyfishPkgTS_client(1,:)=[];
    


    %% 绘制图像
    %根据时间戳进行对齐
    loc_cut=find(JellyfishPkgTS_server==JellyfishPkgTS_client(1));
    
    diff_Jellyfish=JellyfishTS_client-JellyfishTS_server(loc_cut:loc_cut+length(JellyfishTS_client)-1);
    diff_Jellyfish_mean=mean(diff_Jellyfish*1000);
    diff_Jellyfish_std=std(diff_Jellyfish*1000);
    
    figure,plot(diff_Jellyfish*1000)
    xlabel('数据包序号')
    ylabel('数据包传出到应用接收的时间（ms）')
    title(['Jellyfish与应用之间的时间差：' num2str(diff_Jellyfish_mean) '±' num2str(diff_Jellyfish_std)])
    saveas(gca,[figurepath '\转发速度稳定性\Jellyfish与应用接发时间差.tiff'])
end

%% 在线数据与离线数据的Trigger一致性对比
close all
% 发现NDF插件读出来没有trigger，events为空
%所以(写入BDF数据地址)
BDFdatapath=uigetdir('D:\','转换为BDF之后的数据路径');
% BDFdatapath='G:\博睿康代码维护\JellyFish_20230627_Dump原始数据包时间戳\Data\20230704093441_测试601\20230704093441_测试601';
EEG =  pop_importNeuracle([],BDFdatapath);

addpath('.\LibNDF4EEGLab')
% EEG = pop_importNDF;  
% [ChannelData,events] = ReadOneChannel('E:\工作文件夹\2023-01-13 Jellyfish协议更新\JellyFish-develop-20230427-bc96ec72\Data\20230515152314_0515_005',...
%     '东坡居士',"TP8",0,20);    

Data_cmp_all={};
for idx_subject=1:size(filename,2)  % triggersubject位置未知，所有都要对比对比
    subject_loc=find([MetaMessage(:).SubjectIdx]==idx_subject);
    for idx_senor=1:size(filename,1)
        if ~isempty(filename{idx_senor,idx_subject})
            filename_now =filename{idx_senor,idx_subject};
            
            channame_nowsensor=MetaMessage(subject_loc(1)).ChannelName_sort  {1, idx_senor} ;
            if ~strcmp(channame_nowsensor,'Trigger')
                continue
            end
            data_nowsensor_TCPIP= readSavedFile(filename_now);
            dataTS_nowsensor_TCPIP= readSavedFile(filename_TS{idx_senor,idx_subject});
%             data_nowsensor_TCPIP= readSavedFile('.\Data\20230628-131815\nbChan-01-Subject01-Sensor02-20230628-131815.txt');
%             dataTS_nowsensor_TCPIP= readSavedFile('.\Data\20230628-131815\TSnbChan-01-Subject01-Sensor02.txt');
            
            loc_trigger=find(data_nowsensor_TCPIP>0); % Trigger号
            loc_trigger_diff=diff(loc_trigger);%两个trigger之间的时间间隔
            
            figure,histogram(loc_trigger_diff),
            title('TCPIP trigger时间间隔的统计')
            loc_trigger_diff_mean=mean(loc_trigger_diff);
            loc_trigger_diff_std=std(loc_trigger_diff);
            disp(['TCPIP，时间差均值为：' num2str(loc_trigger_diff_mean) 'ms，方差为：' num2str(loc_trigger_diff_std) 'ms'])
            
            
            loc_trigger2=[EEG.event(:).latency];
            loc_trigger_diff2=diff(loc_trigger2);%两个trigger之间的时间间隔
            figure,histogram(loc_trigger_diff2)
            title('BDF trigger时间间隔的统计')
            loc_trigger_diff_mean2=mean(loc_trigger_diff2);
            loc_trigger_diff_std2=std(loc_trigger_diff2);
            disp(['NDF，时间差均值为：' num2str(loc_trigger_diff_mean) 'ms，方差为：' num2str(loc_trigger_diff_std) 'ms'])

            
            data_trigger1=zeros(1,loc_trigger(end)-loc_trigger(1));
            data_trigger1(loc_trigger-loc_trigger(1)+1)=2;
            TS_trigger1=dataTS_nowsensor_TCPIP(loc_trigger(1):loc_trigger(end));
            data_trigger2=zeros(1,loc_trigger2(end)-loc_trigger2(1)); 
            data_trigger2(loc_trigger2-loc_trigger2(1)+1)=1;
            
            %将两段数据等长
            Length_min=min(length(data_trigger1),length(data_trigger2));
            data_trigger1_cut=data_trigger1(1:Length_min);%对齐、补零后的数据
            data_trigger2_cut=data_trigger2(1:Length_min);
%             Count_min=min(length(loc_trigger),length(loc_trigger2));
            try
%                 Time_diff=(loc_trigger(end)-loc_trigger(1))-(loc_trigger2(end)-loc_trigger2(1));
%                 Time_diff=(loc_trigger(1:Count_min)-loc_trigger(1))-...
%                     (loc_trigger2(1:Count_min)-loc_trigger2(1));%并非全部对齐，如果某个类型trg缺失，则不对齐
                Time_diff=data_trigger1_cut./2-data_trigger2_cut;
                
                figure,plot(data_trigger1_cut),hold on,
                plot(data_trigger2_cut),plot(Time_diff*3)
                title(['TCPIP与NDF trigger时间误差均值：' num2str(mean(Time_diff)) '；方差：' num2str(std(Time_diff))])
                ylim([-3 3])
                legend('TCPIP','BDF','存在误差的位置')%,'Error Location'
                saveas(gca,[figurepath '\TCPIP与NDF的Trigger一致性.fig'])
                saveas(gca,[figurepath '\TCPIP与NDF的Trigger一致性.tiff'])
            catch
                disp('TCPIP和NDF的trigger数量不一致')
            end
            
            break
        end
        
        
    end
end

%% 在线数据与离线数据的数据一致性对比
addpath('.\DataCmp')

%对于每个
folder =  uigetdir('*.*', '选择Jellyfish NDF数据文件保存路径');
if isequal(folder,0)
    error('Cancel choosing a folder...');
end

Data_cmp_all={};
for idx_subject=1:size(filename,2)% triggersubject位置未知，所有都要对比对比
    
    
    subject_loc=find([MetaMessage(:).SubjectIdx]==idx_subject);%当前受试所拥有的探头序号
    for idx_senor=1:size(filename,1)
        
        SensorIdx_all={MetaMessage(:).SensorIdx};
        for idx_sensor2=1:length(SensorIdx_all)
            idx_senor_cell{1,idx_sensor2}=idx_senor;
        end
        sensor_loc1=cellfun(@ismember,idx_senor_cell,SensorIdx_all,'UniformOutput',false);
        sensor_loc2=find(cell2mat(sensor_loc1(subject_loc))==1);
        sensor_loc3=subject_loc(sensor_loc2);
        ModuleName_nowSensor=MetaMessage(sensor_loc3).ModuleName';
        ModuleName_nowSensor=strrep(ModuleName_nowSensor,native2unicode(0,'UTF-8'),'');
        
        if ~isempty(filename{idx_senor,idx_subject})
            filename_now =filename{idx_senor,idx_subject};
            
            channame_nowsensor=MetaMessage(subject_loc(1)).ChannelName_sort  {1, idx_senor} ;
            
            if strcmp(channame_nowsensor,'Trigger')
                continue
            end
            data_nowsensor_TCPIP= readSavedFile(filename_now);
            
            fs_nowsensor=MetaMessage(subject_loc(1)).SampleRates  (1, idx_senor) ;
            fs_nowsensor=double(fs_nowsensor);
            
            %对于该sensor的每个通道
            if iscell(channame_nowsensor)
                channum=length(channame_nowsensor);
            else
                channum=1;
            end
            
            for idx_chan=1:channum
                if iscell(channame_nowsensor)
                    channame_nowsensor_now=channame_nowsensor{idx_chan};
                else
                    channame_nowsensor_now=channame_nowsensor;
                end
                
                channame_nowsensor_nowModule=[ModuleName_nowSensor '_' channame_nowsensor_now];
                [~,data_nowchan_NDF]=pop_importNDF(folder, ...
                    channame_nowsensor_now,idx_subject);
                [~,data_nowchan_NDFModule]=pop_importNDF(folder, ...
                    channame_nowsensor_nowModule,idx_subject);

                %根据trigger得到的参考位置，找到差不多的对齐点
                % 按照1000Hz采样率识别到的对齐点
                % loc_trigger(1)：TCPIP，loc_trigger2(1)：NDF
                loc_ref=loc_trigger(1)-loc_trigger2(1);
                loc_ref_time=loc_ref*fs_nowsensor/1000;

                if (~isempty(data_nowchan_NDF))&&(~isempty(data_nowchan_NDFModule))
                    [startPoint1,Data_epoch1,Diff_epoch1,Mean_Diff1,Var_diff1]=...
                        data_equal_cmp(data_nowsensor_TCPIP(idx_chan,:),data_nowchan_NDF,loc_ref_time);
                    [startPoint2,Data_epoch2,Diff_epoch2,Mean_Diff2,Var_diff2]=...
                        data_equal_cmp(data_nowsensor_TCPIP(idx_chan,:),data_nowchan_NDFModule,loc_ref_time);
                    
                    if abs(Mean_Diff1)<abs(Mean_Diff2)
                        startPoint=startPoint1;Data_epoch=Data_epoch1;Diff_epoch=Diff_epoch1;Mean_Diff=Mean_Diff1;Var_diff=Var_diff1;
                        Data_cmp_all{1,end+1}=Data_epoch;
                        Data_cmp_all{2,end}=channame_nowsensor_now;
                        Data_cmp_all{3,end}=startPoint;
                    else
                        startPoint=startPoint2;Data_epoch=Data_epoch2;Diff_epoch=Diff_epoch2;Mean_Diff=Mean_Diff2;Var_diff=Var_diff2;
                        Data_cmp_all{1,end+1}=Data_epoch;
                        Data_cmp_all{2,end}=channame_nowsensor_now;
                        Data_cmp_all{3,end}=startPoint;
                    end
                else
                    
                    % 生成函数，进行对比
                    [startPoint,Data_epoch,Diff_epoch,Mean_Diff,Var_diff]=...
                        data_equal_cmp(data_nowsensor_TCPIP(idx_chan,:),data_nowchan_NDF,loc_ref_time);
                    Data_cmp_all{1,end+1}=Data_epoch;
                    Data_cmp_all{2,end}=channame_nowsensor_now;
                    Data_cmp_all{3,end}=startPoint;
                    
                end
                
                figure,plot(Data_epoch(1,:)),hold on,
                    plot(Data_epoch(2,:)),
                    legend('NDF','TCPIP')
                    xlabel('Data Point'),
                    ylabel('Amplitude(μV)')
                    title(['通道：' channame_nowsensor_now '；误差均值：' num2str(Mean_Diff) '；误差方差：' num2str(Var_diff)])
                
                saveas(gca,['.\ResultFigure\ResultFigure-Subject_' num2str(idx_subject) '-Sensor_' num2str(idx_senor) ...
                    '-Chan_' num2str(idx_chan) '.tiff'])
            end
        end
        
        
    end
end


%{
%% 根据时间戳统计：全探头转发

TS_segment=unique(100*floor(TS_trigger1/100));
TriggerCount_TCPIP=[];
TriggerCount_Jellyfish=[];
for idx_TS_segment=1:length(TS_segment)
    Loc_segment=find(TS_trigger1>=TS_segment(idx_TS_segment)&TS_trigger1<(TS_segment(idx_TS_segment)+100));
    Num_trigger=find(data_trigger1(Loc_segment)>0);
    TriggerCount_TCPIP(idx_TS_segment)=length(Num_trigger);
    
    Num_trigger=find(data_trigger2_cut(Loc_segment)>0);
    TriggerCount_Jellyfish(idx_TS_segment)=length(Num_trigger);
end
%将C#统计的 Trigger 数据对齐
Loc_start=find(VarName3==TS_segment(1));
TriggerCount_C=Trigger(Loc_start:end);

% figure,plot(TriggerCount_TCPIP),hold on,
% plot(TriggerCount_C)
% plot(TriggerCount_Jellyfish)
% legend('TCPIP','C','Jellyfish')

figure,plot(TriggerCount_TCPIP),hold on,
plot(TriggerCount_Jellyfish)
legend('TCPIP','Jellyfish')

figure,plot(TriggerCount_C),hold on,
plot(TriggerCount_Jellyfish)
legend('C','Jellyfish')

%% 根据时间戳统计：单探头转发
    %C#的接收统计有问题，所以不能作为参考

%% 数据传输速度的稳定性
%读取时间 DateTime
DateTime_seconds=[];
for idx_time=2:size(DateTime,1)
    DateTime_now=DateTime(idx_time,1);
    DateTime_now=char(DateTime_now);
    loc_colon=strfind(DateTime_now,':');
    DateTime_now_hour=str2num(DateTime_now(1:loc_colon(1)-1));
    DateTime_now_minute=str2num(DateTime_now(loc_colon(1)+1:loc_colon(2)-1));
    DateTime_now_second=str2num(DateTime_now(loc_colon(2)+1:loc_colon(3)-1));
    DateTime_now_msecond=str2num(DateTime_now(loc_colon(3)+1:end));
    DateTime_seconds(idx_time)=3600*DateTime_now_hour+60*DateTime_now_minute+DateTime_now_second+DateTime_now_msecond/1000;
end
DateTime_seconds(1)=[];
figure,plot(DateTime_seconds)

%}












