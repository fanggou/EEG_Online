classdef DataParser < handle
% Data parser for TCP/IP
%
% Syntax:  
%     
%
% Inputs:
%     
%
% Outputs:
%     
%
% Example:
%     
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% Author: Hanlei Li
%
% Versions:
%    v1.01: 2022-07-06, orignal
%    v1.02: 2022-12-03, Debug for new Jellyfish 
%
% Copyright (c) 2023 Neuracle, Inc. All Rights Reserved. http://neuracle.cn/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    properties (Constant)
        
    end

    properties
        device;
        nChan;
        buffer;
        fileID;
        MetaData_MSG_Jellyfish;
        saveData_flag;
        SN_all;
        pkgsCount
%         pkgsCountIn
%         pkgTSFile
%         TriggerFile
    end

    methods
        function obj = DataParser(device, nChan,saveData_flag)
            obj.device = device;
            obj.nChan = nChan;
            obj.saveData_flag=saveData_flag;
        end

        function WriteData(obj, buffer,TCPIP_in, ringBuffer)
            buffer = uint8(buffer(:));
            obj.buffer = [obj.buffer; buffer];
            switch obj.device
                case 'JellyFish'
                    [data, event, obj.buffer,Flag_Transfer,Timestamp] = ParseDataJellyFish(obj, obj.buffer, TCPIP_in,ringBuffer);
                otherwise
                    error('Device not supported');
            end 
            
            if ~isempty(obj.fileID)&&obj.saveData_flag 
                try
                    for idx_subject=1:size(data,2)
                        for idx_senor=1:size(data,1)
                            if ~isempty(obj.fileID{idx_senor,idx_subject})
                                fwrite(obj.fileID{idx_senor,idx_subject},data{idx_senor,idx_subject},'float32',0,'ieee-le'); 
                            end
                        end
                    end
                catch
                    fprintf('Save fail');
                end
            end
            if Flag_Transfer==0
                ringBuffer.Append(data,Timestamp);
            elseif Flag_Transfer==1
                ringBuffer.Append_Indep(data,Timestamp);
            end

        end
        

        function [Data_all_out, event, buffer,Flag_Transfer,StartTimestamp_all] = ParseDataJellyFish(obj, buffer, TCPIP_in,ringBuffer)
            n = numel(buffer);
            data = {};
            Data_all_out={};
            Flag_Transfer=0;
            event = [];
            
            StartTimestamp_all=[];
            headToken = hex2dec({'5A','A5'});
            tailToken = hex2dec({'A5','5A'});
            headToken_Meta = hex2dec({'5F','F5'});
            tailToken_Meta = hex2dec({'F5','5F'});
            headandtailToken_OK = hex2dec({'F5','5F','5F','F5'});
            i = 1;
            while i <= n
                if isequal(buffer(i:i+1),headToken_Meta)
                    %% 包头内容不变
                    headerLength_Meta = typecast(buffer(i+2:i+5),'uint32');
                    totalLength_Meta = typecast(buffer(i+6:i+9),'uint32');
                    
                    if totalLength_Meta>n
                        break
                    end
                    Flag_Meta = typecast(buffer(i+10:i+13),'uint32');%整体转发末位0，单探头转发末位1
                    
                    sensorCount_Meta =  typecast(buffer(i+14:i+17),'uint32');
                    sensorOffsets_Meta = typecast(buffer(i+headerLength_Meta+1:i+headerLength_Meta+4*sensorCount_Meta),'uint32');
                    
                    offset_Meta = i+headerLength_Meta+4*sensorCount_Meta;
                    
                    ringbufferSize=zeros(sensorCount_Meta,2);
                    MetaData_MSG(sensorCount_Meta)=struct('PersonName',[],'ModuleName',[],'ModuleType',[],'SerialNumber',[],'ChannelCount',[],...
                        'ChannelNames',[],'ChannelTypes',[],'SampleRates',[],'DataCountPerChannels',[],...
                        'MaxDigital',[],'MinDigital',[],'MaxPhysical',[],'MinPhysical',[],'Gain',[]);
                    
                    for id = 1:sensorCount_Meta 
                        %受试名
                        MetaData_MSG(id).PersonName =native2unicode(buffer(offset_Meta:offset_Meta+30-1),'UTF-8')';
                        %传感器名
                        MetaData_MSG(id).ModuleName = native2unicode(buffer(offset_Meta+30:offset_Meta+60-1),'UTF-8');
                        
                        %传感器类型
                        MetaData_MSG(id).ModuleType =  native2unicode(buffer(offset_Meta+60:offset_Meta+90-1),'UTF-8');
                        
                        %SN号：SerialNumber
                        MetaData_MSG(id).SerialNumber = typecast(buffer(offset_Meta+90:offset_Meta+94-1),'uint32'); %
                        
                        %当前设备的通道数
                        channelCount_Meta{id,1} =  typecast(buffer(offset_Meta+94:offset_Meta+98-1),'uint32');%
                        MetaData_MSG(id).ChannelCount =  typecast(buffer(offset_Meta+94:offset_Meta+98-1),'uint32');%
                        
                        %当前设备的各通道通道名
                        MetaData_MSG(id).ChannelNames = native2unicode(buffer(offset_Meta+98:offset_Meta+98+10*channelCount_Meta{id,1}-1),'UTF-8');
                        
                        %当前设备的各通道通道类型
                        MetaData_MSG(id).ChannelTypes = native2unicode(buffer(offset_Meta+98+10*channelCount_Meta{id,1}:offset_Meta+98+20*channelCount_Meta{id,1}-1),'UTF-8');
                        
                        %当前设备的各通道采样率
                        MetaData_MSG(id).SampleRates = typecast(buffer(offset_Meta+98+20*channelCount_Meta{id,1}:offset_Meta+98+24*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道数据量
                        MetaData_MSG(id).DataCountPerChannels = typecast(buffer(offset_Meta+98+24*channelCount_Meta{id,1}:offset_Meta+98+28*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道最大数字值
                        MetaData_MSG(id).MaxDigital = typecast(buffer(offset_Meta+98+28*channelCount_Meta{id,1}:offset_Meta+98+32*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道最小数字值
                        MetaData_MSG(id).MinDigital = typecast(buffer(offset_Meta+98+32*channelCount_Meta{id,1}:offset_Meta+98+36*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道最大模拟值
                        MetaData_MSG(id).MaxPhysical = typecast(buffer(offset_Meta+98+36*channelCount_Meta{id,1}:offset_Meta+98+40*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道最小模拟值
                        MetaData_MSG(id).MinPhysical = typecast(buffer(offset_Meta+98+40*channelCount_Meta{id,1}:offset_Meta+98+44*channelCount_Meta{id,1}-1),'uint32');%
                        
                        %当前设备的各通道增益
                        MetaData_MSG(id).Gain = double(buffer(offset_Meta+98+44*channelCount_Meta{id,1}:offset_Meta+98+45*channelCount_Meta{id,1}-1));
                        %更新offset
                        offset_Meta = offset_Meta+98+45*channelCount_Meta{id,1};%根据设备数量修改的话，每个循环更新offsets
                        
                        
                    end
                    
                    thisTailToken = buffer(offset_Meta :offset_Meta +1);
                    if isequal(thisTailToken, tailToken_Meta)
                        i = i + totalLength_Meta;
                    else
                        disp('bug meta pkgs: Wrong TailToken_Meta');
                        break;
                    end
                    
                    
                    if Flag_Meta==0 %整体转发
                        Flag_Transfer=0;
                       %% 目前已经解析完meta包的全部信息，下面简化并提取有用信息
                        PersonName_unique=unique({MetaData_MSG(:).PersonName},'stable');
                        
                        for idx_subject=1:length(PersonName_unique)
                            PersonName_now=PersonName_unique{idx_subject};
                            PersonLoc_now=find(strcmp({MetaData_MSG.PersonName},PersonName_now)==1);
                            
                            field_SubjectUnique=PersonName_unique;
                            field_SubjectIdx=idx_subject;
                            field_SensorName_sort={};
                            field_ChannelName_sort={};
                            
                            field_SensorIdx_Start=1;
                            
                            for idx_Module=1:length(PersonLoc_now)
                                
                                ChannelTypes_nowModule=MetaData_MSG(PersonLoc_now(idx_Module)).ChannelTypes;
                                ChannelTypes_nowModule=reshape(ChannelTypes_nowModule,10,length(ChannelTypes_nowModule)/10);
                                ChannelTypes_nowModule=ChannelTypes_nowModule';
                                ChannelTypes_nowModule_reshape={};
                                ChannelNames_nowModule=MetaData_MSG(PersonLoc_now(idx_Module)).ChannelNames;
                                ChannelNames_nowModule=reshape(ChannelNames_nowModule,10,length(ChannelNames_nowModule)/10);
                                ChannelNames_nowModule=ChannelNames_nowModule';
                                ChannelNames_nowModule_reshape={};
                                for idx_chan=1:size(ChannelTypes_nowModule,1)
                                    ChannelTypes_nowModule_reshape{idx_chan,1}=strrep(ChannelTypes_nowModule(idx_chan,:),native2unicode(0),'');
                                    ChannelNames_nowModule_reshape{idx_chan,1}=strrep(ChannelNames_nowModule(idx_chan,:),native2unicode(0),'');
                                end
                                SensorTypes_nowModule=unique(ChannelTypes_nowModule_reshape(1:end-1),'stable');%最后一个通道是trigger，要单独考虑
                                
                                DataCountPerChannels_all=MetaData_MSG(PersonLoc_now(idx_Module)).DataCountPerChannels;
                                PointLocation_allSensor={};
                                for idx_sensor=1:length(SensorTypes_nowModule)
                                    SensorChanLoc_now=find(strcmp(ChannelTypes_nowModule_reshape,SensorTypes_nowModule{idx_sensor})==1);
                                    
                                    PointLocation=[];
                                    for idx_chan_nowsensor=1:length(SensorChanLoc_now)
                                        Chan_now_idx=SensorChanLoc_now(idx_chan_nowsensor);
                                        
                                        if Chan_now_idx==1
                                            PointLocation_Start=1;
                                            PointLocation_End=PointLocation_Start+DataCountPerChannels_all(Chan_now_idx)-1;
                                        else
                                            PointLocation_Start=sum(DataCountPerChannels_all(1:(Chan_now_idx-1)))+1;
                                            PointLocation_End=PointLocation_Start+DataCountPerChannels_all(Chan_now_idx)-1;
                                        end
                                        
                                        PointLocation=[PointLocation PointLocation_Start:PointLocation_End];
                                    end
                                    PointLocation_allSensor{idx_sensor,1}=PointLocation;
                                end
                                
                                
                                Chan_now_idx=length(DataCountPerChannels_all);
                                PointLocation_Start=sum(DataCountPerChannels_all(1:(Chan_now_idx-1)))+1;
                                PointLocation_End=PointLocation_Start+DataCountPerChannels_all(Chan_now_idx)-1;
                                
                                PointLocation=[PointLocation_Start:PointLocation_End];
                                
                                PointLocation_allSensor{idx_sensor+1,1}=PointLocation;
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                
                                field_SensorDataLoc=zeros(length(SensorTypes_nowModule)+1,5);
                                
                                data_start=1;
                                for idx_sensor=1:length(SensorTypes_nowModule)
                                    SensorChanLoc_now=find(strcmp(ChannelTypes_nowModule_reshape,SensorTypes_nowModule{idx_sensor})==1);
                                    
                                    DataCountPerChannels_now=MetaData_MSG(PersonLoc_now(idx_Module)).DataCountPerChannels(SensorChanLoc_now(1));
                                    data_end=data_start+DataCountPerChannels_now*length(SensorChanLoc_now)-1;
                                    
                                    field_SensorDataLoc(idx_sensor,:)=[data_start,data_end,length(SensorChanLoc_now),...
                                        DataCountPerChannels_now,...
                                        MetaData_MSG(PersonLoc_now(idx_Module)).SampleRates(SensorChanLoc_now(1))];
                                    data_start=data_end+1;
                                    
                                    field_SensorName_sort{1,end+1}=SensorTypes_nowModule{idx_sensor};
                                    field_SensorName_sort{2,end}=MetaData_MSG(PersonLoc_now(idx_Module)).SampleRates(SensorChanLoc_now(1));
                                    
                                    field_ChannelName_sort{1,end+1}=ChannelNames_nowModule_reshape(SensorChanLoc_now);
                                end
                                DataCountPerChannels_now=MetaData_MSG(PersonLoc_now(idx_Module)).DataCountPerChannels(end);
                                data_end=data_start+DataCountPerChannels_now-1;
                                
                                field_SensorDataLoc(idx_sensor+1,:)=[data_start,data_end,1,...
                                    DataCountPerChannels_now,...
                                    MetaData_MSG(PersonLoc_now(idx_Module)).SampleRates(end)];
                                field_SensorName=SensorTypes_nowModule;
                                field_SensorName{end+1}='Trigger';
                                field_SensorName_sort{1,end+1}='Trigger';
                                field_SensorName_sort{2,end}=1000;
                                field_ChannelName_sort{1,end+1}={'Trigger'};
                                
                                field_SensorIdx=field_SensorIdx_Start+[1:length(SensorTypes_nowModule)+1]-1;
                                field_SensorIdx_Start=field_SensorIdx(end)+1;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SubjectUnique=field_SubjectUnique;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SubjectIdx=field_SubjectIdx;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorDataLoc=field_SensorDataLoc;
                                
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorDataLoc_Point=PointLocation_allSensor;
                                
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorName=field_SensorName;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorIdx=field_SensorIdx;
                                
                            end
                            
                            for idx_Module=1:length(PersonLoc_now)
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorName_sort=field_SensorName_sort;
                                MetaData_MSG(PersonLoc_now(idx_Module)).ChannelName_sort=field_ChannelName_sort;
                                MetaData_MSG(PersonLoc_now(idx_Module)).Flag_Transfer=Flag_Transfer;
                            end
                        end
                        %% 目前构建完成meta包的结构体，MetaData_MSG
                        obj.MetaData_MSG_Jellyfish=MetaData_MSG;
                        ringBuffer.BufferContruct(MetaData_MSG,Flag_Meta); %MetaData_MSG
                        fwrite(TCPIP_in, headandtailToken_OK, 'uint8');
                    elseif Flag_Meta==1 %单探头转发
                        Flag_Transfer=1;
                       %% 目前已经解析完meta包的全部信息，下面简化并提取有用信息
                        PersonName_unique=unique({MetaData_MSG(:).PersonName},'stable');
                        
                        for idx_subject=1:length(PersonName_unique)
                            PersonName_now=PersonName_unique{idx_subject};
                            PersonLoc_now=find(strcmp({MetaData_MSG.PersonName},PersonName_now)==1);
                            
                            field_SubjectUnique=PersonName_unique;
                            field_SubjectIdx=idx_subject;
                            field_SensorName_sort={};
                            field_ChannelName_sort={};
                            
                            field_SensorIdx_Start=1;
                            
                            for idx_Module=1:length(PersonLoc_now)
                                ChannelTypes_nowModule=MetaData_MSG(PersonLoc_now(idx_Module)).ChannelTypes;
                                ChannelTypes_nowModule=reshape(ChannelTypes_nowModule,10,length(ChannelTypes_nowModule)/10);
                                ChannelTypes_nowModule=ChannelTypes_nowModule';
                                ChannelTypes_nowModule_reshape={};
                                ChannelNames_nowModule=MetaData_MSG(PersonLoc_now(idx_Module)).ChannelNames;
                                ChannelNames_nowModule=reshape(ChannelNames_nowModule,10,length(ChannelNames_nowModule)/10);
                                ChannelNames_nowModule=ChannelNames_nowModule';
                                ChannelNames_nowModule_reshape={};
                                for idx_chan=1:size(ChannelTypes_nowModule,1) 
                                    ChannelTypes_nowModule_reshape{idx_chan,1}=strrep(ChannelTypes_nowModule(idx_chan,:),native2unicode(0),'');
                                    ChannelNames_nowModule_reshape{idx_chan,1}=strrep(ChannelNames_nowModule(idx_chan,:),native2unicode(0),'');
                                end
                                SensorTypes_nowModule=unique(ChannelTypes_nowModule_reshape,'stable');
                                
                                DataCountPerChannels_all=MetaData_MSG(PersonLoc_now(idx_Module)).DataCountPerChannels;
                                PointLocation_allSensor={};
                                for idx_sensor=1:length(SensorTypes_nowModule)
                                    SensorChanLoc_now=find(strcmp(ChannelTypes_nowModule_reshape,SensorTypes_nowModule{idx_sensor})==1);
                                    
                                    PointLocation=[];
                                    for idx_chan_nowsensor=1:length(SensorChanLoc_now)
                                        Chan_now_idx=SensorChanLoc_now(idx_chan_nowsensor);
                                        
                                        if Chan_now_idx==1
                                            PointLocation_Start=1;
                                            PointLocation_End=PointLocation_Start+DataCountPerChannels_all(Chan_now_idx)-1;
                                        else
                                            PointLocation_Start=sum(DataCountPerChannels_all(1:(Chan_now_idx-1)))+1;
                                            PointLocation_End=PointLocation_Start+DataCountPerChannels_all(Chan_now_idx)-1;
                                        end
                                        
                                        PointLocation=[PointLocation PointLocation_Start:PointLocation_End];
                                    end
                                    PointLocation_allSensor{idx_sensor,1}=PointLocation;
                                end
                                
                                
                                field_SensorDataLoc=zeros(length(SensorTypes_nowModule),5);
                                
                                data_start=1;
                                for idx_sensor=1:length(SensorTypes_nowModule)
                                    SensorChanLoc_now=find(strcmp(ChannelTypes_nowModule_reshape,SensorTypes_nowModule{idx_sensor})==1);
                                    
                                    DataCountPerChannels_now=MetaData_MSG(PersonLoc_now(idx_Module)).DataCountPerChannels(SensorChanLoc_now(1));
                                    data_end=data_start+DataCountPerChannels_now*length(SensorChanLoc_now)-1;
                                    
                                    field_SensorDataLoc(idx_sensor,:)=[data_start,data_end,length(SensorChanLoc_now),...
                                        DataCountPerChannels_now,...
                                        MetaData_MSG(PersonLoc_now(idx_Module)).SampleRates(SensorChanLoc_now(1))];
                                    data_start=data_end+1;
                                    
                                    field_SensorName_sort{1,end+1}=SensorTypes_nowModule{idx_sensor};
                                    field_SensorName_sort{2,end}=MetaData_MSG(PersonLoc_now(idx_Module)).SampleRates(SensorChanLoc_now(1));
                                    
                                    field_ChannelName_sort{1,end+1}=ChannelNames_nowModule_reshape(SensorChanLoc_now);
                                end

                                field_SensorName=SensorTypes_nowModule;

                                field_SensorIdx=field_SensorIdx_Start+[1:length(SensorTypes_nowModule)]-1;
                                field_SensorIdx_Start=field_SensorIdx(end)+1;
                                
                                MetaData_MSG(PersonLoc_now(idx_Module)).SubjectUnique=field_SubjectUnique;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SubjectIdx=field_SubjectIdx;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorDataLoc=field_SensorDataLoc;
                                
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorDataLoc_Point=PointLocation_allSensor;
                                
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorName=field_SensorName;
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorIdx=field_SensorIdx;
                                
                            end
                            
                            for idx_Module=1:length(PersonLoc_now)
                                MetaData_MSG(PersonLoc_now(idx_Module)).SensorName_sort=field_SensorName_sort;
                                MetaData_MSG(PersonLoc_now(idx_Module)).ChannelName_sort=field_ChannelName_sort;
                                MetaData_MSG(PersonLoc_now(idx_Module)).Flag_Transfer=Flag_Transfer;
                            end
                            
                        end
                        %% 目前构建完成meta包的结构体，MetaData_MSG
                        obj.MetaData_MSG_Jellyfish=MetaData_MSG;
                        obj.SN_all=[MetaData_MSG(:).SerialNumber];
                        ringBuffer.BufferContruct(MetaData_MSG,Flag_Meta); %根据MetaData_MSG，构建结构体
                        fwrite(TCPIP_in, headandtailToken_OK, 'uint8');
                    end
                    

                    
                   
                    
                elseif isequal(buffer(i:i+1),headToken)
                    
                    %% 最新版，Jellyfish数据传输方案
                    headerLength = typecast(buffer(i+2:i+5),'uint32');      %包头长度 4字节
                    totalLength = typecast(buffer(i+6:i+9),'uint32');       %包总长度 4字节
                    
                    StartTimestamp = typecast(buffer(i+10:i+13),'uint32');  
                    TimestampLength = typecast(buffer(i+14:i+17),'uint32');
                    
                    triggerCounter = typecast(buffer(i+18:i+21),'uint32');
                    Flag_Data = typecast(buffer(i+22:i+25),'uint32');

                    ModuleCount =  typecast(buffer(i+26:i+29),'uint32');  
                    
                    offset = i+headerLength+4*ModuleCount;
                    
                    datanow=cputime;
                    TimeStamp_Save=[double(StartTimestamp);datanow];
                                
                    if offset+totalLength-1>n
                        break
                    end
                        
                    if Flag_Data==0
                        Flag_Transfer=0;
                        Data_allModule={};

                        for idx_Module = 1:ModuleCount

                             SerialNumber=typecast(buffer(offset:offset+3),'uint32');
                            channelCount = obj.MetaData_MSG_Jellyfish(idx_Module). ChannelCount;
                            nPoints = obj.MetaData_MSG_Jellyfish(idx_Module).DataCountPerChannels;%每个通道的数据量
                            datas = typecast(buffer(offset+4+channelCount:offset+4+channelCount+sum(nPoints)*4-1),'single');
                            offset = offset + 4+channelCount+sum(nPoints)*4;
                            Data_allModule{1,idx_Module} =datas;
                        end
                        Data_all={};
                        for idx_Module=1:length(Data_allModule)
                            datanow=Data_allModule{idx_Module};
                            
                            ensorDataLoc_now=obj.MetaData_MSG_Jellyfish(idx_Module).SensorDataLoc;
                            for idx_sensor=1:size(ensorDataLoc_now,1)
                                datapointnow=datanow(obj.MetaData_MSG_Jellyfish(idx_Module).SensorDataLoc_Point{idx_sensor,1});
                                Data_Sensor_now=reshape(datapointnow,...
                                    ensorDataLoc_now(idx_sensor,4),ensorDataLoc_now(idx_sensor,3));
                                Data_all{obj.MetaData_MSG_Jellyfish(idx_Module).SensorIdx(idx_sensor),...
                                    obj.MetaData_MSG_Jellyfish(idx_Module).SubjectIdx}=Data_Sensor_now';
                            end
                        end
                        
                        if isempty(Data_all_out)
                            Data_all_out=Data_all;
                        else
                            for idx_subject=1:size(Data_all,2)
                                for idx_sensor=1:size(Data_all,1)
                                    Data_all_out{idx_sensor,idx_subject}=cat(2,Data_all_out{idx_sensor,idx_subject},Data_all{idx_sensor,idx_subject});
                                end
                            end
                        end
                        StartTimestamp_all(1,end+1)=StartTimestamp;
                        
                        thisTailToken = buffer(offset + 34*triggerCounter:offset + 34*triggerCounter+1);
                        if isequal(thisTailToken, tailToken)
                            i = i + totalLength;
                        else
                            disp('bug pkgs !!!!!!');
                            break;
                        end
                    elseif Flag_Data==1
                        Flag_Transfer=1;
                        
                        SerialNumber=typecast(buffer(offset:offset+3),'uint32');
                        idx_Module=find(obj.SN_all==SerialNumber);%
                        %% 根据SN号，判定idx_sensor、idx_subject,即数据块保存位置
                        channelCount = obj.MetaData_MSG_Jellyfish(idx_Module). ChannelCount;
                        nPoints = obj.MetaData_MSG_Jellyfish(idx_Module).DataCountPerChannels;%每个通道的数据量
                        datas = typecast(buffer(offset+4+channelCount:offset+4+channelCount+sum(nPoints)*4-1),'single');
                        offset = offset + 4+channelCount+sum(nPoints)*4;

                        
                        Data_all={};%
                            datanow=datas;
                            ensorDataLoc_now=obj.MetaData_MSG_Jellyfish(idx_Module).SensorDataLoc;
                            for idx_sensor=1:size(ensorDataLoc_now,1)
                                datapointnow=datanow(obj.MetaData_MSG_Jellyfish(idx_Module).SensorDataLoc_Point{idx_sensor,1});
                                Data_Sensor_now=reshape(datapointnow,...
                                    ensorDataLoc_now(idx_sensor,4),ensorDataLoc_now(idx_sensor,3));
                                Data_all{obj.MetaData_MSG_Jellyfish(idx_Module).SensorIdx(idx_sensor),...
                                    obj.MetaData_MSG_Jellyfish(idx_Module).SubjectIdx}=Data_Sensor_now';
                                
                            end
                        
                        Data_all_out{1,end+1}=Data_all;
                        StartTimestamp_all(1,end+1)=StartTimestamp;

                        
                        thisTailToken = buffer(offset :offset + 1);
                        if isequal(thisTailToken, tailToken)
                            i = i + totalLength;

                        else
                            disp('bug pkgs !!!!!!');
                            break;
                        end
                        
                    end
                    
                    
                else
                    i=i+1;
                end
                
            end
            buffer = buffer(i:end);

        end
        

    end
end














