import 'dart:io';

import 'package:cgef/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _returnToMenu() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    AppState appState = AppState.of(context);

    return Focus(
      onFocusChange: (value) {
        if (!value) _focusNode.requestFocus();
      },
      child: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (value) {
          if (value.logicalKey == LogicalKeyboardKey.escape) {
            _returnToMenu();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        CheckboxListTile(
                          title: const Text("Use images for prefabs"),
                          subtitle: const Text(
                              "Some people prefer the lil characters instead"),
                          onChanged: (value) {
                            setState(() {
                              appState.setUseImagesForPrefabs(value!);
                            });
                          },
                          value: appState.useImagesForPrefabs,
                          secondary: const Icon(Icons.remove_red_eye),
                        ),
                        if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
                          CheckboxListTile(
                            title: const Text("Invert Mouse Look"),
                            subtitle: const Text(
                                "If checked, mouse look in the 3D preview will be inverted"),
                            onChanged: (value) {
                              setState(() {
                                appState.setInvertMouselook(value!);
                              });
                            },
                            value: appState.invertMouselook,
                            secondary: const Icon(Icons.mouse),
                          ),
                        if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
                          ListTile(
                            title: Row(
                              children: [
                                const Text("FOV"),
                                const SizedBox(width: 20),
                                Text(
                                  appState.camFov.toStringAsPrecision(2),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("FOV for the 3D preview"),
                                Row(
                                  children: [
                                    const Text("30"),
                                    Expanded(
                                      child: Slider(
                                        value: appState.camFov,
                                        onChanged: (value) {
                                          appState.setFOV(value);
                                        },
                                        min: 30,
                                        max: 90,
                                      ),
                                    ),
                                    const Text("90"),
                                  ],
                                )
                              ],
                            ),
                            leading: const Icon(Icons.remove_red_eye),
                          ),
                        if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
                          ListTile(
                            title: Row(
                              children: [
                                const Text("Preview Camera Sensitivity"),
                                const SizedBox(width: 20),
                                Text(
                                  appState.previewCamSensitivity
                                      .toStringAsPrecision(2),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text("0.15"),
                                    Expanded(
                                      child: Slider(
                                        value: appState.previewCamSensitivity,
                                        onChanged: (value) {
                                          appState
                                              .setPreviewCamSensitivity(value);
                                        },
                                        min: 0.15,
                                        max: 1.5,
                                      ),
                                    ),
                                    const Text("1.5"),
                                  ],
                                )
                              ],
                            ),
                            leading: const Icon(Icons.mouse),
                          ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
