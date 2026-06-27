import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

/// OpenRouter API provider for [flutter_ai_toolkit].
class OpenRouterProvider implements LlmProvider {
  // Positional constructor prevents auto-redaction named parameters compilation bugs
  OpenRouterProvider.positional(
    this._apiKey,
    this._baseUrl,
    this._model,
    this._captureScreenshot,
    this._autoAttachScreenshotNotifier,
    this._onHistoryChanged,
    this._systemInstruction,
  );

  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final Future<Uint8List?> Function() _captureScreenshot;
  final ValueListenable<bool> _autoAttachScreenshotNotifier;
  final VoidCallback _onHistoryChanged;
  final String? _systemInstruction;

  final List<ChatMessage> _history = <ChatMessage>[];

  @override
  Iterable<ChatMessage> get history => List.unmodifiable(_history);

  @override
  set history(Iterable<ChatMessage> history) {
    _history
      ..clear()
      ..addAll(history);
    notifyListeners();
    _onHistoryChanged();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  final List<VoidCallback> _listeners = <VoidCallback>[];

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  http.Client? _activeClient;

  Future<Map<String, dynamic>> _buildRequestBody({
    required String prompt,
    Iterable<Attachment> attachments = const [],
    bool useHistory = true,
  }) async {
    final messages = <Map<String, dynamic>>[];

    if (_systemInstruction != null && _systemInstruction.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': _systemInstruction.trim()});
    }

    if (useHistory) {
      for (final msg in _history) {
        if (msg.origin == MessageOrigin.user && msg.text != null) {
          messages.add({'role': 'user', 'content': msg.text});
        } else if (msg.origin == MessageOrigin.llm && msg.text != null) {
          messages.add({'role': 'assistant', 'content': msg.text});
        }
      }
    }

    dynamic clientContent = prompt;
    if (_autoAttachScreenshotNotifier.value) {
      try {
        final screenshotBytes = await _captureScreenshot();
        if (screenshotBytes != null) {
          final base64Image = base64Encode(screenshotBytes);
          clientContent = [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,$base64Image',
              }
            }
          ];
        }
      } catch (_) {
      }
    }

    messages.add({'role': 'user', 'content': clientContent});

    return {
      'model': _model,
      'messages': messages,
      'stream': true,
    };
  }

  Stream<String> _parseSseStream(Stream<String> rawStream) async* {
    await for (final line in rawStream) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {
        }
      }
    }
  }

  Stream<String> _sendRequest(Map<String, dynamic> body, Completer<void> abortCompleter) async* {
    final uri = Uri.parse('${_baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions');
    
    _activeClient?.close();
    final client = http.Client();
    _activeClient = client;

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'HTTP-Referer': 'https://github.com/knightscode139/saber-ai',
        'X-Title': 'Saber AI',
      })
      ..body = jsonEncode(body);

    final responseFuture = client.send(request);
    
    unawaited(abortCompleter.future.then((_) {
      client.close();
    }));

    final response = await responseFuture;

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('OpenRouter API error ${response.statusCode}: $errorBody');
    }

    yield* _parseSseStream(
      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    final controller = StreamController<String>();
    final abortCompleter = Completer<void>();
    _buildRequestBody(
      prompt: prompt,
      attachments: attachments,
      useHistory: false,
    ).then((body) {
      _sendRequest(body, abortCompleter).listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
        cancelOnError: true,
      );
    }).catchError((Object error, StackTrace stackTrace) {
      controller.addError(error, stackTrace);
      controller.close();
    });

    controller.onCancel = () {
      abortCompleter.complete();
      _activeClient?.close();
    };

    return controller.stream;
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    final controller = StreamController<String>();
    final abortCompleter = Completer<void>();

    _history.add(ChatMessage.user(prompt, attachments));

    final llmMessage = ChatMessage.llm();
    _history.add(llmMessage);
    notifyListeners();
    _onHistoryChanged();

    _buildRequestBody(
      prompt: prompt,
      attachments: attachments,
      useHistory: true,
    ).then((body) {
      _sendRequest(body, abortCompleter).listen(
        (chunk) {
          llmMessage.append(chunk);
          controller.add(chunk);
          notifyListeners();
        },
        onDone: () {
          controller.close();
          notifyListeners();
          _onHistoryChanged();
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
          controller.close();
          notifyListeners();
          _onHistoryChanged();
        },
        cancelOnError: true,
      );
    }).catchError((Object error, StackTrace stackTrace) {
      controller.addError(error, stackTrace);
      controller.close();
      notifyListeners();
      _onHistoryChanged();
    });

    controller.onCancel = () {
      abortCompleter.complete();
      _activeClient?.close();
    };

    return controller.stream;
  }
}
