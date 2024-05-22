import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../widgets/delegate.dart';
import '../../domain/model/node.dart';
import '../../domain/model/edge.dart';
import '../widgets/edge_renderer.dart';
import '../state/controller.dart';
import '../widgets/grid_background.dart';
import '../widgets/marquee.dart';
import '../../domain/model/menu_entry.dart';
import '../widgets/menus.dart';
import '../widgets/node_renderer.dart';

/// A Widget that renders a canvas that can be
/// panned and zoomed.
///
/// This can not be shrink wrapped, so it should be used
/// as a full screen / expanded widget.
class InfiniteCanvas extends StatefulWidget {
  const InfiniteCanvas(
      {super.key,
      required this.controller,
      this.gridSize = const Size.square(50),
      this.menuVisible = true,
      this.menus = const [],
      this.backgroundBuilder,
      this.drawVisibleOnly = false,
      this.canAddEdges = false,
      this.canvasSize = const Size(4096, 4096),
      this.minScale = 0.2,
      this.maxScale = 2,
      this.initialScale = 0.5,
      this.edgesUseStraightLines = false});

  final InfiniteCanvasController controller;
  final Size gridSize;
  final bool menuVisible;
  final List<MenuEntry> menus;
  final bool drawVisibleOnly;
  final bool canAddEdges;
  final bool edgesUseStraightLines;
  final Size canvasSize;
  final double minScale;
  final double maxScale;
  final double initialScale;
  final Widget Function(BuildContext, Rect)? backgroundBuilder;

  @override
  State<InfiniteCanvas> createState() => InfiniteCanvasState();
}

