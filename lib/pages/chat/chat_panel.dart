import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:saber/pages/chat/chat_api_key_dialog.dart';
import 'package:saber/pages/chat/chat_controller.dart';

/// A slide-in chat panel that overlays the left side of the screen.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.controller,
  });

  final ChatPanelController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isOpen) {
          return const SizedBox.shrink();
        }

        return Material(
          elevation: 0,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final activeModelName = widget.controller.availableModels[widget.controller.model] ?? 
        widget.controller.model.split('/').last.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: _showModelSearchBottomSheet,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeModelName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 18, color: theme.hintColor),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.controller.isLoadingModels)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: 'Update Models',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => widget.controller.fetchRemoteModels(),
                ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.controller.autoAttachScreenshot,
                builder: (context, autoAttach, _) {
                  return IconButton(
                    icon: Icon(
                      autoAttach ? Icons.screenshot_monitor : Icons.screenshot,
                      size: 18,
                      color: autoAttach 
                          ? theme.colorScheme.primary 
                          : theme.hintColor,
                    ),
                    tooltip: autoAttach 
                        ? 'Auto Screenshot: ON' 
                        : 'Auto Screenshot: OFF',
                    onPressed: () {
                      widget.controller.autoAttachScreenshot.value = !autoAttach;
                    },
                  );
                },
              ),
              _HeaderButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear Chat',
                onPressed: _clearChat,
              ),
              _HeaderButton(
                icon: Icons.settings,
                tooltip: 'API Key',
                onPressed: _showApiKeyDialog,
              ),
              _HeaderButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: () => widget.controller.close(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final provider = widget.controller.provider;

    if (provider == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('API Key Required'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _showApiKeyDialog,
              child: const Text('Enter API Key'),
            ),
          ],
        ),
      );
    }

    return LlmChatView(
      provider: provider,
      enableAttachments: false,
      enableVoiceNotes: false,
      welcomeMessage: '',
      responseBuilder: (context, text) {
        final latexExtensionSet = md.ExtensionSet(
          [LatexBlockSyntax()],
          [LatexInlineSyntax()],
        );

        return MarkdownBody(
          data: text,
          shrinkWrap: true,
          selectable: true,
          imageDirectory: 'https://raw.githubusercontent.com',
          extensionSet: latexExtensionSet,
          builders: {
            'latex': LatexElementBuilder(
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
          },
        );
      },
    );
  }

  void _showApiKeyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ChatApiKeyDialog(controller: widget.controller),
    );
  }

  void _clearChat() {
    widget.controller.clearHistory();
  }

  void _showModelSearchBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _ModelSearchWidget(controller: widget.controller);
      },
    );
  }
}

class _ModelSearchWidget extends StatefulWidget {
  const _ModelSearchWidget({required this.controller});

  final ChatPanelController controller;

  @override
  State<_ModelSearchWidget> createState() => _ModelSearchWidgetState();
}

class _ModelSearchWidgetState extends State<_ModelSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allModels = widget.controller.availableModels.entries.toList();
    
    allModels.sort((a, b) {
      if (a.key == widget.controller.model) return -1;
      if (b.key == widget.controller.model) return 1;
      return a.value.toLowerCase().compareTo(b.value.toLowerCase());
    });

    final filteredModels = allModels.where((entry) {
      final term = _query.toLowerCase();
      return entry.key.toLowerCase().contains(term) || entry.value.toLowerCase().contains(term);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Select AI Model',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search model... (e.g. deepseek)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _query = val;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredModels.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Model not found 🔍'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredModels.length,
                      itemBuilder: (context, index) {
                        final entry = filteredModels[index];
                        final isSelected = entry.key == widget.controller.model;

                        return ListTile(
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          subtitle: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.7) : theme.hintColor,
                            ),
                          ),
                          trailing: isSelected 
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary) 
                              : null,
                          onTap: () {
                            widget.controller.setModel(entry.key);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}