import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';

import '../../domain/model/node.dart';
import '../state/controller.dart';
import 'clipper.dart';
import 'drag_handel.dart';

class NodeRenderer extends StatelessWidget {
  const NodeRenderer({
    super.key,
    required this.node,
    required this.controller,
  });

  final InfiniteCanvasNode node;
  final InfiniteCanvasController controller;

  static const double borderInset = 2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fonts = Theme.of(context).textTheme;
    final showHandles = node.allowResize && controller.isSelected(node.key);
    late PageController? pageController;
    if (node.type == 'page') {
      pageController = PageController(
        initialPage: node.current,
      );
    }
    return Visibility(
        visible: node.visable,
        child: SizedBox.fromSize(
          size: node.size,
          child: Column(children: [
            Expanded(
                child: Stack(
              clipBehavior: Clip.none,
              children: [
                // if (node.label != null)
                //   Positioned(
                //     top: -25,
                //     left: 0,
                //     child: Text(
                //       node.label!,
                //       style: fonts.bodyMedium?.copyWith(
                //         color: colors.onSurface,
                //         shadows: [
                //           Shadow(
                //             offset: const Offset(0.8, 0.8),
                //             blurRadius: 3,
                //             color: colors.surface,
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                if (controller.isSelected(node.key) ||
                    controller.isHovered(node.key))
                  Positioned(
                    top: -borderInset,
                    left: -borderInset,
                    right: -borderInset,
                    bottom: -borderInset,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: controller.isSelected(node.key)
                                ? colors.primary
                                : colors.outline,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (node.children != null && node.type == 'page')
                  Positioned.fill(
                    key: key,
                    child: Stack(alignment: Alignment.center, children: [
                      PageView(
                        physics: const NeverScrollableScrollPhysics(),
                        // onPageChanged: (value) => node.updateCurrent(value),
                        controller: pageController,
                        children: node.children!,
                      ),
                      if (controller.isSelected(node.key))
                        Positioned(
                          bottom: 10,
                          child: DotsIndicator(
                            dotsCount: node.children!.length,
                            position: node.current,
                            decorator: DotsDecorator(
                              color: Colors.white,
                              activeColor: Colors.amber,
                              activeSize: Size(20, 20),
                              size: Size(10, 10),
                            ),
                          ),
                        )
                    ]),
                  )
                else if (node.child != null)
                  Positioned.fill(
                    key: key,
                    child: node.clipBehavior != Clip.none
                        ? ClipRect(
                            clipper: Clipper(node.rect),
                            clipBehavior: node.clipBehavior,
                            child: node.child,
                          )
                        : node.child!,
                  ),
                if (showHandles) ...[
                  // bottom right
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // if (!controller.mouseDown) return;
                        node.update(size: node.size + details.delta);
                        controller.edit(node);
                      },
                      child: const DragHandel(),
                    ),
                  ),
                  // bottom left
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // if (!controller.mouseDown) return;
                        node.update(
                          size: node.size +
                              Offset(-details.delta.dx, details.delta.dy),
                          offset: node.offset + Offset(details.delta.dx, 0),
                        );
                        controller.edit(node);
                      },
                      child: const DragHandel(),
                    ),
                  ),
                  // top right
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // if (!controller.mouseDown) return;
                        node.update(
                          size: node.size +
                              Offset(details.delta.dx, -details.delta.dy),
                          offset: node.offset + Offset(0, details.delta.dy),
                        );
                        controller.edit(node);
                      },
                      child: const DragHandel(),
                    ),
                  ),
                  // top left
                  Positioned(
                    left: 0,
                    top: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // if (!controller.mouseDown) return;
                        node.update(
                          size: node.size + -details.delta,
                          offset: node.offset + details.delta,
                        );
                        controller.edit(node);
                      },
                      child: const DragHandel(),
                    ),
                  ),
                ],
                if (controller.isSelected(node.key) &&
                    node.key != controller.frameKey)
                  Positioned(
                      right: 40,
                      top: 40,
                      child: CircleAvatar(
                        backgroundColor: Colors.amber,
                        radius: 30,
                        child: InkWell(
                          onTap: () {
                            if (node.allowMove) {
                              node.lock();
                            } else {
                              node.unlock();
                            }
                          },
                          child: Icon(
                            node.allowMove
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                            size: 30,
                          ),
                        ),
                      )),
              ],
            )),
            if (node.type == 'page')
              SizedBox(
                height: 80,
                child: controller.isSelected(node.key)
                    ? Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios,
                                size: 35,
                              ),
                              onPressed: () {
                                if (node.current > 0) {
                                  pageController?.jumpToPage(node.current - 1);
                                  node.updateCurrent(
                                      pageController?.page?.toInt() ?? 0);
                                }
                              },
                            ),
                            Text(
                                '${node.current + 1} / ${node.children!.length}',
                                style: TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                size: 35,
                              ),
                              onPressed: () {
                                if (node.current < node.children!.length - 1) {
                                  pageController?.jumpToPage(node.current + 1);
                                  node.updateCurrent(
                                      pageController?.page?.toInt() ?? 0);
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : null,
              )
          ]),
        ));
  }
}
