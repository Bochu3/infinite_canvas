import 'package:flutter/material.dart';

/// A node in the [InfiniteCanvas].
class InfiniteCanvasNode<T> {
  InfiniteCanvasNode({
    required this.key,
    required this.size,
    required this.offset,
    this.child,
    this.children,
    this.label,
    this.allowResize = false,
    this.allowMove = true,
    this.clipBehavior = Clip.none,
    this.visable = true,
    this.current = 0,
    this.type,
    this.value,
  });

  String get id => key.toString();

  final LocalKey key;
  late Size size;
  late Offset offset;
  late bool visable;
  late int current;
  String? type;
  String? label;
  T? value;
  final Widget? child;
  final List<Widget>? children;
  late bool allowResize, allowMove;
  final Clip clipBehavior;

  Rect get rect => offset & size;
  static const double dragHandleSize = 10;
  static const double borderInset = 2;

  void update({
    Size? size,
    Offset? offset,
    String? label,
  }) {
    if (offset != null && allowMove) this.offset = offset;
    if (size != null && allowResize) {
      if (size.width < dragHandleSize * 2) {
        size = Size(dragHandleSize * 2, size.height);
      }
      if (size.height < dragHandleSize * 2) {
        size = Size(size.width, dragHandleSize * 2);
      }
      this.size = size;
    }
    if (label != null) this.label = label;
  }

  void updateSize(
    Size? size,
  ) {
    if (size != null) {
      this.size = size;
    }
  }

  void updateVisable(bool visable) {
    this.visable = visable;
  }

  void lock() {
    allowMove = false;
    allowResize = false;
  }

  void unlock() {
    allowMove = true;
    allowResize = true;
  }

  void updateCurrent(int current) {
    this.current = current;
  }
}
