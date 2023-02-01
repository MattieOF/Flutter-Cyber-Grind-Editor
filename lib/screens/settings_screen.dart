import 'package:cgef/state/app_state.dart';
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
                          onChanged: (value) {
                            setState(() {
                              appState.setUseImagesForPrefabs(value!);
                            });
                          },
                          value: appState.useImagesForPrefabs,
                          secondary: const Icon(Icons.remove_red_eye),
                        )
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
