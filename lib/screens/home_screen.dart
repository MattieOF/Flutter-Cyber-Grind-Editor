import 'dart:io';

import 'package:cgef/state/app_state.dart';
import 'package:cgef/state/grid_state.dart';
import 'package:cgef/widgets/input/fat_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:layout/layout.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _getVersion().then((value) => setState(() => appVersion = value));
  }

  Future<String> _getVersion() async {
    final fileContent = await rootBundle.loadString(
      "pubspec.yaml",
    );
    final pubspec = Pubspec.parse(fileContent);
    return pubspec.version!.canonicalizedVersion;
  }

  void _openFilePicker() async {
    AppState.of(context).setPastHome();

    var specifyExtension =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    String? path;

    if (!specifyExtension) {
      var strg = await getExternalStorageDirectory();
      path = strg!.path;
    }

    // print('initial directory: $path');

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: specifyExtension ? ['cgp'] : null,
      type: specifyExtension ? FileType.custom : FileType.any,
      // initialDirectory: path,
    );

    if (result == null) return;
    var file = File(result.files.single.path!);
    file.readAsString().then((String contents) {
      GridState.of(context).loadFromString(contents);
      Navigator.of(context).pushNamed('/editor');
    });
  }

  void _openSourceCode() async {
    const sourceUrl = 'https://github.com/PITR-DEV/Flutter-Cyber-Grind-Editor';
    await launchUrlString(sourceUrl, mode: LaunchMode.externalApplication);
  }

  void _newPatternPressed() {
    if (AppState.of(context).patternModified) {
      showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text(
              'Your current pattern has unsaved changes. Discard them and create a new one, or cancel?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ).then((value) => {if (value != null && value) _newPattern()});
    } else {
      _newPattern();
    }
  }

  void _newPattern() {
    AppState.of(context).setPastHome();
    GridState.of(context).resetPattern();
    Navigator.pushNamed(context, '/editor');
  }

  void _showSettings() {
    Navigator.pushNamed(context, '/settings');
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
                    onPressed: _newPatternPressed,
                    child: const Text('NEW'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: FatButton(
                    onPressed: _showSettings,
                    child: const Text('SETTINGS'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: FatButton(
                    onPressed: _openFilePicker,
                    child: const Text('LOAD'),
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
                  TextButton(
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "Cyber Grind Pattern Editor",
                        applicationVersion: appVersion,
                        applicationLegalese:
                            "Simple tool to edit Cyber Grind patterns for ULTRAKILL.\nBy PITR, with contributions from Mattie\ncopyright lololol",
                      );
                    },
                    child: Text(
                      'CGE $appVersion ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
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
