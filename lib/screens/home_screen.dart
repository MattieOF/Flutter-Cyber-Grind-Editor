import 'dart:io';

import 'package:cgef/state/app_state.dart';
import 'package:cgef/state/grid_state.dart';
import 'package:cgef/widgets/input/fat_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:layout/layout.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String appVersion = '';

  void _openFilePicker() async {
    AppState.of(context).setPastHome();

    var specifyExtension =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowedExtensions: specifyExtension ? ['cgp'] : null,
        type: specifyExtension ? FileType.custom : FileType.any);

    if (result == null) return;
    var file = File(result.files.single.path!);
    file.readAsString().then((String contents) {
      GridState.of(context).loadFromString(contents);
      Navigator.of(context).pushNamed('/editor');
    });
  }

  void _openSourceCode() async {
    const sourceUrl = 'https://gitlab.com/PITR_DEV/flutter-cyber-grind-editor';
    await launch(sourceUrl);
  }

  void _newPattern() {
    AppState.of(context).setPastHome();
    GridState.of(context).resetPattern();
    Navigator.pushNamed(context, '/editor');
  }

  @override
  Widget build(BuildContext context) {
    var bigLogo = context.breakpoint > LayoutBreakpoint.xs;
    var showContinue = AppState.of(context).pastHome;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/Logo.png',
                  width: bigLogo ? 400 : 250,
                  height: 70,
                ),
                const Text(
                  'PATTERN EDITOR',
                  style: TextStyle(fontSize: 22, fontFamily: 'vcr'),
                ),
                const SizedBox(height: 14),
                showContinue
                    ? Column(
                        children: [
                          SizedBox(
                            width: 200,
                            child: FatButton(
                              child: const Text('CONTINUE'),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/editor'),
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                        ],
                      )
                    : Column(),
                SizedBox(
                  width: 200,
                  child: FatButton(
                    child: const Text('NEW'),
                    onPressed: _newPattern,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: FatButton(
                    child: const Text('LOAD'),
                    onPressed: _openFilePicker,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'CGEF ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  TextButton(
                    onPressed: _openSourceCode,
                    child: const Text('Source Code'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
