import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cgef/state/app_state.dart';
import 'package:cgef/widgets/exception_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:cgef/helpers/parsing_helper.dart';
import 'package:cgef/state/grid_state.dart';
import 'package:cgef/widgets/arena_grid.dart';
import 'package:cgef/widgets/input/tab_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:layout/layout.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:universal_html/html.dart' as html;
import 'package:raylib/raylib.dart' as rl;
import 'package:raylib/rlgl.dart' as rlgl;
import 'package:ffi/src/allocation.dart' as ffi;

const deg2rad = pi / 180;

class EditorScreen extends StatefulWidget {
  const EditorScreen({Key? key}) : super(key: key);

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  AppState? _appState;
  GridState? _gridState;

  rl.Camera3D? _camera;
  rl.Model? _skybox;
  rl.Model? _pillarModel;
  rl.Model? _zapPlane;
  rl.Model? _stairsModel;
  rl.Model? _cornerStairsModel;
  rl.Vector2 _cameraAngle = rl.Vector2.zero();
  rl.Vector3 _pillarSize = rl.Vector3.zero();
  double _targetDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _appState ??= AppState.of(context);
      _gridState ??= GridState.of(context);

      if (_appState!.raylibUpdateTimer != null) {
        _appState!.raylibUpdateTimer!.cancel();
      }

      _appState!.raylibUpdateTimer = Timer.periodic(
          const Duration(milliseconds: 10), (Timer timer) => _tick());

