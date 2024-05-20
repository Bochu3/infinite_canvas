import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart';

import '../../domain/model/edge.dart';
import '../../domain/model/graph.dart';
import '../../domain/model/node.dart';

import 'dart:ui' as ui;

typedef NodeFormatter = void Function(InfiniteCanvasNode);

/// A controller for the [InfiniteCanvas].
class InfiniteCanvasController extends ChangeNotifier implements Graph {
  InfiniteCanvasController({
    List<InfiniteCanvasNode> nodes = const [],
    List<InfiniteCanvasEdge> edges = const [],
  }) {
    if (nodes.isNotEmpty) {
      this.nodes.addAll(nodes);
    }
    if (edges.isNotEmpty) {
      this.edges.addAll(edges);
    }
  }

  GlobalKey canvasKey = GlobalKey();
  LocalKey frameKey = UniqueKey();

  double minScale = 0.2;
  double maxScale = 2;
  final focusNode = FocusNode();
  Size? viewport;
  Size canvasSize = const Size(4096, 4096);
  bool frameVisible = true;
  bool processing = false;
  String capture = 'completed';
  Map<LocalKey, PageController> pageControllers = {};

  @override
  final List<InfiniteCanvasNode> nodes = [];

  @override
  final List<InfiniteCanvasEdge> edges = [];

  final Set<Key> _selected = {};
  List<InfiniteCanvasNode> get selection =>
      nodes.where((e) => _selected.contains(e.key)).toList();
  final Set<Key> _hovered = {};
  List<InfiniteCanvasNode> get hovered =>
      nodes.where((e) => _hovered.contains(e.key)).toList();

  void _cacheSelectedOrigins() {
    // cache selected node origins
    _selectedOrigins.clear();
    for (final key in _selected) {
      final index = nodes.indexWhere((e) => e.key == key);
      if (index == -1) continue;
      final current = nodes[index];
      _selectedOrigins[key] = current.offset;
    }
  }

  void _cacheSelectedOrigin(Key key) {
    final index = nodes.indexWhere((e) => e.key == key);
    if (index == -1) return;
    final current = nodes[index];
    _selectedOrigins[key] = current.offset;
  }

  final Map<Key, Offset> _selectedOrigins = {};
  final initialMatrix = Matrix4.identity()..scale(0.4);
  late final transform = TransformationController(initialMatrix);
  Matrix4 get matrix => transform.value;
  late double xTranslate;
  late double yTranslate;
  Offset mousePosition = Offset.zero;
  Offset? mouseDragStart;
  Offset? marqueeStart, marqueeEnd;
  LocalKey? linkStart;

  void _formatAll() {
    for (InfiniteCanvasNode node in nodes) {
      _formatter!(node);
    }
  }

  bool _formatterHasChanged = false;
  NodeFormatter? _formatter;
  set formatter(NodeFormatter value) {
    _formatterHasChanged = _formatter != value;

    if (_formatterHasChanged == false) return;

    _formatter = value;
    _formatAll();
    notifyListeners();
  }

  Offset? _linkEnd;
  Offset? get linkEnd => _linkEnd;
  set linkEnd(Offset? value) {
    if (value == _linkEnd) return;
    _linkEnd = value;
    notifyListeners();
  }

  Size _frameSize = const Size(640, 640);
  Size get frameSize => _frameSize;
  set frameSize(Size value) {
    if (value == _frameSize) return;
    _frameSize = value;
    notifyListeners();
  }

  bool _mouseDown = false;
  bool get mouseDown => _mouseDown;
  set mouseDown(bool value) {
    if (value == _mouseDown) return;
    _mouseDown = value;
    notifyListeners();
  }

  bool _shiftPressed = false;
  bool get shiftPressed => _shiftPressed;
  set shiftPressed(bool value) {
    if (value == _shiftPressed) return;
    _shiftPressed = value;
    notifyListeners();
  }

  bool _spacePressed = false;
  bool get spacePressed => _spacePressed;
  set spacePressed(bool value) {
    if (value == _spacePressed) return;
    _spacePressed = value;
    notifyListeners();
  }

  bool _controlPressed = false;
  bool get controlPressed => _controlPressed;
  set controlPressed(bool value) {
    if (value == _controlPressed) return;
    _controlPressed = value;
    notifyListeners();
  }

