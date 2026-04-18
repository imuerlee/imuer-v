import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../blocs/statistics/statistics_bloc.dart';
import '../blocs/statistics/statistics_state.dart';
import '../blocs/vpn/vpn_bloc.dart';
import '../blocs/vpn/vpn_state.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpnState) {
        return BlocBuilder<StatisticsBloc, StatisticsState>(
          builder: (context, statsState) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildRealTimeStats(vpnState),
                  const SizedBox(height: 24),
                  _buildSpeedChart(statsState),
                  const SizedBox(height: 24),
                  _buildTrafficOverview(statsState),
                  const SizedBox(height: 24),
                  _buildSessionStats(vpnState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Real-time network statistics',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeStats(VpnState state) {
    return Row(
      children: [
        Expanded(
          child: _buildRealtimeCard(
            'Upload Speed',
            FormatUtils.formatSpeed(state.connection.uploadSpeed ?? 0),
            AppColors.accent,
            Icons.upload_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRealtimeCard(
            'Download Speed',
            FormatUtils.formatSpeed(state.connection.downloadSpeed ?? 0),
            AppColors.accentBlue,
            Icons.download_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimeCard(String label, String value, Color color, IconData icon) {
    return SciFiCard(
      showGlow: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChart(StatisticsState state) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpnState) {
        return SciFiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Speed History',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10000,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.border.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              FormatUtils.formatSpeed(value.toInt()),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _buildSpeedSpots(vpnState),
                        isCurved: true,
                        color: AppColors.accentBlue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accentBlue.withValues(alpha: 0.3),
                              AppColors.accentBlue.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<FlSpot> _buildSpeedSpots(VpnState state) {
    final downloadSpeed = state.connection.downloadSpeed ?? 0;
    final uploadSpeed = state.connection.uploadSpeed ?? 0;
    
    if (downloadSpeed == 0 && uploadSpeed == 0) {
      return [const FlSpot(0, 0)];
    }
    
    // 使用真实速度数据：显示当前总速度（上传 + 下载）
    // fl_chart 会自动根据数据更新图表，不需要生成额外的点
    // 真实的速度历史应该由 VpnBloc 每秒推送更新
    return [FlSpot(0, (downloadSpeed + uploadSpeed).toDouble())];
  }


  Widget _buildTrafficOverview(StatisticsState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Traffic Overview',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTrafficItem(
                  'This Week',
                  FormatUtils.formatBytes(state.totalBytesThisWeek),
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrafficItem(
                  'Daily Average',
                  FormatUtils.formatBytes(state.averageDailyBytes),
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(state.dailyTraffic),
                barGroups: _generateBarGroups(state.dailyTraffic),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final index = value.toInt();
                        if (index >= 0 && index < days.length) {
                          return Text(
                            days[index],
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY(List dailyTraffic) {
    if (dailyTraffic.isEmpty) return 1000000;
    final maxBytes = dailyTraffic.fold<int>(
      0,
      (max, traffic) => (traffic.uploadBytes + traffic.downloadBytes) > max
          ? (traffic.uploadBytes + traffic.downloadBytes)
          : max,
    );
    return maxBytes.toDouble() * 1.2;
  }

  List<BarChartGroupData> _generateBarGroups(List dailyTraffic) {
    // 如果有真实数据，使用真实数据
    if (dailyTraffic.isNotEmpty) {
      return List.generate(7, (index) {
        final traffic = dailyTraffic.length > index ? dailyTraffic[index] : null;
        final bytes = traffic != null 
            ? (traffic.uploadBytes ?? 0) + (traffic.downloadBytes ?? 0)
            : 0.0;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: bytes.toDouble(),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      });
    }
    
    // 没有数据时返回空图表
    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: 0,
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _buildTrafficItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionStats(VpnState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Session Statistics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSessionItem(
            'Connection Duration',
            state.connection.connectionDuration != null
                ? FormatUtils.formatDuration(state.connection.connectionDuration!)
                : '00:00',
            Icons.access_time,
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildSessionItem(
            'Total Upload',
            FormatUtils.formatBytes(state.connection.totalUpload ?? 0),
            Icons.upload_outlined,
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildSessionItem(
            'Total Download',
            FormatUtils.formatBytes(state.connection.totalDownload ?? 0),
            Icons.download_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
