/// 🤖 Generated wholesale or partially with Hermes Agent; Sparkle ✨
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_controller.dart';

/// A dialog to enter or update the OpenRouter API key and system instructions.
class ChatApiKeyDialog extends StatefulWidget {
  const ChatApiKeyDialog({
    super.key,
    required this.controller,
  });

  final ChatPanelController controller;

  @override
  State<ChatApiKeyDialog> createState() => _ChatApiKeyDialogState();
}

class _ChatApiKeyDialogState extends State<ChatApiKeyDialog> {
  final _keyController = TextEditingController();
  final _sysController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyController.text = widget.controller.apiKey ?? '';
    _sysController.text = widget.controller.systemInstruction ?? '';
  }

  @override
  void dispose() {
    _keyController.dispose();
    _sysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final key = _keyController.text.trim();
    if (key.isNotEmpty && !key.startsWith('sk-or-') && !key.startsWith('***')) {
      _showWarning('Invalid API key. Must start with "sk-or-"');
      return;
    }

    final instruction = _sysController.text.trim();

    // Only update key if it is not the obfuscated placeholder and has changed
    if (key.isNotEmpty && !key.startsWith('***')) {
      await widget.controller.setApiKey(key);
    }
    await widget.controller.setSystemInstruction(instruction);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('AI Chat Settings'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your OpenRouter API key and system instruction prompt that is sent at the start of each conversation.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-or-v1-...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter API Key';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sysController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'System Instructions (Optional)',
                  hintText: 'e.g. You are a helpful mathematics teacher.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.controller.apiKey != null)
          TextButton(
            onPressed: () async {
              await widget.controller.clearApiKey();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Reset / Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
