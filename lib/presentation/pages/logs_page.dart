import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../../data/services/log_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final LogService _logService = LogService();
  List<LogEntry> _logs = [];
  LogLevel _minLevel = LogLevel.debug;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    await _logService.initialize();
    _logs = _logService.getLogs(minLevel: _minLevel);
    setState(() => _isLoading = false);
    
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _refreshLogs() async {
    await _logService.initialize();
    _logs = _logService.getLogs(minLevel: _minLevel);
    setState(() {});
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Logs', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to clear all logs? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logService.clearLogs();
      await _loadLogs();
    }
  }

  Future<void> _exportLogs() async {
    final content = await _logService.exportLogs();
    await Share.share(content, subject: 'NebulaVPN Logs');
  }

  Future<void> _copyLogs() async {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln(log.toFormattedString());
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copied to clipboard'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return AppColors.textTertiary;
      case LogLevel.info:
        return AppColors.primary;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Connection Logs', style: TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center, 
                       color: AppColors.primary),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: 'Auto-scroll',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'copy':
                  _copyLogs();
                  break;
                case 'export':
                  _exportLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Text('Copy to clipboard', style: TextStyle(color: AppColors.textPrimary)),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Share logs', style: TextStyle(color: AppColors.textPrimary)),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear logs', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          const Text('Filter: ', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<LogLevel>(
            value: _minLevel,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.primary),
            underline: const SizedBox(),
            items: LogLevel.values.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(
                  level.name.toUpperCase(),
                  style: TextStyle(color: _getLevelColor(level)),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _minLevel = value);
                _refreshLogs();
              }
            },
          ),
          const Spacer(),
          Text(
            '${_logs.length} entries',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refreshLogs,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No logs available',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return SciFiCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getLevelColor(log.level).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.level.name.toUpperCase(),
                  style: TextStyle(
                    color: _getLevelColor(log.level),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (log.source != null) ...[
                const SizedBox(width: 8),
                Text(
                  '[${log.source}]',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatTime(log.timestamp),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            log.message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}';
  }
}
