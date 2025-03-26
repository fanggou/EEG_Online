%author:chen date:2024-7-31
%通过对不同频带进行滤波，然后使用CSP算法提取每个频带的特征，最终将所有频带的特征拼接在一起，
%形成最终的特征矩阵 features_train。该特征矩阵可以用于后续的分类任务。该函数能够处理二维或三维的EEG数据，适用于在线特征提取。

%input:train_data,3维 EEG数据。其中，第一维是采样点，第二维是通道数量，第三维度是trials大小
%                 2维 EEG数据。其中，第一位是采样点，第二维是通道数量
%      projMAll,  由训练集计算所得个子频带CSP投影矩阵
%      classNum,  待分类的类别数
%      sampleRate,采样率
%               m,CSP的m参数
%output:features, 融合后各子频带后的特征数组
function features_train=FBCSPOnline(train_data,projMAll,classNum,sampleRate,m,freq)
    
    if nargin < 6
        error('参数不足，需要6个输入参数');
    end
    train_data= double(train_data);
    if ndims(train_data)==3 %输入EEG数据为3维
      
        % acquire and combine feature of different frequency bands
        [q,p,k]=size(train_data);%获取总的trial次数
        filter_data=zeros(size(train_data));
        features_train=[];      %声明训练集csp特征融合数组
        numBands = length(freq)-1; % 子频带数量为频率点数量-1
       
        for i=1:numBands
    
            lower=freq(i);  %获取低频
            higher=freq(i+1);%获取高频
    
            %对各子频带进行滤波
            filter_tmp=[];
            for j = 1 : k % 对每个trial进行循环滤波,
            
                
                filter_tmp=filter_param(train_data(:,:,j),lower,higher,sampleRate,4);
                filter_data(:,:,j)=filter_tmp;
            end
    
            feature=[];  %声明本子频带特征矩阵
            for b=1:k    %循环提取特征
                feature(b,:)=cspFeature(projMAll(:,:,1+(i-1)*classNum:i*classNum),filter_data(:,:,b),m); %第三个参数m不要超过通道数的一半，不然会出现重复特征
            end
    
            tmp_data=feature;
            features_train=[features_train,tmp_data]; %拼接个自频带特征矩阵
    
        end
    else                  
       
        % 输入EEG数据为2维
        features_train=[];      %声明训练集csp特征融合数组
        numBands = length(freq)-1; % 子频带数量为频率点数量-1
    
        for i=1:numBands
           
            lower=freq(i);  %获取低频
            higher=freq(i+1);%获取高频
           
            % 滤波并转置为 [通道 × 时间点]
            filtered = filter_param(train_data, lower, higher, sampleRate, 4);
            
            % 提取当前子频带投影矩阵 (4个方向)
            currentProj = projMAll(:,:, (i-1)*classNum+1 : i*classNum);
            
            % 特征提取
            feature = cspFeature(currentProj, filtered, m);
            features_train = [features_train, feature]; 
            
            %调试信息
%             disp(['子频带 ', num2str(i), ' 投影矩阵尺寸: ', num2str(size(currentProj))]);
%             disp(['滤波后数据尺寸: ', num2str(size(filtered))]);
           

        end
    end
end

