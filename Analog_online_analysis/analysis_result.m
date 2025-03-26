%% 加载预测结果
load('continuous_predictions.mat'); % 加载保存的all_predictions结构体

%% 提取时间戳和置信度
% 计算窗口中心时间 (单位：秒)
time_mid = (all_predictions.start_time + all_predictions.end_time)/2;

% 提取置信度数据
confidence = all_predictions.confidence;

%% 绘制置信度曲线
figure('Position', [100 100 1200 400]) % 设置图形大小

% 主曲线
plot(time_mid, confidence, ...
    'LineWidth', 1.2, ...
    'Color', [0.2 0.4 0.8], ...
    'DisplayName', '置信度');

hold on;

% 添加阈值线（示例：标注高置信区间）
yline(0.8, '--', 'Threshold=0.8', ...
    'Color', [0.9 0.2 0.2], ...
    'LineWidth', 1.2, ...
    'LabelHorizontalAlignment', 'left');

% 标注最高置信度点
[max_conf, max_idx] = max(confidence);
plot(time_mid(max_idx), max_conf, 'o', ...
    'MarkerSize', 8, ...
    'MarkerFaceColor', [0.9 0.2 0.2], ...
    'MarkerEdgeColor', 'k', ...
    'DisplayName', '峰值置信度');

%% 图表美化
xlabel('时间 (秒)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('置信度', 'FontSize', 12, 'FontWeight', 'bold');
title('MI-EEG信号识别置信度时序曲线', 'FontSize', 14);
grid on;
legend('Location', 'northeast');

% 设置坐标轴范围
xlim([0, max(time_mid)]);
ylim([0, 1.05]);

% 优化刻度显示
ax = gca;
ax.XAxis.MinorTick = 'on';
ax.YAxis.MinorTick = 'on';
ax.FontSize = 11;

%% 保存图表
saveas(gcf, 'confidence_plot.png');
disp('图表已保存为 confidence_plot.png');