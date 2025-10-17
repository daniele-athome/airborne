// Stateful version of future_progress_dialog.
// Future callbacks were interfering with the stateless nature of the old version.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'cupertinoplus.dart';

Decoration _defaultDecoration(BuildContext context) => isCupertino(context)
    ? BoxDecoration(
        color: kCupertinoDialogScaffoldBackgroundColor(
          context,
        ).resolveFrom(context),
        shape: BoxShape.rectangle,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      )
    : BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor,
        shape: BoxShape.rectangle,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      );

class FutureProgressDialog extends StatefulWidget {
  /// Dialog will be closed when [future] task is finished.
  @required
  final Future future;

  /// [BoxDecoration] of [FutureProgressDialog].
  final BoxDecoration? decoration;

  /// opacity of [FutureProgressDialog]
  final double opacity;

  /// If you want to use custom progress widget set [progress].
  final Widget? progress;

  /// If you want to use message widget set [message].
  final Widget? message;

  const FutureProgressDialog(
    this.future, {
    super.key,
    this.decoration,
    this.opacity = 1.0,
    this.progress,
    this.message,
  });

  @override
  State<FutureProgressDialog> createState() => _FutureProgressDialogState();
}

class _FutureProgressDialogState extends State<FutureProgressDialog> {
  @override
  void initState() {
    super.initState();
    widget.future
        .then((val) {
          if (mounted) {
            Navigator.of(context).pop(val);
          }
        })
        .catchError((e) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: _buildDialog(context));
  }

  Widget _buildDialog(BuildContext context) {
    Widget content;

    if (isCupertino(context)) {
      if (widget.message == null) {
        content = Center(
          child: Container(
            height: 100,
            width: 100,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            decoration: widget.decoration ?? _defaultDecoration(context),
            child:
                widget.progress ?? const CupertinoActivityIndicator(radius: 24),
          ),
        );
      } else {
        content = Center(
          child: Container(
            height: 120,
            constraints: BoxConstraints.loose(const Size(200, 150)),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            decoration: widget.decoration ?? _defaultDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.progress ?? const CupertinoActivityIndicator(radius: 24),
                const SizedBox(height: 10),
                _buildText(context),
              ],
            ),
          ),
        );
      }

      // no dialog needed
      return content;
    } else {
      if (widget.message == null) {
        content = Center(
          heightFactor: 1.0,
          // FIXME width ignored
          widthFactor: 1.0,
          child: Container(
            height: 80,
            // FIXME width ignored
            width: 80,
            alignment: Alignment.center,
            decoration: widget.decoration ?? _defaultDecoration(context),
            child: widget.progress ?? const CircularProgressIndicator(),
          ),
        );
      } else {
        content = Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: widget.decoration ?? _defaultDecoration(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              widget.progress ?? const CircularProgressIndicator(),
              const SizedBox(width: 20),
              _buildText(context),
            ],
          ),
        );
      }

      return PlatformAlertDialog(
        material: (context, platform) => MaterialAlertDialogData(elevation: 0),
        content: Opacity(opacity: widget.opacity, child: content),
      );
    }
  }

  Widget _buildText(BuildContext context) {
    if (widget.message == null) {
      return const SizedBox.shrink();
    }
    return Expanded(flex: 1, child: widget.message!);
  }
}
