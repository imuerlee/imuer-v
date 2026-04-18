import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../../domain/entities/server_node.dart';
import '../../data/services/config_parser_service.dart';
import '../../data/services/subscription_service.dart';
import '../../injection.dart';
import '../blocs/server/server_bloc.dart';
import '../blocs/server/server_event.dart';
import '../blocs/server/server_state.dart';
import '../blocs/vpn/vpn_bloc.dart';
import '../blocs/vpn/vpn_event.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        if (state.status == ServerStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return Column(
          children: [
            _buildHeader(context, state),
            Expanded(
              child: state.servers.isEmpty
                  ? _buildEmptyState(context)
                  : _buildServerList(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ServerState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server List',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${state.servers.length} servers',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionButton(
                icon: Icons.sync,
                label: 'Test All',
                onTap: () {
                  context.read<ServerBloc>().add(const TestAllServersLatency());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildImportButton(
                  context: context,
                  icon: Icons.qr_code_scanner,
                  label: 'QR Code',
                  onTap: () => _showQRScanner(context),
                ),
                const SizedBox(width: 8),
                _buildImportButton(
                  context: context,
                  icon: Icons.content_paste,
                  label: 'Clipboard',
                  onTap: () => _importFromClipboard(context),
                ),
                const SizedBox(width: 8),
                _buildImportButton(
                  context: context,
                  icon: Icons.folder_open,
                  label: 'File',
                  onTap: () => _importFromFile(context),
                ),
                const SizedBox(width: 8),
                _buildImportButton(
                  context: context,
                  icon: Icons.cloud_download,
                  label: 'Subscribe',
                  onTap: () => _showSubscriptionDialog(context),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.add,
                  label: 'Add',
                  isPrimary: true,
                  onTap: () => _showAddServerDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? AppColors.background : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? AppColors.background : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Servers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import servers or add manually',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddServerDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Server'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(BuildContext context, ServerState state) {
    final sortedServers = state.serversByLatency;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedServers.length,
      itemBuilder: (context, index) {
        final server = sortedServers[index];
        return _buildServerCard(context, server);
      },
    );
  }

  Widget _buildServerCard(BuildContext context, ServerNode server) {
    final latencyColor = _getLatencyColor(server.latency);

    return Dismissible(
      key: Key(server.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      onDismissed: (_) {
        context.read<ServerBloc>().add(DeleteServer(server.id));
      },
      child: SciFiCard(
        showGlow: false,
        margin: const EdgeInsets.only(bottom: 12),
        onTap: () {
          context.read<VpnBloc>().add(ConnectVpn(server.id));
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getCountryFlag(server.country ?? ''),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getProtocolColor(server.protocol).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          server.protocol.name.toUpperCase(),
                          style: TextStyle(
                            color: _getProtocolColor(server.protocol),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${server.address}:${server.port}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: latencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    server.latency != null ? '${server.latency} ms' : '--',
                    style: TextStyle(
                      color: latencyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    context.read<ServerBloc>().add(TestServerLatency(server.id));
                  },
                  child: const Icon(
                    Icons.refresh,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getLatencyColor(int? latency) {
    if (latency == null) return AppColors.textTertiary;
    if (latency < 100) return AppColors.success;
    if (latency < 200) return AppColors.warning;
    return AppColors.error;
  }

  Color _getProtocolColor(ServerProtocol protocol) {
    switch (protocol) {
      case ServerProtocol.vmess:
        return AppColors.primary;
      case ServerProtocol.vless:
        return AppColors.secondary;
      case ServerProtocol.ss:
        return AppColors.accentBlue;
      case ServerProtocol.ssr:
        return AppColors.accent;
      case ServerProtocol.trojan:
        return AppColors.warning;
      case ServerProtocol.wireguard:
        return AppColors.success;
      case ServerProtocol.hysteria:
      case ServerProtocol.hysteria2:
        return AppColors.error;
      case ServerProtocol.http:
        return AppColors.textSecondary;
      case ServerProtocol.socks5:
        return AppColors.textTertiary;
    }
  }

  String _getCountryFlag(String country) {
    final flags = {
      'United States': '🇺🇸',
      'United Kingdom': '🇬🇧',
      'Japan': '🇯🇵',
      'Singapore': '🇸🇬',
      'Hong Kong': '🇭🇰',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Australia': '🇦🇺',
      'Canada': '🇨🇦',
      'Netherlands': '🇳🇱',
      'South Korea': '🇰🇷',
      'Taiwan': '🇹🇼',
      'Russia': '🇷🇺',
      'India': '🇮🇳',
      'Brazil': '🇧🇷',
      'Unknown': '🌐',
    };
    return flags[country] ?? '🌐';
  }

  void _showQRScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _QRScannerView(
          onServerAdded: (server) {
            context.read<ServerBloc>().add(AddServer(server));
          },
        ),
      ),
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final bloc = context.read<ServerBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final text = data.text!.trim();
        List<ServerNode> servers = [];

        servers = ConfigParserService.parseConfig(text);

        if (servers.isEmpty && text.startsWith('http')) {
          servers = await _fetchServersFromUrl(text);
        }

        if (servers.isEmpty) {
          final normalized = text
              .replaceAll(RegExp(r'\s+'), '\n')
              .replaceAll(RegExp(r',+'), '\n');
          servers = ConfigParserService.parseConfig(normalized);
        }

        if (servers.isEmpty) {
          try {
            final decoded = utf8.decode(base64Decode(text));
            servers = ConfigParserService.parseConfig(decoded);
          } catch (_) {}
        }

        if (servers.isNotEmpty) {
          for (final server in servers) {
            bloc.add(AddServer(server));
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text('Imported ${servers.length} server(s)'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No valid servers found in clipboard'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to read clipboard: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<List<ServerNode>> _fetchServersFromUrl(String url) async {
    try {
      final subscriptionService = SubscriptionService(
        prefs: getIt<SharedPreferences>(),
      );
      await subscriptionService.setSubscriptionUrl(url);
      return await subscriptionService.fetchSubscriptionServers(url);
    } catch (e) {
      return [];
    }
  }

  Future<void> _importFromFile(BuildContext context) async {
    final bloc = context.read<ServerBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final servers = ConfigParserService.parseFromFile(content);

        if (servers.isNotEmpty) {
          for (final server in servers) {
            bloc.add(AddServer(server));
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text('Imported ${servers.length} server(s) from file'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No valid servers found in file'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to read file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSubscriptionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => _SubscriptionView(
        onServersImported: (servers) {
          for (final server in servers) {
            context.read<ServerBloc>().add(AddServer(server));
          }
        },
      ),
    );
  }

  void _showAddServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => _AddServerForm(
        onAdd: (server) {
          context.read<ServerBloc>().add(AddServer(server));
          Navigator.pop(dialogContext);
        },
      ),
    );
  }
}

class _QRScannerView extends StatefulWidget {
  final Function(ServerNode) onServerAdded;

  const _QRScannerView({required this.onServerAdded});

  @override
  State<_QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<_QRScannerView> {
  MobileScannerController? _controller;
  bool _hasScanned = false;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = 'Failed to initialize camera';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (_hasScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;
      
      final value = barcode.rawValue!;
      List<ServerNode> servers = ConfigParserService.parseConfig(value);
      
      if (servers.isEmpty && value.startsWith('http')) {
        try {
          final subscriptionService = SubscriptionService(
            prefs: getIt<SharedPreferences>(),
          );
          await subscriptionService.setSubscriptionUrl(value);
          servers = await subscriptionService.fetchSubscriptionServers(value);
        } catch (_) {}
      }
      
      if (servers.isEmpty) {
        final normalized = value
            .replaceAll(RegExp(r'\s+'), '\n')
            .replaceAll(RegExp(r',+'), '\n');
        servers = ConfigParserService.parseConfig(normalized);
      }
      
      if (servers.isNotEmpty) {
        _hasScanned = true;
        for (final server in servers) {
          widget.onServerAdded(server);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${servers.length} server(s)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scan QR Code',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (_controller != null)
                    IconButton(
                      icon: const Icon(
                        Icons.flash_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _controller?.toggleTorch(),
                    ),
                  if (_controller != null)
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _controller?.switchCamera(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, color: AppColors.error, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : MobileScanner(
                        controller: _controller,
                        onDetect: _handleDetection,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: AppColors.error, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  error.errorDetails?.message ?? 'Camera error',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Point camera at QR code',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionView extends StatefulWidget {
  final Function(List<ServerNode>) onServersImported;

  const _SubscriptionView({required this.onServersImported});

  @override
  State<_SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<_SubscriptionView> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isPreviewMode = false;
  String? _error;
  SubscriptionInfo? _info;
  List<ServerNode> _previewServers = [];

  @override
  void initState() {
    super.initState();
    _loadSavedSubscription();
  }

  Future<void> _loadSavedSubscription() async {
    final subscriptionService = SubscriptionService(prefs: getIt<SharedPreferences>());
    final savedUrl = await subscriptionService.getSubscriptionUrl();
    final savedName = await subscriptionService.getSubscriptionName();
    if (savedUrl != null && mounted) {
      setState(() {
        _urlController.text = savedUrl;
        _nameController.text = savedName ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubscription() async {
    if (_urlController.text.isEmpty) {
      setState(() => _error = 'Please enter subscription URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subscriptionService = SubscriptionService(
        prefs: getIt<SharedPreferences>(),
      );
      
      await subscriptionService.setSubscriptionUrl(_urlController.text);
      if (_nameController.text.isNotEmpty) {
        await subscriptionService.setSubscriptionName(_nameController.text);
      }
      final servers = await subscriptionService.fetchSubscriptionServers(_urlController.text);
      _info = await subscriptionService.getSubscriptionInfo(_urlController.text);
      
      if (servers.isNotEmpty) {
        setState(() {
          _previewServers = servers;
          _isPreviewMode = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No servers found in subscription';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _confirmImport() {
    widget.onServersImported(_previewServers);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${_previewServers.length} servers'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _backToForm() {
    setState(() {
      _isPreviewMode = false;
      _previewServers = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreviewMode) {
      return _buildPreviewMode();
    }
    return _buildFormMode();
  }

  Widget _buildPreviewMode() {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _backToForm,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Found ${_previewServers.length} servers',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (_info != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_info!.total != null)
                    Text(
                      'Total: ${_formatBytes(_info!.total!)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  if (_info!.remaining != null)
                    Text(
                      'Remaining: ${_formatBytes(_info!.remaining!)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  if (_info!.expire != null)
                    Text(
                      'Expires: ${_info!.expire!.toLocal()}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _previewServers.length,
              itemBuilder: (context, index) {
                final server = _previewServers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            server.protocol.name.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${server.address}:${server.port}',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmImport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Import ${_previewServers.length} Servers'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormMode() {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subscription',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Import servers from a subscription URL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Subscription Name (optional)',
              hintText: 'My Subscription',
              prefixIcon: Icon(Icons.bookmark, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Subscription URL',
              hintText: 'https://example.com/subscription',
              prefixIcon: const Icon(Icons.link, color: AppColors.primary),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _fetchSubscription,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Fetch Subscription'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _AddServerForm extends StatefulWidget {
  final Function(ServerNode) onAdd;

  const _AddServerForm({required this.onAdd});

  @override
  State<_AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<_AddServerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _uuidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _methodController = TextEditingController();
  final _pathController = TextEditingController();
  final _sniController = TextEditingController();
  final _hostController = TextEditingController();
  final _flowController = TextEditingController();
  final _fingerprintController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _peerPublicKeyController = TextEditingController();
  final _mtuController = TextEditingController();
  final _obfsPasswordController = TextEditingController();
  final _protocolParamController = TextEditingController();
  final _obfsController = TextEditingController();
  final _pluginController = TextEditingController();
  final _pluginOptsController = TextEditingController();
  final _alpnController = TextEditingController();
  final _reservedController = TextEditingController();
  final _authUsernameController = TextEditingController();
  final _authPasswordController = TextEditingController();
  final _speedUpController = TextEditingController();
  final _speedDownController = TextEditingController();
  final _serviceNameController = TextEditingController();
  final _localAddressController = TextEditingController();
  final _dnsController = TextEditingController();
  final _endpointController = TextEditingController();

  ServerProtocol _protocol = ServerProtocol.vmess;
  String _network = 'tcp';
  String _security = 'tls';
  bool _auth = false;
  bool _allowInsecure = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _uuidController.dispose();
    _passwordController.dispose();
    _methodController.dispose();
    _pathController.dispose();
    _sniController.dispose();
    _hostController.dispose();
    _flowController.dispose();
    _fingerprintController.dispose();
    _publicKeyController.dispose();
    _privateKeyController.dispose();
    _peerPublicKeyController.dispose();
    _mtuController.dispose();
    _obfsPasswordController.dispose();
    _protocolParamController.dispose();
    _obfsController.dispose();
    _pluginController.dispose();
    _pluginOptsController.dispose();
    _alpnController.dispose();
    _reservedController.dispose();
    _authUsernameController.dispose();
    _authPasswordController.dispose();
    _speedUpController.dispose();
    _speedDownController.dispose();
    _serviceNameController.dispose();
    _localAddressController.dispose();
    _dnsController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Server',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProtocolSelector(),
                const SizedBox(height: 20),
                _buildSectionTitle('Basic'),
                _buildTextField(
                  controller: _nameController,
                  label: 'Remark',
                  hint: 'Server remark',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'example.com or IP',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _portController,
                  label: 'Port',
                  hint: '443',
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                ..._buildProtocolFields(),
                const SizedBox(height: 20),
                _buildNetworkSection(),
                const SizedBox(height: 20),
                _buildSecuritySection(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Add Server'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildProtocolSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Protocol',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ServerProtocol.values.map((protocol) {
            final isSelected = _protocol == protocol;
            return ChoiceChip(
              label: Text(protocol.name.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _protocol = protocol);
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceLight,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildProtocolFields() {
    switch (_protocol) {
      case ServerProtocol.vmess:
        return [
          _buildSectionTitle('VMess'),
          _buildTextField(
            controller: _uuidController,
            label: 'UUID',
            hint: 'Enter UUID',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Security',
            value: _methodController.text.isEmpty ? 'auto' : _methodController.text,
            items: ['auto', 'aes-128-gcm', 'chacha20-poly1305', 'aes-128-ctr', 'aes-256-ctr'],
            onChanged: (v) => _methodController.text = v ?? 'auto',
          ),
        ];
      case ServerProtocol.vless:
        return [
          _buildSectionTitle('VLESS'),
          _buildTextField(
            controller: _uuidController,
            label: 'UUID',
            hint: 'Enter UUID',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Flow',
            value: _flowController.text.isEmpty ? 'none' : _flowController.text,
            items: ['none', 'xtls-rprx-vision', 'xtls-rprx-direct', 'xtls-rprx-origin'],
            onChanged: (v) => _flowController.text = v ?? 'none',
          ),
        ];
      case ServerProtocol.ss:
        return [
          _buildSectionTitle('Shadowsocks'),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Encryption Password',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Method',
            value: _methodController.text.isEmpty ? 'chacha20-ietf-poly1305' : _methodController.text,
            items: ['chacha20-ietf-poly1305', 'aes-256-gcm', 'aes-128-gcm', 'aes-256-ctr', 'aes-128-ctr'],
            onChanged: (v) => _methodController.text = v ?? 'chacha20-ietf-poly1305',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _pluginController,
            label: 'Plugin',
            hint: 'v2ray-plugin (optional)',
          ),
          if (_pluginController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _pluginOptsController,
              label: 'Plugin Options',
              hint: 'host=example.com;tls',
            ),
          ],
        ];
      case ServerProtocol.ssr:
        return [
          _buildSectionTitle('ShadowsocksR'),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'SSR Password',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Method',
            value: _methodController.text.isEmpty ? 'chacha20-ietf-poly1305' : _methodController.text,
            items: ['chacha20-ietf-poly1305', 'aes-256-gcm', 'aes-128-gcm', 'aes-256-ctr', 'aes-128-ctr'],
            onChanged: (v) => _methodController.text = v ?? 'chacha20-ietf-poly1305',
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Protocol',
            value: _protocolParamController.text.isEmpty ? 'origin' : _protocolParamController.text.split(':').first,
            items: ['origin', 'auth_sha1_v2', 'auth_sha1_v4', 'auth_aes128_sha1', 'auth_aes128_md5'],
            onChanged: (v) {
              final current = _protocolParamController.text.contains(':') 
                  ? _protocolParamController.text.split(':').skip(1).join(':')
                  : '';
              _protocolParamController.text = '$v:$current';
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'OBFS',
            value: _obfsController.text.isEmpty ? 'plain' : _obfsController.text,
            items: ['plain', 'http_simple', 'http_post', 'tls1.2_ticket_auth', 'tls1.2_ticket_fastauth'],
            onChanged: (v) => _obfsController.text = v ?? 'plain',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _obfsPasswordController,
            label: 'OBFS Password',
            hint: 'OBFS password (optional)',
          ),
        ];
      case ServerProtocol.trojan:
        return [
          _buildSectionTitle('Trojan'),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Trojan Password',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _sniController,
            label: 'SNI',
            hint: 'example.com',
          ),
        ];
      case ServerProtocol.wireguard:
        return [
          _buildSectionTitle('WireGuard'),
          _buildTextField(
            controller: _privateKeyController,
            label: 'Private Key',
            hint: 'Local private key',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _localAddressController,
            label: 'Local Address',
            hint: '10.0.0.2/32',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _peerPublicKeyController,
            label: 'Peer Public Key',
            hint: 'Server public key',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _dnsController,
            label: 'DNS',
            hint: '1.1.1.1',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _endpointController,
            label: 'Endpoint',
            hint: 'example.com:51820',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _mtuController,
            label: 'MTU',
            hint: '1420',
            keyboardType: TextInputType.number,
          ),
        ];
      case ServerProtocol.hysteria:
        return [
          _buildSectionTitle('Hysteria'),
          _buildTextField(
            controller: _passwordController,
            label: 'Auth String',
            hint: 'Password',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _obfsPasswordController,
            label: 'OBFS Password',
            hint: 'OBFS password (optional)',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _speedUpController,
                  label: 'Up (Mbps)',
                  hint: '100',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _speedDownController,
                  label: 'Down (Mbps)',
                  hint: '100',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ];
      case ServerProtocol.hysteria2:
        return [
          _buildSectionTitle('Hysteria2'),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Hysteria2 password',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _obfsPasswordController,
            label: 'OBFS Password',
            hint: 'OBFS password (optional)',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _speedUpController,
                  label: 'Up (Mbps)',
                  hint: '100',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _speedDownController,
                  label: 'Down (Mbps)',
                  hint: '100',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ];
      case ServerProtocol.http:
        return [
          _buildSectionTitle('HTTP'),
          Row(
            children: [
              const Text('Authentication', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              Switch(
                value: _auth,
                onChanged: (v) => setState(() => _auth = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_auth) ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _authUsernameController,
              label: 'Username',
              hint: 'username',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _authPasswordController,
              label: 'Password',
              hint: 'password',
              obscure: true,
            ),
          ],
        ];
      case ServerProtocol.socks5:
        return [
          _buildSectionTitle('SOCKS5'),
          Row(
            children: [
              const Text('Authentication', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              Switch(
                value: _auth,
                onChanged: (v) => setState(() => _auth = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_auth) ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _authUsernameController,
              label: 'Username',
              hint: 'username',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _authPasswordController,
              label: 'Password',
              hint: 'password',
              obscure: true,
            ),
          ],
        ];
    }
  }

  Widget _buildNetworkSection() {
    if (_protocol == ServerProtocol.wireguard ||
        _protocol == ServerProtocol.hysteria ||
        _protocol == ServerProtocol.hysteria2 ||
        _protocol == ServerProtocol.http ||
        _protocol == ServerProtocol.socks5) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Transport'),
        _buildDropdownField(
          label: 'Network',
          value: _network,
          items: ['tcp', 'ws', 'grpc'],
          onChanged: (v) => setState(() => _network = v ?? 'tcp'),
        ),
        if (_network == 'ws') ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _hostController,
            label: 'Host',
            hint: 'example.com',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _pathController,
            label: 'Path',
            hint: '/path',
          ),
        ],
        if (_network == 'grpc') ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _serviceNameController,
            label: 'Service Name',
            hint: 'grpc_service_name',
          ),
        ],
      ],
    );
  }

  Widget _buildSecuritySection() {
    if (_protocol == ServerProtocol.wireguard ||
        _protocol == ServerProtocol.hysteria ||
        _protocol == ServerProtocol.hysteria2 ||
        _protocol == ServerProtocol.http ||
        _protocol == ServerProtocol.socks5) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Security'),
        if (_protocol == ServerProtocol.vmess) ...[
          _buildDropdownField(
            label: 'Security',
            value: _security,
            items: ['tls', 'none'],
            onChanged: (v) => setState(() => _security = v ?? 'tls'),
          ),
        ],
        if (_protocol == ServerProtocol.vless) ...[
          _buildDropdownField(
            label: 'Security',
            value: _security,
            items: ['tls', 'reality'],
            onChanged: (v) => setState(() => _security = v ?? 'tls'),
          ),
        ],
        if (_protocol == ServerProtocol.trojan) ...[
          _buildTextField(
            controller: _sniController,
            label: 'SNI',
            hint: 'example.com',
          ),
        ],
        if ((_security == 'tls' || _protocol == ServerProtocol.vmess || _protocol == ServerProtocol.trojan) && _protocol != ServerProtocol.ss) ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _sniController,
            label: 'SNI',
            hint: 'example.com',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _alpnController,
            label: 'ALPN',
            hint: 'h2,http/1.1',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _fingerprintController,
            label: 'Fingerprint',
            hint: 'chrome (optional)',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Allow Insecure', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              Switch(
                value: _allowInsecure,
                onChanged: (v) => setState(() => _allowInsecure = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ],
        if (_protocol == ServerProtocol.vless && _security == 'reality') ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _publicKeyController,
            label: 'Public Key',
            hint: 'Reality public key',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _reservedController,
            label: 'Short ID',
            hint: 'Optional',
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
      ),
      dropdownColor: AppColors.surfaceLight,
      style: const TextStyle(color: AppColors.textPrimary),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final server = ServerNode(
        id: const Uuid().v4(),
        name: _nameController.text,
        address: _addressController.text,
        port: int.tryParse(_portController.text) ?? 443,
        protocol: _protocol,
        uuid: _uuidController.text.isNotEmpty ? _uuidController.text : null,
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        method: _methodController.text.isNotEmpty ? _methodController.text : null,
        path: _pathController.text.isNotEmpty ? _pathController.text : null,
        sni: _sniController.text.isNotEmpty ? _sniController.text : null,
        host: _hostController.text.isNotEmpty ? _hostController.text : null,
        alpn: _alpnController.text.isNotEmpty ? _alpnController.text : null,
        fingerprint: _fingerprintController.text.isNotEmpty ? _fingerprintController.text : null,
        flow: _flowController.text.isNotEmpty && _flowController.text != 'none' ? _flowController.text : null,
        publicKey1: _publicKeyController.text.isNotEmpty ? _publicKeyController.text : null,
        privateKey: _privateKeyController.text.isNotEmpty ? _privateKeyController.text : null,
        peerPublicKey: _peerPublicKeyController.text.isNotEmpty ? _peerPublicKeyController.text : null,
        mtu: int.tryParse(_mtuController.text),
        reserved: _reservedController.text.isNotEmpty ? _reservedController.text : null,
        plugin: _pluginController.text.isNotEmpty ? _pluginController.text : null,
        pluginOpts: _pluginOptsController.text.isNotEmpty ? _pluginOptsController.text : null,
        protocolParam: _protocolParamController.text.isNotEmpty ? _protocolParamController.text : null,
        obfs: _obfsController.text.isNotEmpty ? _obfsController.text : null,
        obfsParam: _obfsPasswordController.text.isNotEmpty ? _obfsPasswordController.text : null,
        auth: _auth ? true : null,
        authUsername: _authUsernameController.text.isNotEmpty ? _authUsernameController.text : null,
        authPassword: _authPasswordController.text.isNotEmpty ? _authPasswordController.text : null,
        allowInsecure: _allowInsecure ? true : null,
        speedLimitUp: int.tryParse(_speedUpController.text),
        speedLimitDown: int.tryParse(_speedDownController.text),
        network: _network,
        tls: _security == 'none' ? 'none' : _security,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onAdd(server);
    }
  }
}
