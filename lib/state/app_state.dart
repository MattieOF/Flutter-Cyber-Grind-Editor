import 'dart:async';

import 'package:cgef/helpers/parsing_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cgef/helpers/stack.dart' as stack;

import 'grid_state.dart';

class HistoryStep {
  List<List<GridBlock>> grid;
  String name = "Untitled";

  HistoryStep(List<List<GridBlock>> newGrid, String newName)
      : grid = newGrid,
        name = newName;
}

class AppState extends Model {
  BuildContext? buildContext;

  SharedPreferences? _sharedPreferences;
  FToast fToast = FToast();

  Tool _tool = Tool.point;
  ToolModifier _toolModifier = ToolModifier.plusOne;
  Prefab _selectedPrefab = Prefab.none;
  AppTab _tab = AppTab.heights;

  int _setToValue = 0;
  int _plusValue = 2;

  int _toolSelectedGridBlock = -1;

  double _previewCamSensitivity = 0.5;

  double _camFov = 60;

  bool _invertMouseLook = false;

  bool _pastHome = false;

  bool _patternModified = false;

  bool _useImagesForPrefabs = true;

  bool _dirty = false;

  Timer? raylibUpdateTimer;

  stack.Stack<HistoryStep> _undoHistory = stack.Stack<HistoryStep>();

  AppState({this.buildContext}) {
    SharedPreferences.getInstance().then((value) {
      _sharedPreferences = value;
      if (_sharedPreferences == null) return;
      _useImagesForPrefabs =
          _sharedPreferences!.getBool("useImagesForPrefabs") ?? true;
      _previewCamSensitivity =
          _sharedPreferences!.getDouble("previewCamSensitivity") ?? 0.5;
      _camFov = _sharedPreferences!.getDouble("camFOV") ?? 60;
      _invertMouseLook =
          _sharedPreferences!.getBool("invertMouselook") ?? false;
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_dirty) {
          _sharedPreferences!
              .setBool("useImagesForPrefabs", _useImagesForPrefabs);
          _sharedPreferences!
              .setDouble("previewCamSensitivity", _previewCamSensitivity);
          _sharedPreferences!.setDouble("camFOV", _camFov);
          _sharedPreferences!.setBool("invertMouselook", _invertMouseLook);
          _dirty = false;
        }
      });
    });
  }

  Tool get tool => _tool;
  ToolModifier get toolModifier => _toolModifier;
  Prefab get selectedPrefab => _selectedPrefab;
  AppTab get tab => _tab;

  int get setToValue => _setToValue;
  int get plusValue => _plusValue;

  int get toolSelectedGridBlockIndex => _toolSelectedGridBlock;

  bool get pastHome => _pastHome;

  bool get patternModified => _patternModified;

  bool get useImagesForPrefabs => _useImagesForPrefabs;

  double get previewCamSensitivity => _previewCamSensitivity;

  double get camFov => _camFov;

  bool get invertMouselook => _invertMouseLook;

  void setPastHome() {
    _pastHome = true;
  }

  void setPatternModified() {
    _patternModified = true;
  }

  void clearPatternModified() {
    _patternModified = false;
  }

  void setUseImagesForPrefabs(bool newValue) {
    _useImagesForPrefabs = newValue;
    _dirty = true;
    notifyListeners();
  }

  void setPreviewCamSensitivity(double newValue) {
    _previewCamSensitivity = newValue;
    _dirty = true;
    notifyListeners();
  }

  void setInvertMouselook(bool newValue) {
    _invertMouseLook = newValue;
    _dirty = true;
    notifyListeners();
  }

  void setFOV(double newValue) {
    _camFov = newValue;
    _dirty = true;
    notifyListeners();
  }

  void setToolOptions({int? setToValue, int? plusValue}) {
    _setToValue = setToValue ?? _setToValue;
    _plusValue = plusValue ?? _plusValue;
    notifyListeners();
  }

  void setTool(Tool tool) {
    _tool = tool;
    _toolSelectedGridBlock = -1;
    notifyListeners();
  }

  void setToolModifier(ToolModifier mod) {
    _toolModifier = mod;
    notifyListeners();
  }

  void setPrefab(Prefab prefab) {
    _selectedPrefab = prefab;
    notifyListeners();
  }

  void setTab(AppTab tab) {
    _tab = tab;
    _toolSelectedGridBlock = -1;
    notifyListeners();
  }

  void setGridBlockSelected(int index) {
    _toolSelectedGridBlock = index;
    notifyListeners();
  }

  void clearUndoHistory(GridState gridState) {
    _undoHistory.clear(HistoryStep(
        List.generate(
            ParsingHelper.arenaSize,
            (x) => List.generate(ParsingHelper.arenaSize,
                (y) => GridBlock.from(gridState.grid[x][y]))),
        ""));
  }

  Widget? undo(GridState gridState) {
    if (_undoHistory.hasOneBehind) {
      var undoingName = _undoHistory.peek.name;
      _undoHistory.back();
      gridState.grid = List.generate(
          ParsingHelper.arenaSize,
          (x) => List.generate(ParsingHelper.arenaSize,
              (y) => GridBlock.from(_undoHistory.peek.grid[x][y])));

      if (undoingName != "") {
        notifyListeners();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            color: Colors.greenAccent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check,
                color: Colors.black,
              ),
              const SizedBox(
                width: 12.0,
              ),
              Text("Undo: $undoingName",
                  style: const TextStyle(color: Colors.black)),
            ],
          ),
        );
      }
    }

    notifyListeners();
    return null;
  }

  Widget? redo(GridState gridState) {
    if (_undoHistory.hasOneInFront) {
      var redoingName = _undoHistory.peekInFront.name;
      _undoHistory.forward();
      gridState.grid = List.generate(
          ParsingHelper.arenaSize,
          (x) => List.generate(ParsingHelper.arenaSize,
              (y) => GridBlock.from(_undoHistory.peek.grid[x][y])));

      if (redoingName != "") {
        notifyListeners();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            color: Colors.greenAccent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check,
                color: Colors.black,
              ),
              const SizedBox(
                width: 12.0,
              ),
              Text("Redo: $redoingName",
                  style: const TextStyle(color: Colors.black)),
            ],
          ),
        );
      }
    }

    notifyListeners();
    return null;
  }

  void submitCommand(GridState gridState, String commandDesc) {
    _undoHistory.push(HistoryStep(
        List.generate(
            ParsingHelper.arenaSize,
            (x) => List.generate(ParsingHelper.arenaSize,
                (y) => GridBlock.from(gridState.grid[x][y]))),
        commandDesc));
  }

  static AppState of(BuildContext context) {
    return ScopedModel.of<AppState>(context, rebuildOnChange: true);
  }
}

enum AppTab { heights, prefabs, preview }

enum Tool { point, brush, fillRect, outlineRect }

enum ToolModifier { plusOne, minusOne, setTo, plusValue }

enum Prefab { none, melee, projectile, jumpPad, stairs, hideous }
