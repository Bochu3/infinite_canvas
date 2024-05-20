import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import '../state/controller.dart';
import '../../domain/model/menu_entry.dart';

/// A widget that displays a menu for the [InfiniteCanvas].
class Menus extends StatefulWidget {
  const Menus({
    super.key,
    this.menus = const [],
    required this.controller,
    required this.child,
    this.renameLabel,
    this.visible = true,
  });

  final List<MenuEntry> menus;
  final InfiniteCanvasController controller;
  final String Function(String)? renameLabel;
  final bool visible;
  final Widget child;

  @override
  State<Menus> createState() => _MenusState();
}

class _MenusState extends State<Menus> {
  ShortcutRegistryEntry? _shortcutsEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(onUpdate);
  }

  void onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shortcutsEntry?.dispose();
    widget.controller.removeListener(onUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Menus oldWidget) {
    if (oldWidget.visible != widget.visible) {
      if (mounted) setState(() {});
    }
    if (oldWidget.menus != widget.menus) {
      if (mounted) setState(() {});
    }
    super.didUpdateWidget(oldWidget);
  }

  MenuEntry buildView(BuildContext context) {
    return MenuEntry(
      label: 'View',
      menuChildren: [
        MenuEntry(
          label: 'Zoom In',
          onPressed: widget.controller.zoomIn,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.equal,
          ),
        ),
        MenuEntry(
          label: 'Zoom Out',
          onPressed: widget.controller.zoomOut,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.minus,
          ),
        ),
        MenuEntry(
          label: 'Move Up',
          onPressed: widget.controller.panUp,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.arrowUp,
          ),
        ),
        MenuEntry(
          label: 'Move Down',
          onPressed: widget.controller.panDown,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.arrowDown,
          ),
        ),
        MenuEntry(
          label: 'Move Left',
          onPressed: widget.controller.panLeft,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.arrowLeft,
          ),
        ),
        MenuEntry(
          label: 'Move Right',
          onPressed: widget.controller.panRight,
          shortcut: const SingleActivator(
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        MenuEntry(
          label: 'Reset',
          onPressed: widget.controller.zoomReset,
        ),
      ],
    );
  }

  MenuEntry buildEdit(BuildContext context) {
    return MenuEntry(
      label: 'Edit',
      menuChildren: [
        MenuEntry(
          label: 'Select All',
          onPressed: widget.controller.selection.length ==
                  widget.controller.nodes.length
              ? null
              : widget.controller.selectAll,
        ),
        MenuEntry(
          label: 'Deselect All',
          onPressed: widget.controller.selection.isEmpty
              ? null
              : widget.controller.deselectAll,
        ),
        MenuEntry(
          label: 'Send to back',
          onPressed: widget.controller.sendToBack,
        ),
        MenuEntry(
          label: 'Send backward',
          onPressed: widget.controller.selection.length == 1
              ? widget.controller.sendBackward
              : null,
        ),
        MenuEntry(
          label: 'Bring forward',
          onPressed: widget.controller.selection.length == 1
              ? widget.controller.sendForward
              : null,
        ),
        MenuEntry(
          label: 'Bring to front',
          onPressed: widget.controller.bringToFront,
        ),
        MenuEntry(
          label: 'Delete',
          onPressed: () {
            confirm(
              context,
              title: 'Delete Selection',
              content: 'Do you want to delete the current selection?',
            ).then(
              (value) {
                if (!value) return;
                widget.controller.deleteSelection();
              },
            );
          },
        ),
      ],
    );
  }

  List<MenuEntry> merge(BuildContext context) {
    final menus = <MenuEntry>[];
    menus.addAll(widget.menus);
    // if (!menus.map((e) => e.label).contains('View')) {
    //   menus.add(buildView(context));
    // } else {
    //   final idx = menus.indexWhere((e) => e.label == 'View');
    //   final value = menus[idx];
    //   final children = value.menuChildren ?? [];
    //   final merged = buildView(context).merge(children);
    //   menus.removeAt(idx);
    //   menus.insert(idx, merged);
    // }
    // if (!menus.map((e) => e.label).contains('Edit')) {
    //   menus.add(buildEdit(context));
    // } else {
    //   final idx = menus.indexWhere((e) => e.label == 'Edit');
    //   final value = menus[idx];
    //   final children = value.menuChildren ?? [];
    //   final merged = buildEdit(context).merge(children);
    //   menus.removeAt(idx);
    //   menus.insert(idx, merged);
    // }
    if (widget.renameLabel != null) {
      for (var i = 0; i < menus.length; i++) {
        final label = widget.renameLabel!(menus[i].label);
        menus[i] = menus[i].rename(label);
      }
    }
    return menus;
  }

  List<MenuEntry> createMenus(BuildContext context) {
    final result = merge(context);
    // _shortcutsEntry?.dispose();
    // final registry = ShortcutRegistry.of(context);
    // final items = MenuEntry.shortcuts(result);
    // if (items.isNotEmpty) {
    //   _shortcutsEntry = registry.addAll(items);
    // } else {
    //   _shortcutsEntry = null;
    // }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return widget.child;
    final result = createMenus(context);
    return Column(
      children: <Widget>[
        if (widget.visible)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: MenuBar(
                  children: MenuEntry.build(result),
                ),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
