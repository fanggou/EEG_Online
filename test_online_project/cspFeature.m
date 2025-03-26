%%%%%%通过投影矩阵进行特征提取，通过共空间模式（CSP）投影矩阵将输入数据投影到新的空间，并提取投影后数据的方差特征。
%%%%%%然后对这些特征进行归一化并取对数，以得到最终的特征向量 feature，这些特征向量可以用于分类器的训练和测试。
%输入参数：
%  projM: csp投影矩阵，三维矩阵，维度为 (通道数, 通道数, 类别数)
%  x: 一个时间窗口的2维EEG数据。其中，第一维是采样点；第二维是通道
%  m: 投影数据矩阵的第一列和最后一列的个数。
%输出参数：
%  feature: 从列向量中提取到的特征

function feature = cspFeature(projM, data, m)
    % 输入验证
    assert(isequal(size(projM,1), size(projM,2)), '投影矩阵应为方阵');
    assert(size(projM,1) == size(data,2), '数据通道数不匹配');
    
    % 核心计算逻辑
    classNo = size(projM, 3);  % 投影矩阵的类别数
    feature = [];
    
    for k = 1:classNo
        % 正确乘法顺序: [时间点×通道] × [通道×通道] → [时间点×通道]
        Z = data * projM(:,:,k); 
        
        % 提取前m和后m个通道的方差
        var_front = var(Z(:, 1:m));        % [1×m]
        var_back = var(Z(:, end-m+1:end)); % [1×m]
        
        % 对数归一化
        log_features = log( [var_front, var_back] / sum([var_front, var_back]) );
        feature = [feature, log_features];
    end
end

% 
% function feature=cspFeature(projM,data,m)
%     
%     % 添加维度验证
%     disp('====== cspFeature维度验证 ======');
%     disp(['投影矩阵维度: ', num2str(size(projM))]); % 应为 [59 59 ...]
%     disp(['输入数据维度: ', num2str(size(data))]); % 应为 [59 N]
%     assert(size(projM,3) == 4, '每个子频带应使用4个投影矩阵');
% 
%     classNo=length(projM(1,1,:));  %获取类别数量
%     channelNo=size(data,2);           %获取通道数量
%     feature=[];                    %声明特征矩阵
%     for k=1:classNo                %classNo为类数量
%         Z=data*projM(:,:,k); %projected data matrix
%         for j=1:m
%             feature=[feature; var(Z(:,j)); var(Z(:,channelNo-j+1))];  %var(A) 算矩阵A没列方差，此时默认是除N-1
%             %variances of the first and last m columns(第1和最后m列的方差)
%         end
%     end
%     feature=log(feature/sum(feature));%对提取到的 feature 特征矩阵进行归一化处理，将每个特征值除以特征矩阵的总和，然后取对数。
% end                                  %这样做的目的是为了将特征压缩到一个较小的数值范围内，使得特征值之间的差异更加显著。