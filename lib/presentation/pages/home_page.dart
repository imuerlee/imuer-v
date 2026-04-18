import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../../domain/entities/vpn_connection.dart';
import '../blocs/vpn/vpn_bloc.dart';
import '../blocs/vpn/vpn_event.dart';
import '../blocs/vpn/vpn_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, state) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildConnectionButton(context, state),
                const SizedBox(height: 32),
                _buildServerInfo(state),
                const SizedBox(height: 24),
                _buildSpeedGauges(state),
                const SizedBox(height: 24),
                _buildStatsCards(state),
                const SizedBox(height: 24),
                _buildLocationCard(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionButton(BuildContext context, VpnState state) {
    final isConnected = state.connection.status == VpnStatus.connected;
    final isConnecting = state.connection.status == VpnStatus.connecting;
    final isDisconnecting = state.connection.status == VpnStatus.disconnecting;

    return Column(
      children: [
        AnimatedPulse(
          pulseColor: isConnected ? AppColors.success : AppColors.primary,
          child: GestureDetector(
            onTap: () {
              if (isConnected) {
                context.read<VpnBloc>().add(const DisconnectVpn());
              } else if (!isConnecting && !isDisconnecting) {
                context.read<VpnBloc>().add(const ConnectVpn(''));
              }
            },
            child: CircularPercentIndicator(
              radius: 100,
              lineWidth: 12,
              percent: isConnected ? 1.0 : (isConnecting ? 0.7 : 0.0),
              center: _buildCenterContent(isConnected, isConnecting, isDisconnecting),
              progressColor: isConnected ? AppColors.success : AppColors.primary,
              backgroundColor: AppColors.surfaceLight,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 1000,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _getStatusText(state.connection.status),
          style: TextStyle(
            color: _getStatusColor(state.connection.status),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (state.connection.connectionDuration != null)
          Text(
            FormatUtils.formatDuration(state.connection.connectionDuration!),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildCenterContent(bool isConnected, bool isConnecting, bool isDisconnecting) {
    IconData icon;
    if (isConnecting) {
      icon = Icons.sync;
    } else if (isDisconnecting) {
      icon = Icons.sync;
    } else if (isConnected) {
      icon = Icons.power_settings_new;
    } else {
      icon = Icons.power_settings_new;
    }

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [AppColors.success.withValues(alpha: 0.3), AppColors.surface]
              : [AppColors.primary.withValues(alpha: 0.3), AppColors.surface],
        ),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.primary,
          width: 3,
        ),
      ),
      child: Icon(
        icon,
        size: 60,
        color: isConnected ? AppColors.success : AppColors.primary,
      ),
    );
  }

  Widget _buildServerInfo(VpnState state) {
    return SciFiCard(
      showGlow: state.connection.status == VpnStatus.connected,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dns,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.connection.serverName ?? 'No Server Selected',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.connection.serverAddress ?? 'Tap to select a server',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (state.connection.ping != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${state.connection.ping} ms',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauges(VpnState state) {
    return Row(
      children: [
        Expanded(
          child: _buildSpeedGauge(
            'Upload',
            state.connection.uploadSpeed ?? 0,
            AppColors.accent,
            Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSpeedGauge(
            'Download',
            state.connection.downloadSpeed ?? 0,
            AppColors.accentBlue,
            Icons.arrow_downward,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedGauge(String label, int speed, Color color, IconData icon) {
    return SciFiCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FormatUtils.formatSpeed(speed),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(VpnState state) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Upload',
            FormatUtils.formatBytes(state.connection.totalUpload ?? 0),
            AppColors.accent,
            Icons.upload_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Download',
            FormatUtils.formatBytes(state.connection.totalDownload ?? 0),
            AppColors.accentBlue,
            Icons.download_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return SciFiCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(VpnState state) {
    return SciFiCard(
      showGlow: state.connection.status == VpnStatus.connected,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.public,
              color: AppColors.secondary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.connection.serverCountry ?? 'Unknown',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.connection.serverCity != null)
                  Text(
                    state.connection.serverCity!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (state.connection.status == VpnStatus.connected)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.success,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText(VpnStatus status) {
    switch (status) {
      case VpnStatus.disconnected:
        return 'Disconnected';
      case VpnStatus.connecting:
        return 'Connecting...';
      case VpnStatus.connected:
        return 'Connected';
      case VpnStatus.disconnecting:
        return 'Disconnecting...';
      case VpnStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(VpnStatus status) {
    switch (status) {
      case VpnStatus.disconnected:
        return AppColors.textSecondary;
      case VpnStatus.connecting:
        return AppColors.warning;
      case VpnStatus.connected:
        return AppColors.success;
      case VpnStatus.disconnecting:
        return AppColors.warning;
      case VpnStatus.error:
        return AppColors.error;
    }
  }
}