class InfiniteCanvasState extends State<InfiniteCanvas> {
  @override
  void initState() {
    super.initState();
    controller.addListener(onUpdate);
    controller.focusNode.requestFocus();
    controller.canvasSize = widget.canvasSize;
    controller.minScale = widget.minScale;
    controller.maxScale = widget.maxScale;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      controller.xTranslate = MediaQuery.of(context).size.width / 6;
      controller.yTranslate = MediaQuery.of(context).size.height / 6;
      double dx = -widget.canvasSize.width / 4 + controller.frameSize.width / 4;
      double dy =
          -widget.canvasSize.height / 4 + controller.frameSize.height / 4;
      if (MediaQuery.of(context).size.width >
          widget.canvasSize.width * controller.getScale()) {
        dx = 0;
        controller.xTranslate = 0;
      }
      if (MediaQuery.of(context).size.height >
          widget.canvasSize.height * controller.getScale()) {
        dy = 0;
        controller.yTranslate = 0;
      }
      controller.pan(Offset(
            dx,
            dy,
          ) +
          controller.toLocal(Offset(
            controller.xTranslate,
            controller.yTranslate,
          )));
    });
    controller.zoomReset(scale: widget.initialScale);
    controller.nodes.add(InfiniteCanvasNode(
        key: controller.frameKey,
        label: 'frame',
        allowResize: false,
        allowMove: true,
        offset: Offset(
          (widget.canvasSize.width - controller.frameSize.width) / 4,
          (widget.canvasSize.height - controller.frameSize.height) / 4,
        ),
        size: Size(controller.frameSize.width, controller.frameSize.height),
        child: Builder(
          builder: (context) {
            return Container(
              // child: Icon(
              //   Icons.brush,
              //   size: 80r,
              //   color: Colors.white,
              // ),
              decoration: BoxDecoration(
                color: Colors.black12,
                border: Border.all(
                  color: Colors.amber,
                  width: 5,
                ),
              ),
              // width: controller.frameSize.width,
              // height: controller.frameSize.height,
            );
          },
        )));
  }

  @override
  void dispose() {
    controller.removeListener(onUpdate);
    controller.focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InfiniteCanvas oldWidget) {
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(onUpdate);
      controller.addListener(onUpdate);
    }
    if (oldWidget.menus != widget.menus ||
        oldWidget.menuVisible != widget.menuVisible ||
        oldWidget.canAddEdges != widget.canAddEdges ||
        oldWidget.drawVisibleOnly != widget.drawVisibleOnly) {
      if (mounted) setState(() {});
    }
    super.didUpdateWidget(oldWidget);
  }

  void onUpdate() {
    if (mounted) setState(() {});
  }

  InfiniteCanvasController get controller => widget.controller;

  Rect axisAlignedBoundingBox(Quad quad) {
    double xMin = quad.point0.x;
    double xMax = quad.point0.x;
    double yMin = quad.point0.y;
    double yMax = quad.point0.y;

    for (final Vector3 point in <Vector3>[
      quad.point1,
      quad.point2,
      quad.point3,
    ]) {
      if (point.x < xMin) {
        xMin = point.x;
      } else if (point.x > xMax) {
        xMax = point.x;
      }

      if (point.y < yMin) {
        yMin = point.y;
      } else if (point.y > yMax) {
        yMax = point.y;
      }
    }

    return Rect.fromLTRB(xMin, yMin, xMax, yMax);
  }

  Widget buildBackground(BuildContext context, Quad quad) {
    final viewport = axisAlignedBoundingBox(quad);
    if (widget.backgroundBuilder != null) {
      return widget.backgroundBuilder!(context, viewport);
    }
    return GridBackgroundBuilder(
      cellWidth: widget.gridSize.width,
      cellHeight: widget.gridSize.height,
      viewport: viewport,
    );
  }

  List<InfiniteCanvasNode> getNodes(BoxConstraints constraints) {
    if (widget.drawVisibleOnly) {
      final nodes = <InfiniteCanvasNode>[];
      final viewport = controller.getRect(constraints);
      for (final node in controller.nodes) {
        if (node.rect.overlaps(viewport)) {
          nodes.add(node);
        }
      }
      return nodes;
    }
    return controller.nodes;
  }

  List<InfiniteCanvasEdge> getEdges(BoxConstraints constraints) {
    if (widget.drawVisibleOnly) {
      final nodes = getNodes(constraints);
      final nodeKeys = nodes.map((e) => e.key).toSet();
      final edges = <InfiniteCanvasEdge>[];
      for (final edge in controller.edges) {
        if (nodeKeys.contains(edge.from) || nodeKeys.contains(edge.to)) {
          edges.add(edge);
        }
      }
      return edges;
    }
    return controller.edges;
  }

  @override
  Widget build(BuildContext context) {
    return Menus(
      controller: widget.controller,
      visible: widget.menuVisible,
      menus: widget.menus,
      child: Listener(
        onPointerDown: (details) {
          controller.mouseDown = true;
          if (controller.processing) return;
          controller.checkSelection(details.localPosition);

          // if (controller.selection.isEmpty) {
          //   // if (!controller.spacePressed) {
          //   //   controller.marqueeStart = details.localPosition;
          //   //   controller.marqueeEnd = details.localPosition;
          //   // }
          // } else {
          //   if (controller.controlPressed && widget.canAddEdges) {
          //     final selected = controller.selection.last;

          //   }
          // }
        },
        onPointerUp: (details) {
          controller.mouseDown = false;
          // if (controller.marqueeStart != null &&
          //     controller.marqueeEnd != null) {
          //   controller.checkMarqueeSelection();
          // }
          // if (controller.linkStart != null && controller.linkEnd != null) {
          //   controller.checkSelection(controller.linkEnd!);
          //   if (controller.selection.isNotEmpty) {
          //     final selected = controller.selection.last;
          //     controller.addLink(controller.linkStart!, selected.key);
          //   }
          // }
          // controller.marqueeStart = null;
          // controller.marqueeEnd = null;
          // controller.linkStart = null;
          // controller.linkEnd = null;
        },
        onPointerCancel: (details) {
          controller.mouseDown = false;
        },
        onPointerHover: (details) {
          if (controller.processing) return;
          controller.mousePosition = details.localPosition;
          controller.checkSelection(controller.mousePosition, true);
        },
        onPointerMove: (details) {
          // controller.marqueeEnd = details.localPosition;
          // if (controller.marqueeStart != null &&
          //     controller.marqueeEnd != null) {
          //   controller.checkMarqueeSelection(true);
          // }
          // if (controller.linkStart != null) {
          //   controller.linkEnd = details.localPosition;
          //   controller.checkSelection(controller.linkEnd!, true);
          // }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            controller.viewport = constraints.biggest;

            return InteractiveViewer.builder(
              transformationController: controller.transform,
              panEnabled: controller.canvasMoveEnabled,
              scaleEnabled: controller.canvasMoveEnabled,
              onInteractionStart: (details) {
                controller.mousePosition = details.focalPoint;
                controller.mouseDragStart = controller.mousePosition;
              },
              onInteractionUpdate: (details) {
                // if (controller.processing) return;
                if (!controller.mouseDown) {
                  controller.scale = details.scale;
                } else if (controller.spacePressed) {
                  controller.pan(details.focalPointDelta);
                } else if (controller.controlPressed) {
                } else {
                  controller.moveSelection(details.focalPoint);
                }
                controller.mousePosition = details.focalPoint;
              },
              onInteractionEnd: (_) => controller.mouseDragStart = null,
              minScale: controller.minScale,
              maxScale: controller.maxScale,
              boundaryMargin: EdgeInsets.zero,
              builder: (context, quad) {
                final nodes = getNodes(constraints);
                return SizedBox.fromSize(
                  // size: controller.getMaxSize().size,
                  size: widget.canvasSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: buildBackground(context, quad),
                      ),

                      // Positioned.fill(
                      //   child: InfiniteCanvasEdgeRenderer(
                      //     controller: controller,
                      //     edges: edges,
                      //     linkStart: controller
                      //         .getNode(controller.linkStart)
                      //         ?.rect
                      //         .center,
                      //     linkEnd: controller.linkEnd,
                      //     straightLines: widget.edgesUseStraightLines,
                      //   ),
                      // ),
                      Positioned(
                        // top: controller.getPositionOffset().dy,
                        // left: controller.getPositionOffset().dx,
                        // top: 0,
                        // left: 0,
                        child: SizedBox.fromSize(
                            size: controller.getMaxSize().size,
                            child: Container(
                              // margin: EdgeInsets.only(
                              //     top: controller.getTop(),
                              //     left: controller.getLeft()),
                              // color: Colors.red.withOpacity(0.5),
                              child: RepaintBoundary(
                                  key: controller.canvasKey,
                                  child: CustomMultiChildLayout(
                                    delegate:
                                        InfiniteCanvasNodesDelegate(nodes),
                                    children: nodes
                                        .map((e) => LayoutId(
                                              key: e.key,
                                              id: e,
                                              child: NodeRenderer(
                                                node: e,
                                                controller: controller,
                                              ),
                                            ))
                                        .toList(),
                                  )),
                            )),
                      ),

                      // Positioned.fill(
                      //   child: IgnorePointer(
                      //       ignoring: false,
                      //       child: SizedBox(
                      //           width: controller.canvasSize.width,
                      //           height: controller.canvasSize.height,
                      //           child: Container(
                      //             color: Colors.blue.withOpacity(0.5),
                      //           ))),
                      // ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
