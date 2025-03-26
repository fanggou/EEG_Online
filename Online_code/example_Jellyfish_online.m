

% jellyfish online fetch data demo
% Subfunctions: m files in this path
% mat-files required: none
%
% Author: Hanlei Li, lihanlei@neuracle.cn
% Copyright (c) 2016 Neuracle, Inc. All Rights Reserved. http://neuracle.cn/

clear all;
clc;
close all;
instrreset;

deviceName = 'JellyFish';       % deviceName must be 'JellyFish'
nChan = 0;                      % default
srate = 0;                      % default

% Modify subject, sensor, and channel info in DataMesssage: required fields
subject_toshow='1';             % type the real subject name
sensor_toshow='EEG';            % choose one type of signals
channel_toshow='T8';            % type the focused channel. Please type 'Trigger' if trigger channel is focused
nDevice= 1;                     % type the number of device, default
ipData = '127.0.0.1';        % type IP address of the DataServer in JellyFish
portData = 8712;                % type port of the DataServer in JellyFish, default


bufferSize = 5;                 % length of ringbuffer: 5s
datasaveflag=0;                 % whether save data to bin file or not



%% open data server
dataServer = DataServer(deviceName,nChan, ipData, portData, srate,datasaveflag,bufferSize);
dataServer.Open();

pause(1.5);                    % waiting 1.5s for creating inner buffer
DataMessage = dataServer.GetDataMessage();
%DataMeta = dataServer.GetMetaData();
idx_subject_toshow=find(contains({DataMessage(:).SubjectName},subject_toshow)==1);
idx_sensor_toshow=find(strcmp([DataMessage(idx_subject_toshow).SensorName],sensor_toshow)==1);
idx_sensor_toshow=idx_sensor_toshow(1);
idx_chan_toshow=find(strcmp([DataMessage(idx_subject_toshow).SensorChannelName{1,idx_sensor_toshow(1)}],channel_toshow)==1);

% set the data filename
if datasaveflag==1
    timenow=datestr(now,'yyyymmdd-HHMMSS');
    filename={};
    datapath=['.\Data\' timenow];
    if ~isfolder(datapath)
        mkdir(datapath);
    end
    for idx_subject=1:length(DataMessage)
        for idx_senor=1:length(DataMessage(idx_subject).SensorName)
            Chan_num_now=length(DataMessage(idx_subject).SensorChannelName{1,idx_senor});
            filename{idx_senor,idx_subject} = [datapath '\' strcat('nbChan-',num2str(Chan_num_now,'%02d'),...
                '-','Subject',num2str(idx_subject,'%02d'),'-','Sensor',num2str(idx_senor,'%02d'),'-',timenow , '.txt')];
            fileID{idx_senor,idx_subject}= fopen(filename{idx_senor,idx_subject},'w');
        end
    end
    
end

%% online plot

%%% all data in ringbuffer were extracted 
t={};% time is not necessary. All sensors' sampling rate was stored in DataMessage by default.
for idx_subject=1:length(DataMessage)  
    sensorSrate_nowsub=DataMessage(idx_subject).SensorSrate;
    for idx_sensor=1:length(sensorSrate_nowsub)
        srate_now=double(sensorSrate_nowsub{idx_sensor});
        t{idx_sensor,idx_subject}=[0:bufferSize*srate_now-1]./srate_now;
    end
end

figure;
t_show = t{idx_sensor_toshow,idx_subject_toshow};
for i = 1:20
    [raw,trigger,~,~] = dataServer.GetBufferData();%all the data and trigger in ringbuffer
    rawdata_plot=raw{idx_sensor_toshow,idx_subject_toshow};
    plot(t_show,rawdata_plot(idx_chan_toshow,:))
    title(['Subject: ' subject_toshow '; Sensor: ' sensor_toshow '; Channel: ' channel_toshow])
    pause(0.2);
end

close gcf
%%  only obtain and save the latest data, without overlap signal

dataServer.ResetnUpdate;
pause(0.2);
rawdata_all=[];
figure;
for i = 1:20 %循环
    [raw_latest,trigger_latest,~,~] = dataServer.GetLatestData();%just the latest data  
    rawdata_plot=raw_latest{idx_sensor_toshow,idx_subject_toshow};
    
    if ~isempty(rawdata_plot)
        rawdata_all=[rawdata_all,rawdata_plot];
        plot(rawdata_plot(idx_chan_toshow,:))
        title(['Subject: ' subject_toshow '; Sensor: ' sensor_toshow '; Channel: ' channel_toshow])
    else
        disp('该循环为空')
    end
    
    %Save the data to the corresponding file
    if datasaveflag==1
        for idx_subject=1:size(raw_latest,2)
            for idx_senor=1:size(raw_latest,1)
                if ~isempty(fileID{idx_senor,idx_subject})
                    fwrite(fileID{idx_senor,idx_subject},raw_latest{idx_senor,idx_subject},'double',0,'ieee-le'); 

                end
            end
        end
    end
    pause(0.2);
end
close gcf
figure,plot(rawdata_all(idx_chan_toshow,:))

%% Get/Clear trigger in the ringBuffer if necessary
% the sampling rate of trigger channel was fixed, 1000Hz
% all subjects and all sensors share one trigger

sensor_toshow='Trigger';
channel_toshow='Trigger';

idx_subject_toshow=find(contains({DataMessage(:).SubjectName},subject_toshow)==1);
idx_sensor_toshow=find(strcmp([DataMessage(idx_subject_toshow).SensorName],sensor_toshow)==1);

figure;
for i = 1:20
    [~,rawdata_plot,~,~] = dataServer.GetBufferData();%all the trigger in ringbuffer    
    if any(rawdata_plot>0)
        dataServer.ClearTrigger(idx_sensor_toshow(1));
    end
    [~,rawdata_plot2,~,~] = dataServer.GetBufferData();
    if any(rawdata_plot>0)
        plot(rawdata_plot),hold on
        plot(rawdata_plot2),hold off
        legend('Maintain trigger','Clear trigger')
        title(['Subject: ' subject_toshow '; Sensor: ' sensor_toshow '; Channel: ' channel_toshow])
    end
    
    pause(0.5);
end


%% close data server
if datasaveflag==1
    dataServer.EndSaveFile();
end

dataServer.Close();