  bool _metaPressed = false;
  bool get metaPressed => _metaPressed;
  set metaPressed(bool value) {
    if (value == _metaPressed) return;
    _metaPressed = value;
    notifyListeners();
  }

  double _scale = 1;
  double get scale => _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    notifyListeners();
  }

  double getScale() {
    final matrix = transform.value;
    final scaleX = matrix.getMaxScaleOnAxis();
    return scaleX;
  }

  Rect getMaxSize() {
    Rect rect = Rect.zero;
    // if (nodes.isEmpty) return rect;
    // rect = Rect.fromLTRB(
    //     nodes.map((e) => e.rect.left).reduce(min),
    //     nodes.map((e) => e.rect.top).reduce(min),
    //     nodes.map((e) => e.rect.right).reduce(max),
    //     nodes.map((e) => e.rect.bottom).reduce(max));
    // Offset offset = getPositionOffset();
    for (final child in nodes) {
      rect = Rect.fromLTRB(
        min(rect.left, child.rect.left),
        min(rect.top, child.rect.top),
        max(rect.right, child.rect.right),
        max(rect.bottom, child.rect.bottom),
      );
    }
    return rect;
  }

  Rect getMinSize() {
    Rect rect = Rect.zero;
    List<InfiniteCanvasNode<dynamic>> images =
        nodes.where((e) => e.key != frameKey).toList();
    if (images.isEmpty) return rect;
    rect = Rect.fromLTRB(
        images.map((e) => e.rect.left).reduce(min),
        images.map((e) => e.rect.top).reduce(min),
        images.map((e) => e.rect.right).reduce(max),
        images.map((e) => e.rect.bottom).reduce(max));
    return rect;
  }

  double getTop() {
    if (nodes.isEmpty) return 0;
    return nodes.map((e) => e.rect.top).reduce(min);
  }

  double getLeft() {
    if (nodes.isEmpty) return 0;
    return nodes.map((e) => e.rect.left).reduce(min);
  }

  bool isSelected(LocalKey key) => _selected.contains(key);
  bool isHovered(LocalKey key) => _hovered.contains(key);

  bool get hasSelection => _selected.isNotEmpty;

  bool get canvasMoveEnabled => selection.isEmpty;

  Offset toLocal(Offset global) {
    return transform.toScene(global);
  }

  void checkSelection(Offset localPosition, [bool hover = false]) {
    final offset = toLocal(localPosition);
    final selection = <Key>[];
    for (final child in nodes) {
      final rect = child.rect;
      if (rect.contains(offset)) {
        selection.add(child.key);
      }
    }
    if (selection.isNotEmpty) {
      if (shiftPressed) {
        setSelection({selection.last, ..._selected.toSet()}, hover);
      } else {
        setSelection({selection.last}, hover);
      }
    } else {
      deselectAll(hover);
    }
  }

  void checkMarqueeSelection([bool hover = false]) {
    if (marqueeStart == null || marqueeEnd == null) return;
    final selection = <Key>{};
    final rect = Rect.fromPoints(
      toLocal(marqueeStart!),
      toLocal(marqueeEnd!),
    );
    for (final child in nodes) {
      if (rect.overlaps(child.rect)) {
        selection.add(child.key);
      }
    }
    if (selection.isNotEmpty) {
      if (shiftPressed) {
        setSelection(selection.union(_selected.toSet()), hover);
      } else {
        setSelection(selection, hover);
      }
    } else {
      deselectAll(hover);
    }
  }

  bool checkFrameSelection() {
    var frame = getNode(frameKey)!;
    final selection = <Key>{};
    final rect = Rect.fromLTWH(
        frame.offset.dx, frame.offset.dy, frame.size.width, frame.size.height);
    for (final child in nodes) {
      if (child.key != frameKey) {
        if (rect.overlaps(child.rect)) {
          selection.add(child.key);
        }
      }
    }
    deselectAll();
    if (selection.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }

  InfiniteCanvasNode? getNode(LocalKey? key) {
    if (key == null) return null;
    return nodes.firstWhereOrNull((e) => e.key == key);
  }

  void addLink(LocalKey from, LocalKey to, [String? label]) {
    final edge = InfiniteCanvasEdge(
      from: from,
      to: to,
      label: label,
    );
    edges.add(edge);
    notifyListeners();
  }

  void moveSelection(Offset position) {
    final delta = mouseDragStart != null
        ? toLocal(position) - toLocal(mouseDragStart!)
        : toLocal(position);
    for (final key in _selected) {
      final index = nodes.indexWhere((e) => e.key == key);
      if (index == -1) continue;
      final current = nodes[index];
      final origin = _selectedOrigins[key];
      current.update(offset: origin! + delta);
      if (_formatter != null) {
        _formatter!(current);
      }
    }
    notifyListeners();
  }

  void select(Key key, [bool hover = false]) {
    if (hover) {
      _hovered.add(key);
    } else {
      _selected.add(key);
      _cacheSelectedOrigin(key);
    }

    notifyListeners();
  }

  void setSelection(Set<Key> keys, [bool hover = false]) {
    if (hover) {
      _hovered.clear();
      _hovered.addAll(keys);
    } else {
      _selected.clear();
      _selected.addAll(keys);
      _cacheSelectedOrigins();
    }
    notifyListeners();
  }

  void deselect(Key key, [bool hover = false]) {
    if (hover) {
      _hovered.remove(key);
    } else {
      _selected.remove(key);
      _selectedOrigins.remove(key);
    }
    notifyListeners();
  }

  void deselectAll([bool hover = false]) {
    if (hover) {
      _hovered.clear();
    } else {
      _selected.clear();
      _selectedOrigins.clear();
    }
    notifyListeners();
  }

  void add(InfiniteCanvasNode child) {
    if (_formatter != null) {
      _formatter!(child);
    }
    nodes.insert(nodes.length - 1, child);
    notifyListeners();
  }

  void edit(InfiniteCanvasNode child) {
    if (_selected.length == 1) {
      final idx = nodes.indexWhere((e) => e.key == _selected.first);
      nodes[idx] = child;
      notifyListeners();
    }
  }

  void remove(Key key) {
    nodes.removeWhere((e) => e.key == key);
    _selected.remove(key);
    _selectedOrigins.remove(key);
    notifyListeners();
  }

  void bringToFront() {
    final selection = _selected.toList();
    for (final key in selection) {
      final index = nodes.indexWhere((e) => e.key == key && e.key != frameKey);
      if (index == -1) continue;
      final current = nodes[index];
      nodes.removeAt(index);
      nodes.insert(nodes.length - 1, current);
    }
    notifyListeners();
  }

  void sendBackward() {
    final selection = _selected.toList();
    if (selection.length == 1) {
      final key = selection.first;
      final index = nodes.indexWhere((e) => e.key == key && e.key != frameKey);
      if (index == nodes.length - 1) return;
      if (index == -1) return;
      if (index == 0) return;
      final current = nodes[index];
      nodes.removeAt(index);
      nodes.insert(index - 1, current);
      notifyListeners();
    }
  }

  void sendForward() {
    final selection = _selected.toList();
    if (selection.length == 1) {
      final key = selection.first;
      final index = nodes.indexWhere((e) => e.key == key && e.key != frameKey);
      if (index == -1) return;
      if (index == nodes.length - 1) return;
      final current = nodes[index];
      nodes.removeAt(index);
      nodes.insert(min(index + 1, nodes.length - 1), current);
      notifyListeners();
    }
  }

  void sendToBack() {
    final selection = _selected.toList();
    for (final key in selection) {
      final index = nodes.indexWhere((e) => e.key == key && e.key != frameKey);
      if (index == -1) continue;
      final current = nodes[index];
      nodes.removeAt(index);
      nodes.insert(0, current);
    }
    notifyListeners();
  }

  void deleteSelection() {
    final selection = _selected.toList();
    for (final key in selection) {
      final index = nodes.indexWhere((e) => e.key == key && e.key != frameKey);
      if (index == -1) continue;
      nodes.removeAt(index);
      _selectedOrigins.remove(key);
    }
    notifyListeners();
  }

  void deleteAll() {
    nodes.where((element) => element.key != frameKey).toList().clear();
    _selectedOrigins.clear();
    notifyListeners();
  }

  void selectAll() {
    _selected.clear();
    _selected.addAll(nodes
        .where((element) => element.key != frameKey)
        .map((e) => e.key)
        .toList());
    _cacheSelectedOrigins();
    notifyListeners();
  }

  void zoom(double delta) {
    final matrix = transform.value.clone();
    final local = toLocal(mousePosition);
    matrix.translate(local.dx, local.dy);
    matrix.scale(delta, delta);
    matrix.translate(-local.dx, -local.dy);
    transform.value = matrix;
    notifyListeners();
  }

  void zoomIn() => zoom(1.1);
  void zoomOut() => zoom(0.9);
  void zoomReset() => transform.value = Matrix4.identity();

  void pan(Offset delta) {
    final matrix = transform.value.clone();
    matrix.translate(delta.dx, delta.dy);
    transform.value = matrix;
    notifyListeners();
  }

  void panUp() => pan(const Offset(0, -10));
  void panDown() => pan(const Offset(0, 10));
  void panLeft() => pan(const Offset(-10, 0));
  void panRight() => pan(const Offset(10, 0));

  Offset getOffset() {
    final matrix = transform.value.clone();
    matrix.invert();
    // matrix.translate(xTranslate, yTranslate);
    final result = matrix.getTranslation();
    return Offset(result.x, result.y);
  }

  Offset getOffsetCenter() {
    final matrix = transform.value.clone();
    matrix.invert();
    matrix.translate(xTranslate, yTranslate);
    final result = matrix.getTranslation();
    return Offset(result.x, result.y);
  }

  Rect getRect(BoxConstraints constraints) {
    final offset = getOffset();
    final scale = matrix.getMaxScaleOnAxis();
    final size = constraints.biggest;
    return offset & size / scale;
  }

  Future<Uint8List?> captureFrame() async {
    getNode(frameKey)!.updateVisable(false);
    _hovered.clear();
    lockNodes();
    lockScreen();
    await Future.delayed(Duration(milliseconds: 500));
    final canvas =
        canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    try {
      ui.Image image = await canvas.toImage();
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final decodedImage = decodeImage(pngBytes);
      Offset offset = getNode(frameKey)!.offset;
      if (decodedImage != null) {
        final crop = copyCrop(
          decodedImage,
          x: offset.dx.toInt(),
          y: offset.dy.toInt(),
          width: frameSize.width.toInt(),
          height: frameSize.height.toInt(),
        );
        return Uint8List.fromList(encodePng(crop));
      }
    } catch (e) {
      print(e);
    } finally {
      getNode(frameKey)!.updateVisable(true);
      unlockNodes();
    }
    return null;
  }

  Future<Uint8List?> captureCanvas() async {
    getNode(frameKey)!.updateVisable(false);
    _hovered.clear();
    lockScreen();
    await Future.delayed(Duration(milliseconds: 500));
    final canvas =
        canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    try {
      ui.Image image = await canvas.toImage();
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final decodedImage = decodeImage(pngBytes);
      Rect minSize = getMinSize();
      if (decodedImage != null) {
        final crop = copyCrop(
          decodedImage,
          x: minSize.topLeft.dx.toInt(),
          y: minSize.topLeft.dy.toInt(),
          width: minSize.width.toInt(),
          height: minSize.height.toInt(),
        );
        return Uint8List.fromList(encodePng(crop));
      }
    } catch (e) {
      print(e);
    } finally {
      getNode(frameKey)!.updateVisable(true);
      unlockNodes();
    }
    return null;
  }

  Future<Uint8List> capturePng() async {
    deselectAll();
    RenderRepaintBoundary boundary =
        canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage();
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    Uint8List pngBytes = byteData!.buffer.asUint8List();
    return pngBytes;
  }

  void updateFrameSize(Size size) {
    frameSize = size;
    getNode(frameKey)?.updateSize(size);
    notifyListeners();
  }

  void hideFrame() {
    getNode(frameKey)!.updateVisable(false);
    notifyListeners();
  }

  void lockScreen() {
    processing = true;
    deselectAll();
    notifyListeners();
  }

  void lockNodes() {
    for (final node in nodes) {
      if (node.key != frameKey) {
        node.lock();
      }
    }
  }

  void unlockNodes() {
    processing = false;
    notifyListeners();
  }

  void generate(List<String> urls) {
    var frame = getNode(frameKey)!;
    final node = InfiniteCanvasNode(
        key: UniqueKey(),
        allowResize: false,
        allowMove: false,
        size: Size(frame.size.width, frame.size.height + 80),
        offset: frame.offset,
        type: 'page',
        current: 0,
        children: urls
            .map(
              (url) => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            )
            .toList());

    add(node);
    setSelection({node.key});
  }
}