      if (!kIsWeb && Platform.isWindows || Platform.isLinux) {
        if (rl.isWindowReady()) _initPreview();
      }
    });
  }

  String _getExportableString() {
    var grid = ScopedModel.of<GridState>(context).grid;
    var exportableString = ParsingHelper().stringifyPattern(grid);
    return exportableString;
  }

  Future<bool> _export() async {
    try {
      var date = DateTime.now();
      String? outputPath;
      final fileName =
          '${date.hour}_${date.minute} - ${date.day}_${date.month}_${date.year}.cgp';

      // Web implementation
      if (kIsWeb) {
        final output = _getExportableString();
        final bytes = utf8.encode(output);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        anchor.click();

        // Cleanup
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        return true; // Technically the user can cancel the download, but we can't detect that (afaik).
      }

      // Mobile implementation
      if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
        var path = await getExternalStorageDirectory();
        outputPath = p.join(path!.path, fileName);

        final file = File(outputPath);
        await file.writeAsString(_getExportableString());

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                'Exported',
              ),
              content: SelectableText(
                'File saved to:\n${path.path}\n\nas\n\n$fileName',
                maxLines: 8,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'ok',
                  ),
                )
              ],
            );
          },
        );
        //print(path);
        return true;
      }

      // Desktop implementation
      var resEx = Platform.resolvedExecutable;

      var exFile = File(resEx);
      if (exFile.parent.parent.parent.parent.existsSync()) {
        var ultrakillDirectory = exFile.parent.parent.parent.parent;

        if (ultrakillDirectory.path.split(Platform.pathSeparator).last ==
            "ULTRAKILL") {
          // print('ULTRAKILL dir spotted');

          var patternsDir = Directory(
              p.join(ultrakillDirectory.path, 'Cybergrind', 'Patterns'));
          if (patternsDir.existsSync()) {
            outputPath = patternsDir.path;
          }
        } else {
          // print('cgef seems to be not in StreamingAssets.');
          // print('attempting to use default path');
          outputPath = p.join('C:', 'Program Files (x86)', 'Steam', 'steamapps',
              'common', 'ULTRAKILL', 'Cybergrind', 'Patterns');
        }
      }

      // print('Setting default filename to ${outputPath ?? 'null'}');

      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export your pattern:',
        fileName: fileName,
        initialDirectory: outputPath,
        allowedExtensions: ['cgp'],
        type: FileType.custom,
      );

      // print('User selected ${outputPath ?? 'null'}');

      if (outputPath == null) return false;

      if (!outputPath.endsWith('.cgp')) {
        outputPath += '.cgp';
      }

      await File(outputPath).writeAsString(_getExportableString());
      return true;
    } catch (ex, stack) {
      spawnExceptionDialog(context, "$ex\n$stack");
      return false;
    }
  }

  void _exportPressed() {
    _export().then((success) =>
        {if (success) AppState.of(context).clearPatternModified()});
  }

  void _initPreview() {
    var pathList = Platform.resolvedExecutable.split('\\');
    var path = pathList.sublist(0, pathList.length - 1).join('\\');

    if (!rl.isWindowReady()) {
      rl.initWindow(1280, 600, "Cyber Grind Preview");
      rl.setWindowState(rl.ConfigFlags
          .windowResizable); // I'd like to make it resizeable, but it causes weird issues with the skybox
      rl.setExitKey(rl.KeyboardKey.none);

      rl.Image icon =
          rl.loadImage("$path/data/flutter_assets/assets/icon/icon_static.png");
      rl.setWindowIcon(icon);
    }

    _camera ??= rl.Camera(
      position: rl.Vector3(22, 15, 22),
      target: rl.Vector3(0, 10, 0),
      up: rl.Vector3(0, 1, 0),
      fovy: _appState!.camFov,
    );
    rl.setCameraMode(_camera!, rl.CameraMode.custom);
    double dx = _camera!.target.x - _camera!.position.x;
    double dy = _camera!.target.y - _camera!.position.y;
    double dz = _camera!.target.z - _camera!.position.z;
    _cameraAngle =
        rl.Vector2(atan2(dx, dz), atan2(dy, sqrt(dx * dx + dz * dz)));
    _targetDistance = sqrt(dx * dx + dy * dy + dz * dz);

    if (_skybox == null) {
      var cube = rl.genMeshCube(1, 1, 1);
      _skybox = rl.loadModelFromMesh(cube);

      var shader = rl.loadShader(
          "$path/data/flutter_assets/assets/shaders/glsl330/skybox.vs",
          "$path/data/flutter_assets/assets/shaders/glsl330/skybox.fs");

      _skybox!.materials[0].setShader(shader);

      // Set uniforms for skybox shader
      ffi.Pointer<ffi.Int32> data =
          ffi.calloc.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      data.value = rl.MaterialMapIndex.CUBEMAP;
      rl.setShaderValue(
          _skybox!.materials[0].shader,
          rl.getShaderLocation(shader, "environmentMap"),
          ffi.Pointer<ffi.Void>.fromAddress(data.address),
          rl.ShaderUniformDataType.INT);
      ffi.calloc.free(data);

      data = ffi.calloc.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      data.value = 0;
      rl.setShaderValue(
          _skybox!.materials[0].shader,
          rl.getShaderLocation(shader, "doGamma"),
          ffi.Pointer<ffi.Void>.fromAddress(data.address),
          rl.ShaderUniformDataType.INT);
      ffi.calloc.free(data);

      data = ffi.calloc.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      data.value = 0;
      rl.setShaderValue(
          _skybox!.materials[0].shader,
          rl.getShaderLocation(shader, "vflipped"),
          ffi.Pointer<ffi.Void>.fromAddress(data.address),
          rl.ShaderUniformDataType.INT);
      ffi.calloc.free(data);

      rl.Image skyboxImage = rl.loadImage(
          "$path/data/flutter_assets/assets/preview_assets/skybox.png");
      _skybox!.materials[0].maps[7].texture =
          rl.loadTextureCubemap(skyboxImage, rl.CubemapLayout.autoDetect);
      rl.unloadImage(skyboxImage);
    }

    rl.Texture2D blockTexture = rl.loadTexture(
        "$path/data/flutter_assets/assets/preview_assets/block.png");
    rl.setTextureWrap(blockTexture, rl.TextureWrap.repeat);
    rl.setTextureFilter(blockTexture, rl.TextureFilter.point);
    if (_pillarModel == null) {
      _pillarModel = rl.loadModel(
          "$path/data/flutter_assets/assets/preview_assets/CGPillar.glb");
      final box = rl.getMeshBoundingBox(_pillarModel!.meshes[0]);
      _pillarSize = rl.Vector3(
          box.max.x - box.min.x, box.max.y - box.min.y, box.max.z - box.min.z);
      _pillarModel!.materials[1].maps[0].texture = blockTexture;
    }

    if (_stairsModel == null) {
      _stairsModel = rl.loadModel(
          "$path/data/flutter_assets/assets/preview_assets/CGStairs.glb");
      _stairsModel!.materials[1].maps[0].texture = blockTexture;
    }

    if (_cornerStairsModel == null) {
      _cornerStairsModel = rl.loadModel(
          "$path/data/flutter_assets/assets/preview_assets/CGCornerStairs.glb");
      _cornerStairsModel!.materials[1].maps[0].texture = blockTexture;
    }

    if (_zapPlane == null) {
      rl.Texture2D zapGridTexture = rl.loadTexture(
          "$path/data/flutter_assets/assets/preview_assets/zapGrid.png");
      rl.setTextureWrap(zapGridTexture, rl.TextureWrap.repeat);
      rl.setTextureFilter(zapGridTexture, rl.TextureFilter.point);
      _zapPlane = rl.loadModel(
          "$path/data/flutter_assets/assets/preview_assets/CGZapPlane.glb");
      _zapPlane!.materials[1].maps[0].texture = zapGridTexture;
    }
  }

  void _tick() {
    if (!rl.isWindowReady()) {
      return;
    }

    if (rl.windowShouldClose()) {
      // Deinit
      // Unload shaders
      rl.unloadShader(_skybox!.materials[0].shader);

      // Unload models
      rl.unloadModel(_skybox!);
      rl.unloadModel(_pillarModel!);
      rl.unloadModel(_stairsModel!);
      rl.unloadModel(_cornerStairsModel!);
      rl.unloadModel(_zapPlane!);

      // Set dart objects to null
      _skybox = null;
      _pillarModel = null;
      _stairsModel = null;
      _cornerStairsModel = null;
      _zapPlane = null;

      // Free and nullify camera
      ffi.calloc.free(_camera!.pointer);
      _camera = null;

      // Finally, close window
      rl.closeWindow();
    } else {
      if (_camera == null) {
        // I don't see how this state occurs, but it does.
        _initPreview();
        return;
      }

      _doCamera();

      rl.beginDrawing();
      rl.clearBackground(rl.Color.darkGray);
      rl.beginMode3D(_camera!);

      // Draw skybox
      rlgl.disableBackfaceCulling();
      rlgl.disableDepthMask();
      rl.drawModel(_skybox!, rl.Vector3(0, 0, 0), 1.0, rl.Color.white);
      rlgl.enableBackfaceCulling();
      rlgl.enableDepthMask();

      _drawGrid();

      rl.endMode3D();

      rl.endDrawing();
    }
  }

  void _drawGrid() {
    final int gridSize = _gridState!.grid.length;
    for (var x = 0; x < _gridState!.grid.length; x++) {
      for (var y = 0; y < _gridState!.grid[x].length; y++) {
        final element = _gridState!.grid[x][y];
        var position = rl.Vector3((-(gridSize / 2) + x) * _pillarSize.x,
            element.height.toDouble(), (-(gridSize / 2) + y) * _pillarSize.z);
        rl.drawModel(_pillarModel!, position, 1, rl.Color.white);
        if (element.prefab == "s") {
          _drawStair(position, x, y);
        }
      }
    }
    rlgl.disableBackfaceCulling();
    rl.drawModel(_zapPlane!, rl.Vector3(-1, (-4 + _pillarSize.y / 2) + 1.5, -1),
        1, rl.Color.white);
    rlgl.enableBackfaceCulling();
  }

  void _drawStair(rl.Vector3 position, int x, int y) {
    // YANDERE DEV ASS CODE COMING UP. SHOULD MAYBE BE REWRITTEN
    // OR AT LEAST CACHED INSTEAD OF HAPPENING EVERY FRAME FOR EVERY STAIR

    // Compute position, rotation, and scale
    final int gridSize = _gridState!.grid.length;
    final element = _gridState!.grid[x][y];
    position.y += _pillarSize.y / 2 + 2;
    var scale = rl.Vector3.all(1);

    // 1 = back, 0 = neither/both, -1 = front
    int backFront = 0;
    // 1 = right, 0 = neither/both, -1 left
    int rightLeft = 0;

    int frontDiff = y != gridSize - 1
        ? _gridState!.grid[x][y + 1].height - element.height
        : 0;
    int backDiff =
        y != 0 ? _gridState!.grid[x][y - 1].height - element.height : 0;

    bool front = frontDiff > 0 && frontDiff <= 2;
    bool back = backDiff > 0 && backDiff <= 2;
    if (front && back) {
      if (frontDiff < backDiff) {
        scale.y = 0.5;
        backFront = 1;
      } else if (backDiff < frontDiff) {
        scale.y = 0.5;
        backFront = -1;
      } else {
        backFront = 0;
      }
    } else if (front) {
      if (frontDiff == 1) scale.y = 0.5;
      backFront = 1;
    } else if (back) {
      if (backDiff == 1) scale.y = 0.5;
      backFront = -1;
    }

    int leftDiff = x != gridSize - 1
        ? (_gridState!.grid[x + 1][y].height) - element.height
        : 0;
    int rightDiff =
        x != 0 ? _gridState!.grid[x - 1][y].height - element.height : 0;
    bool left = leftDiff > 0 && leftDiff <= 2;
    bool right = rightDiff > 0 && rightDiff <= 2;

    if (left && right) {
      if (leftDiff < rightDiff) {
        scale.y = 0.5;
        rightLeft = 1;
      } else if (rightDiff < leftDiff) {
        scale.y = 0.5;
        rightLeft = -1;
      } else {
        rightLeft = 0;
      }
    } else if (left) {
      if (leftDiff == 1) scale.y = 0.5;
      rightLeft = 1;
    } else if (right) {
      if (rightDiff == 1) scale.y = 0.5;
      rightLeft = -1;
    }
    if (scale.y == 0.5) position.y -= 0.5;

    if (backFront != 0 && rightLeft != 0) {
      bool frontOrBackHasStair =
          (y != gridSize - 1 && _gridState!.grid[x][y + 1].prefab == "s") ||
              (y != 0 && _gridState!.grid[x][y - 1].prefab == "s");
      bool leftOrRightHasStair =
          (x != gridSize - 1 && _gridState!.grid[x + 1][y].prefab == "s") ||
              (x != 0 && _gridState!.grid[x - 1][y].prefab == "s");

      if (frontOrBackHasStair && !leftOrRightHasStair) {
        backFront = 0;
      } else if (leftOrRightHasStair && !frontOrBackHasStair) {
        rightLeft = 0;
      } else {
        if (((leftDiff < frontDiff) && (leftDiff < backDiff)) ||
            ((rightDiff < frontDiff) && (rightDiff < backDiff)))
          backFront = 0;
        else if (((frontDiff < leftDiff) && (frontDiff < rightDiff)) ||
            ((backDiff < leftDiff) && (backDiff < rightDiff))) rightLeft = 0;
      }
    }

    // Make sure that we only do corner stairs if they're both the same height
    // Prevents a corner stair that doesn't actually reach one of the sides
    if (backFront != 0 && rightLeft != 0 && scale.y == 0.5) {
      if (leftDiff > 1 || rightDiff > 1) {
        rightLeft = 0;
      } else if (frontDiff > 1 || backDiff > 1) {
        backFront = 0;
      }
    }

    if (backFront == 0 && rightLeft == 0) return;

    if (backFront != 0 && rightLeft != 0) {
      double angle = 0;

      if (backFront == 1 && rightLeft == 1) {
        angle = 0;
      } else if (backFront == -1 && rightLeft == 1) {
        angle = 90;
      } else if (backFront == -1 && rightLeft == -1) {
        angle = 180;
      } else if (backFront == 1 && rightLeft == -1) {
        angle = 270;
      }

      rl.drawModelEx(_cornerStairsModel!, position, rl.Vector3(0, 1, 0), angle,
          scale, rl.Color.white);
      return;
    }

    double angle = 0;

    // if (x == 5 && y == 1) print("$backFront, $rightLeft");
    if (backFront == 1) {
      angle = 270;
    } else if (backFront == -1) {
      angle = 90;
    } else if (rightLeft == -1) {
      angle = 180;
    }

    rl.drawModelEx(_stairsModel!, position, rl.Vector3(0, 1, 0), angle, scale,
        rl.Color.white);
  }

  void _doCamera() {
    _camera!.fovy = _appState!.camFov;

    // Lock/unlock the cursor
    if (rl.isKeyPressed(rl.KeyboardKey.escape) && rl.isCursorHidden()) {
      rl.enableCursor();
      return;
    } else if (rl.isMouseButtonPressed(rl.MouseButton.left) &&
        rl.isCursorOnScreen() &&
        !rl.isCursorHidden()) {
      rl.disableCursor();
    }

    if (!rl.isCursorHidden()) return;

    const double camMoveSpeed = 16;
    var deltaTime = rl.getFrameTime();
    var mouseDelta = rl.getMouseDelta();

    // Up/down movement
    if (rl.isKeyDown(rl.KeyboardKey.space)) {
      _camera!.position.y += camMoveSpeed * deltaTime;
    }
    if (rl.isKeyDown(rl.KeyboardKey.leftShift)) {
      _camera!.position.y -= camMoveSpeed * deltaTime;
    }

    List<bool> keyPresses = [
      rl.isKeyDown(rl.KeyboardKey.w),
      rl.isKeyDown(rl.KeyboardKey.s),
      rl.isKeyDown(rl.KeyboardKey.a),
      rl.isKeyDown(rl.KeyboardKey.d)
    ];

    // The following code sucks. Copy pasted (but dart ported) from raylib

    _camera!.position.x += (sin(_cameraAngle.x) * (keyPresses[1] ? 1 : 0) -
            sin(_cameraAngle.x) * (keyPresses[0] ? 1 : 0) -
            cos(_cameraAngle.x) * (keyPresses[2] ? 1 : 0) +
            cos(_cameraAngle.x) * (keyPresses[3] ? 1 : 0)) *
        camMoveSpeed *
        deltaTime;

    _camera!.position.y += (sin(_cameraAngle.y) * (keyPresses[0] ? 1 : 0) -
            sin(_cameraAngle.y) * (keyPresses[1] ? 1 : 0)) *
        camMoveSpeed *
        deltaTime;

    _camera!.position.z += (cos(_cameraAngle.x) * (keyPresses[1] ? 1 : 0) -
            cos(_cameraAngle.x) * (keyPresses[0] ? 1 : 0) +
            sin(_cameraAngle.x) * (keyPresses[2] ? 1 : 0) -
            sin(_cameraAngle.x) * (keyPresses[3] ? 1 : 0)) *
        camMoveSpeed *
        deltaTime;

    _cameraAngle.x -= (mouseDelta.x *
        _appState!.previewCamSensitivity *
        (_appState!.invertMouselook ? -1 : 1) *
        deltaTime);
    _cameraAngle.y -= (mouseDelta.y *
        _appState!.previewCamSensitivity *
        (_appState!.invertMouselook ? -1 : 1) *
        deltaTime);

    // Clamp camera angle
    if (_cameraAngle.y > (89 * deg2rad)) {
      _cameraAngle.y = 89 * deg2rad;
    } else if (_cameraAngle.y < (-89 * deg2rad)) {
      _cameraAngle.y = -89 * deg2rad;
    }

    // The one in brackets is defined as CAMERA.targetDistance/CAMERA_FREE_PANNING_DIVIDER in raylib
    rl.Matrix transMat = rl.Matrix.withValues(
        1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, _targetDistance / 5.1, 0, 0, 0, 1);

    rl.Matrix rotMat =
        rl.Matrix.withValues(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);

    double cosz = cos(0);
    double sinz = sin(0);
    double cosy = cos(-(pi * 2 - _cameraAngle.x));
    double siny = sin(-(pi * 2 - _cameraAngle.x));
    double cosx = cos(-(pi * 2 - _cameraAngle.y));
    double sinx = sin(-(pi * 2 - _cameraAngle.y));

    rotMat.m0 = cosz * cosy;
    rotMat.m4 = (cosz * siny * sinx) - (sinz * cosx);
    rotMat.m8 = (cosz * siny * cosx) + (sinz * sinx);
    rotMat.m1 = sinz * cosy;
    rotMat.m5 = (sinz * siny * sinx) + (cosz * cosx);
    rotMat.m9 = (sinz * siny * cosx) - (cosz * sinx);
    rotMat.m2 = -siny;
    rotMat.m6 = cosy * sinx;
    rotMat.m10 = cosy * cosx;

    rl.Matrix transformMat = rl.Matrix();

    transformMat.m0 = transMat.m0 * rotMat.m0 +
        transMat.m1 * rotMat.m4 +
        transMat.m2 * rotMat.m8 +
        transMat.m3 * rotMat.m12;
    transformMat.m1 = transMat.m0 * rotMat.m1 +
        transMat.m1 * rotMat.m5 +
        transMat.m2 * rotMat.m9 +
        transMat.m3 * rotMat.m13;
    transformMat.m2 = transMat.m0 * rotMat.m2 +
        transMat.m1 * rotMat.m6 +
        transMat.m2 * rotMat.m10 +
        transMat.m3 * rotMat.m14;
    transformMat.m3 = transMat.m0 * rotMat.m3 +
        transMat.m1 * rotMat.m7 +
        transMat.m2 * rotMat.m11 +
        transMat.m3 * rotMat.m15;
    transformMat.m4 = transMat.m4 * rotMat.m0 +
        transMat.m5 * rotMat.m4 +
        transMat.m6 * rotMat.m8 +
        transMat.m7 * rotMat.m12;
    transformMat.m5 = transMat.m4 * rotMat.m1 +
        transMat.m5 * rotMat.m5 +
        transMat.m6 * rotMat.m9 +
        transMat.m7 * rotMat.m13;
    transformMat.m6 = transMat.m4 * rotMat.m2 +
        transMat.m5 * rotMat.m6 +
        transMat.m6 * rotMat.m10 +
        transMat.m7 * rotMat.m14;
    transformMat.m7 = transMat.m4 * rotMat.m3 +
        transMat.m5 * rotMat.m7 +
        transMat.m6 * rotMat.m11 +
        transMat.m7 * rotMat.m15;
    transformMat.m8 = transMat.m8 * rotMat.m0 +
        transMat.m9 * rotMat.m4 +
        transMat.m10 * rotMat.m8 +
        transMat.m11 * rotMat.m12;
    transformMat.m9 = transMat.m8 * rotMat.m1 +
        transMat.m9 * rotMat.m5 +
        transMat.m10 * rotMat.m9 +
        transMat.m11 * rotMat.m13;
    transformMat.m10 = transMat.m8 * rotMat.m2 +
        transMat.m9 * rotMat.m6 +
        transMat.m10 * rotMat.m10 +
        transMat.m11 * rotMat.m14;
    transformMat.m11 = transMat.m8 * rotMat.m3 +
        transMat.m9 * rotMat.m7 +
        transMat.m10 * rotMat.m11 +
        transMat.m11 * rotMat.m15;
    transformMat.m12 = transMat.m12 * rotMat.m0 +
        transMat.m13 * rotMat.m4 +
        transMat.m14 * rotMat.m8 +
        transMat.m15 * rotMat.m12;
    transformMat.m13 = transMat.m12 * rotMat.m1 +
        transMat.m13 * rotMat.m5 +
        transMat.m14 * rotMat.m9 +
        transMat.m15 * rotMat.m13;
    transformMat.m14 = transMat.m12 * rotMat.m2 +
        transMat.m13 * rotMat.m6 +
        transMat.m14 * rotMat.m10 +
        transMat.m15 * rotMat.m14;
    transformMat.m15 = transMat.m12 * rotMat.m3 +
        transMat.m13 * rotMat.m7 +
        transMat.m14 * rotMat.m11 +
        transMat.m15 * rotMat.m15;

    _camera!.target.x = _camera!.position.x - transformMat.m12;
    _camera!.target.y = _camera!.position.y - transformMat.m13;
    _camera!.target.z = _camera!.position.z - transformMat.m14;
  }

  @override
  Widget build(BuildContext context) {
    final gridCentered = context.breakpoint > LayoutBreakpoint.xs &&
        context.breakpoint > LayoutBreakpoint.sm;

    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size(0, 52),
          child: Center(
            child: Margin(
              margin: const EdgeInsets.only(bottom: 12),
              child: ScopedModelDescendant<AppState>(
                builder: (context, child, model) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabButton(
                        onPressed: () => model.setTab(AppTab.heights),
                        active: model.tab == AppTab.heights,
                        text: 'Heights',
                        collapsed: !gridCentered,
                        collapsedIcon: const Icon(Icons.height),
                      ),
                      TabButton(
                        onPressed: () => model.setTab(AppTab.prefabs),
                        active: model.tab == AppTab.prefabs,
                        text: 'Prefabs',
                        collapsed: !gridCentered,
                        collapsedIcon: const Icon(Icons.widgets),
                      ),
                      if (Platform.isWindows || Platform.isLinux)
                        TabButton(
                          onPressed: () {
                            _initPreview();
                          },
                          active: model.tab == AppTab.preview,
                          text: '3D Preview',
                          collapsed: !gridCentered,
                          collapsedIcon: const Icon(Icons.remove_red_eye),
                        ),
                      TabButton(
                        onPressed: _exportPressed,
                        text: 'Export',
                        collapsed: !gridCentered,
                        collapsedIcon: const Icon(Icons.save),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        body: Listener(
          child: ScopedModelDescendant<GridState>(
            builder: (context, child, model) {
              return gridCentered
                  ? Center(
                      child: Column(
                        children: [
                          Text(_gridState?.getHoveredString() ?? ""),
                          const SizedBox(
                            height: 15,
                          ),
                          Expanded(
                            child: ArenaGrid(model),
                          )
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Text(_gridState?.getHoveredString() ?? ""),
                        const SizedBox(
                          height: 15,
                        ),
                        Expanded(
                          child: ArenaGrid(model),
                        )
                      ],
                    );
            },
          ),
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse &&
                event.buttons == kSecondaryMouseButton) {
              if (_gridState != null) _gridState!.onRightClick(_appState!);
            }
          },
        ));
  }
}
