%%%%基于共空间模式算法计算出一个投影矩阵，通过计算每个类别的协方差矩阵，进行白化变换和特征分解
%%%%最终得到每个类别的CSP投影矩阵。这个投影矩阵可以用于将输入数据投影到一个新的空间，
%%%%在这个空间中，不同类别的数据具有最大的方差差异，从而增强信号的分类性能。
%%%%这里的多分类CSP采用的是一对多策略实现对二分类CSP的扩展，对四分类需要计算四个投影矩阵W1,W2,W3,W4,
%输入参数：
%   x:3维 EEG数据。其中，第一维是采样点，第二维是通道数量，第三维度是trials大小
%   y: 一维列向量标签 范围是从1到分类数量，长度与x的第三维保持一致
%注意：这里y标签只能从1开始，往后延，不能用-1 1这种标签格式
function projM=cspProjMatrix(x,y)
trialNo=length(y); %获取标签长度
classNo=max(y);    %获取标签类别数量
channelNo=length(x(1,:,1)); %获取通道数量
% 计算每个类别的投影矩阵
for k=1:classNo    %对每一类进行训练
    N_a=sum(y==k); %当前类的trials数量
    N_b=trialNo-N_a;%其他类的试验数量
    R_a=zeros(channelNo,channelNo); %申请[通道数量*通道数量] 方阵大小的空间
    R_b=zeros(channelNo,channelNo);
    for i=1:trialNo 
        R=x(:,:,i)'*x(:,:,i); % 计算协方差矩阵
        %R=cov(x(:,:,i)); 
        R=R/trace(R);%归一化协方差矩阵
        if y(i)==k   
            R_a=R_a+R;%当前类，累加到当前类的协方差矩阵
        else         
            R_b=R_b+R;%其他类，累加到其他类的协方差矩阵
        end
    end
    R_a=R_a/N_a;%平均当前类的协方差矩阵
    R_b=R_b/N_b;% 平均其他类的协方差矩阵
    [V,D]=svd(R_a+R_b);  %对协方差矩阵之和进行奇异值分解
    %对奇异值进行降序排列
    [D_sorted, idx] = sort(diag(D), 'descend');
    V_sorted = V(:, idx);
     %计算P白化矩阵，P矩阵返回为W
    D_sqrt_inv = diag(1./sqrt(D_sorted));  % 对奇异值的平方根进行取倒数
    W=D_sqrt_inv*V_sorted';      
    S_a=W*R_a*W';  %变换为当前类的协方差矩阵
    [V,D]=svd(S_a); %对变换后的协方差矩阵进行特征值分解
    %对特征值进行降序排列
    [D_sorted, idx] = sort(diag(D), 'descend');
    V_sorted = V(:, idx);
    projM(:,:,k)=W'*V_sorted;  %投影矩阵， 最后投影矩阵的大小为 [通道数量 通道数量 类别数量] 其中第三维度为每个类的滤波器
end 
