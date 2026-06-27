import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:screenshot/screenshot.dart';

import 'openrouter_provider.dart';

/// Manages the chat panel state and OpenRouter provider lifecycle.
class ChatPanelController extends ChangeNotifier {
  ChatPanelController() {
    _loadState();
    fetchRemoteModels();
  }

  static const _apiKeyKey = 'openrouter_api_key';
  static const _modelKey = 'openrouter_selected_model';
  static const _historyKey = 'openrouter_chat_history';
  static const _systemInstructionKey = 'openrouter_system_instruction';
  static const _defaultModel = 'openai/gpt-4o-mini';
  final _secureStorage = const FlutterSecureStorage();

  // Screenshot Controller
  final screenshotController = ScreenshotController();

  final ValueNotifier<bool> autoAttachScreenshot = ValueNotifier<bool>(false);

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  String? _apiKey;
  String? get apiKey => _apiKey;

  String? _systemInstruction;
  String? get systemInstruction => _systemInstruction;

  String _model = _defaultModel;
  String get model => _model;

  OpenRouterProvider? _provider;
  OpenRouterProvider? get provider => _provider;

  // Dynamic Models Cache: Map from model ID to readable name
  final Map<String, String> availableModels = {
    'openai/gpt-4o-mini': 'GPT-4o Mini',
    'google/gemini-2.5-flash': 'Gemini 2.5 Flash',
    'deepseek/deepseek-chat': 'DeepSeek V3',
  };

  bool isLoadingModels = false;

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    _ensureProvider();
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  Future<Uint8List?> captureScreenshot() async {
    try {
      return await screenshotController.capture();
    } catch (_) {
      return null;
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await _secureStorage.write(key: _apiKeyKey, value: key);
    _ensureProvider();
    notifyListeners();
  }

  Future<void> setSystemInstruction(String instruction) async {
    _systemInstruction = instruction;
    await _secureStorage.write(key: _systemInstructionKey, value: instruction);
    _ensureProvider();
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    _systemInstruction = null;
    _provider = null;
    await _secureStorage.delete(key: _apiKeyKey);
    await _secureStorage.delete(key: _systemInstructionKey);
    await _secureStorage.delete(key: _historyKey);
    notifyListeners();
  }

  Future<void> setModel(String selectedModel) async {
    _model = selectedModel;
    await _secureStorage.write(key: _modelKey, value: selectedModel);
    _ensureProvider();
    notifyListeners();
  }

  void clearHistory() {
    _provider?.history = [];
    _saveHistory();
    notifyListeners();
  }

  /// Automatically fetch available models from OpenRouter API
  Future<void> fetchRemoteModels() async {
    if (isLoadingModels) return;
    isLoadingModels = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://openrouter.ai/api/v1/models')).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>?;
        if (data != null) {
          final Map<String, String> tempModels = {};
          for (final modelItem in data) {
            final id = modelItem['id'] as String?;
            final name = modelItem['name'] as String?;
            if (id != null && name != null) {
              tempModels[id] = name;
            }
          }
          if (tempModels.isNotEmpty) {
            availableModels.clear();
            availableModels.addAll(tempModels);
            if (!availableModels.containsKey(_model)) {
              availableModels[_model] = _model.split('/').last.toUpperCase();
            }
          }
        }
      }
    } catch (_) {
    } finally {
      isLoadingModels = false;
      notifyListeners();
    }
  }

  Future<void> _loadState() async {
    try {
      _apiKey = await _secureStorage.read(key: _apiKeyKey);
      _systemInstruction = await _secureStorage.read(key: _systemInstructionKey);
      final savedModel = await _secureStorage.read(key: _modelKey);
      if (savedModel != null && savedModel.isNotEmpty) {
        _model = savedModel;
      }
      
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        _ensureProvider();
        
        final historyString = await _secureStorage.read(key: _historyKey);
        if (historyString != null && _provider != null) {
          final List<dynamic> jsonList = jsonDecode(historyString) as List<dynamic>;
          final chatHistory = jsonList.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
          _provider!.history = chatHistory;
        }
        
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    if (_provider == null) return;
    try {
      final jsonList = _provider!.history.map((msg) => msg.toJson()).toList();
      final historyString = jsonEncode(jsonList);
      await _secureStorage.write(key: _historyKey, value: historyString);
    } catch (_) {}
  }

  String _resolveKey() {
    return _apiKey ?? '';
  }

  void _ensureProvider() {
    final key = _resolveKey();
    if (key.isEmpty) return;
    
    final oldHistory = _provider?.history.toList() ?? [];
    
    _provider = OpenRouterProvider.positional(
      key, 
      'https://openrouter.ai/api/v1', 
      _model, 
      captureScreenshot, 
      autoAttachScreenshot, 
      _saveHistory,
      _systemInstruction,
    );
    _provider!.history = oldHistory;
  }
}
