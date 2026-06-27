import 'package:flutter/material.dart';
import 'package:saber/components/home/sentry_consent_dialog.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/main.dart'; // import chatPanelController
import 'package:saber/pages/chat/chat_panel.dart';
import 'package:saber/pages/home/browse.dart';
import 'package:saber/pages/home/recent_notes.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:screenshot/screenshot.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.subpage, required this.path});

  final String subpage;
  final String? path;

  @override
  State<HomePage> createState() => _HomePageState();

  static const recentSubpage = 'recent';
  static const browseSubpage = 'browse';
  static const whiteboardSubpage = 'whiteboard';
  static const settingsSubpage = 'settings';
  static const List<String> subpages = [
    recentSubpage,
    browseSubpage,
    whiteboardSubpage,
    settingsSubpage,
  ];
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    super.initState();
    _showDialogs();
  }

  void _showDialogs() async {
    await null; // initState must be completed before using context
    if (!mounted) return;
    UpdateManager.showUpdateDialog(context);
    SentryConsentDialog.showIfNeeded(context);
  }

  void _setState() {
    if (mounted) setState(() {});
  }

  Widget get body {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(widget.subpage),
        child: switch (widget.subpage) {
          HomePage.browseSubpage => BrowsePage(path: widget.path),
          HomePage.whiteboardSubpage => const Whiteboard(),
          HomePage.settingsSubpage => const SettingsPage(),
          _ => const RecentPage(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen splitting layout width: near half of the width on tablets (45%)
    final double chatPanelWidth = MediaQuery.sizeOf(context).width * 0.45;

    Widget mainContent = ResponsiveNavbar(
      selectedIndex: HomePage.subpages.indexOf(widget.subpage),
      body: body,
    );

    // If whiteboard in fullscreen, bypass the general navbar, but KEEP layout shifting and screenshot!
    final bool isWhiteboardFullscreen = widget.subpage == HomePage.whiteboardSubpage &&
        DynamicMaterialApp.isFullscreen;
    if (isWhiteboardFullscreen) {
      mainContent = body;
    }

    return Scaffold(
      body: ListenableBuilder(
        listenable: chatPanelController,
        builder: (context, _) {
          final double currentWidth = chatPanelController.isOpen ? chatPanelWidth : 0.0;
          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: currentWidth,
                child: ChatPanel(controller: chatPanelController),
              ),
              Expanded(
                child: Screenshot(
                  controller: chatPanelController.screenshotController,
                  child: Stack(
                    children: [
                      mainContent,
                      Positioned(
                        left: 12,
                        top: MediaQuery.of(context).padding.top + 12, // Align with the top layout elements gracefully (no blocking, perfectly placed)
                        child: ListenableBuilder(
                          listenable: chatPanelController,
                          builder: (context, _) {
                            if (chatPanelController.isOpen) return const SizedBox.shrink();
                            return SizedBox(
                              width: 32,
                              height: 32,
                              child: FloatingActionButton.small(
                                heroTag: 'chat-toggle',
                                tooltip: 'AI Sohbet',
                                onPressed: () => chatPanelController.toggle(),
                                child: const Icon(Icons.auto_awesome, size: 14),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    super.dispose();
  }
}