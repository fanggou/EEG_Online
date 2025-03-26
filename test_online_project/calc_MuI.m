%计算两列向量之间的互信息
%u1：输入计算的向量1
%u2：输入计算的向量2
%wind_size：向量的维度,用于直方图计算的窗口大小
function mi = calc_MuI(u1, u2, wind_size)
x = [u1, u2];
n = wind_size;
[xrow, xcol] = size(x);% xrow 和 xcol 分别是 x 的行数和列数
bin = zeros(xrow,xcol);% bin 初始化为一个全零矩阵，用于存储每个数据点所属的箱
pmf = zeros(n, 2);% pmf 初始化为一个全零矩阵，用于存储概率质量函数（PMF）
for i = 1:2
    minx = min(x(:,i));
    maxx = max(x(:,i));
    binwidth = (maxx - minx) / n;
    edges = minx + binwidth*(0:n);
    histcEdges = [-Inf edges(2:end-1) Inf];
    [occur,bin(:,i)] = histc(x(:,i),histcEdges,1); %通过直方图方式计算单个向量的直方图分布
    pmf(:,i) = occur(1:n)./xrow;
end
%计算u1和u2的联合概率密度
jointOccur = accumarray(bin,1,[n,n]);  %（xi，yi）两个数据同时落入n*n等分方格中的数量即为联合概率密度
jointPmf = jointOccur./xrow;
%计算互信息和归一化互信息
Hx = -(pmf(:,1))'*log2(pmf(:,1)+eps);% Hx 和 Hy 分别是 u1 和 u2 的熵
Hy = -(pmf(:,2))'*log2(pmf(:,2)+eps);
Hxy = -(jointPmf(:))'*log2(jointPmf(:)+eps);% Hxy 是 u1 和 u2 的联合熵
MI = Hx+Hy-Hxy;% MI 是互信息
mi = MI/sqrt(Hx*Hy);% mi 是归一化互信息
