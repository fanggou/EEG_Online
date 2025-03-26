%author:chen 
%input:fea_train(m*n), 特征矩阵，每行代表一个样本，每列代表一个特征
%      label_train(m*1),标签向量，每个元素对应一个样本的标签
%output:rank(n*2),the first dimension includes the Mutual information 
%       values,and the second dimension incoude the index
%       函数返回 sort_tmp，它是一个排序后的矩阵
%all_Mul该函数计算每个特征与标签之间的互信息，并返回一个矩阵rank，其中包含特征的重要性排序
%rank(1:k,2) 表示取 rank 矩阵中前 k 行第 2 列的值，这些值表示互信息最高的特征的索引
%FBtrainf(:,rank(1:k,2)) 使用这些索引从 FBtrainf 中提取相应的特征，构建新的训练集 selFeaTrain
function sort_tmp=all_MuI(fea_train,label_train)
n=size(fea_train,1); %获取 fea_train 的行数（即样本数），并将其存储在变量 n 中         
tmp=[];%初始化一个空矩阵 tmp，用于存储每个特征的互信息值及其对应的索引
for i=1:size(fea_train,2)
    MuI=calc_MuI(fea_train(:,i),label_train,n);
    tmp=[tmp;MuI i];  %将互信息值和特征索引 i 作为一行追加到矩阵 tmp 中                
end
sort_tmp=sortrows(tmp,'descend');%对矩阵 tmp 按照第一列（互信息值）进行降序排序;sort_tmp：存储排序后的矩阵