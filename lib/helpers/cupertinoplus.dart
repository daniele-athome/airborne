import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils.dart';

const double kDefaultCupertinoFormRowStartPadding = 20.0;

const EdgeInsetsGeometry kDefaultCupertinoFormRowPadding =
    EdgeInsets.symmetric(horizontal: kDefaultCupertinoFormRowStartPadding, vertical: 6.0);

const EdgeInsetsGeometry kDefaultCupertinoFormRowWithHelperPadding =
EdgeInsets.symmetric(horizontal: kDefaultCupertinoFormRowStartPadding, vertical: 12.0);

const EdgeInsetsGeometry kDefaultCupertinoFormRowHorizontalPadding =
    EdgeInsets.symmetric(horizontal: kDefaultCupertinoFormRowStartPadding);

const EdgeInsetsGeometry kDefaultCupertinoFormRowVerticalPadding =
    EdgeInsets.symmetric(vertical: 6.0);

/// Margin between form sections.
const double kDefaultCupertinoFormSectionMargin = 34.0;

/// Top margin for the first [CupertinoFormSection]
const double kDefaultCupertinoFormTopMargin = kDefaultCupertinoFormSectionMargin / 2;

/// A trick for making the background of dialogs a little darker when in light mode.
CupertinoDynamicColor kCupertinoDialogScaffoldBackgroundColor(BuildContext context) =>
  CupertinoDynamicColor.withBrightness(
    //color: CupertinoTheme.of(context).barBackgroundColor,
    // FIXME non-transparent version of the above color, since it was causing problems with page transitions
    color: const Color(0xFFEDEEEE),
    darkColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
  );

/// A standard-sized container for a [CupertinoFormRow] child.
class CupertinoFormRowContainer extends StatelessWidget {
  const CupertinoFormRowContainer({
    Key? key,
    this.child,
  }) : super(key: key);

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(minHeight: kMinInteractiveDimensionCupertino),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// A button-like [CupertinoFormRow]. Heavily inspired by [CupertinoButton].
/// TODO animate the background color
class CupertinoFormButtonRow extends StatefulWidget {

  const CupertinoFormButtonRow({
    Key? key,
    required this.child,
    this.prefix,
    this.padding,
    this.helper,
    this.error,
    this.pressedOpacity = 0.4,
    required this.onPressed,
  }) : super(key: key);

  final Widget? prefix;
  final EdgeInsetsGeometry? padding;
  final Widget? helper;
  final Widget? error;
  final double? pressedOpacity;
  final VoidCallback? onPressed;
  final Widget child;

  bool get enabled => onPressed != null;

  @override
  _CupertinoFormButtonRowState createState() => _CupertinoFormButtonRowState();
}

class _CupertinoFormButtonRowState extends State<CupertinoFormButtonRow> with SingleTickerProviderStateMixin {
  // Eyeballed values. Feel free to tweak.
  static const Duration kFadeOutDuration = Duration(milliseconds: 120);
  static const Duration kFadeInDuration = Duration(milliseconds: 180);
  final Tween<double> _opacityTween = Tween<double>(begin: 1.0);

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      value: 0.0,
      vsync: this,
    );
    _opacityAnimation = _animationController
        .drive(CurveTween(curve: Curves.decelerate))
        .drive(_opacityTween);
    _setTween();
  }

  @override
  void didUpdateWidget(CupertinoFormButtonRow old) {
    super.didUpdateWidget(old);
    _setTween();
  }

  void _setTween() {
    _opacityTween.end = widget.pressedOpacity ?? 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _buttonHeldDown = false;

  void _handleTapDown(TapDownDetails event) {
    if (!_buttonHeldDown) {
      _buttonHeldDown = true;
      _animate();
    }
  }

  void _handleTapUp(TapUpDetails event) {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _handleTapCancel() {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _animate() {
    if (_animationController.isAnimating) {
      return;
    }
    final bool wasHeldDown = _buttonHeldDown;
    final TickerFuture ticker = _buttonHeldDown
        ? _animationController.animateTo(1.0, duration: kFadeOutDuration, curve: Curves.easeInOutCubic/*Emphasized*/)
        : _animationController.animateTo(0.0, duration: kFadeInDuration, curve: Curves.easeOutCubic);
    ticker.then<void>((void value) {
      if (mounted && wasHeldDown != _buttonHeldDown) {
        _animate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? _handleTapDown : null,
      onTapUp: enabled ? _handleTapUp : null,
      onTapCancel: enabled ? _handleTapCancel : null,
      onTap: widget.onPressed,
      child: Semantics(
        button: true,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: CupertinoFormRow(
            prefix: widget.prefix,
            helper: widget.helper,
            error: widget.error,
            padding: widget.padding,
            child: widget.child
          ),
        ),
      ),
    );
  }

}

/// A Cupertino form field row that activates and date and time picker on tap.
/// Inspired by [CupertinoTextFormFieldRow].
class CupertinoDateTimeFormFieldRow extends FormField<DateTime> {

  // TODO other constructor parameters
  CupertinoDateTimeFormFieldRow({
    Key? key,
    this.prefix,
    this.controller,
    this.helper,
    DateTime? initialValue,
    ValueChanged<DateTime>? onChanged,
    FormFieldSetter<DateTime>? onSaved,
  }) :
      super(
        key: key,
        initialValue: controller?.value ?? initialValue ?? DateTime.now(),
        onSaved: onSaved,
        builder: (FormFieldState<DateTime> field) {
          void onTapDateHandler() {
            showDatePicker(
              context: field.context,
              builder: (context, child) => Theme(
                  data: getBrightness(context) == Brightness.dark ?
                    ThemeData.dark() : ThemeData.light(),
                  child: child!
              ),
              initialDate: field.value!,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            ).then((value) {
              if (value != null) {
                final newValue = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  field.value!.hour,
                  field.value!.minute,
                );
                field.didChange(newValue);
                if (onChanged != null) {
                  onChanged(newValue);
                }
              }
            });
          }

          void onTapTimeHandler() {
            showTimePicker(
              context: field.context,
              builder: (context, child) => Theme(
                  data: getBrightness(context) == Brightness.dark ?
                    ThemeData.dark() : ThemeData.light(),
                  child: child!
              ),
              initialTime: TimeOfDay(
                hour: field.value!.hour,
                minute: field.value!.minute,
              ),
            ).then((value) {
              if (value != null) {
                final newValue = DateTime(
                  field.value!.year,
                  field.value!.month,
                  field.value!.day,
                  value.hour,
                  value.minute,
                );
                field.didChange(newValue);
                if (onChanged != null) {
                  onChanged(newValue);
                }
              }
            });
          }

          final TextStyle textStyle = CupertinoTheme.of(field.context).textTheme.textStyle;

          return CupertinoFormRowContainer(
            child: CupertinoFormRow(
              prefix: prefix,
              padding: const EdgeInsetsDirectional.fromSTEB(kDefaultCupertinoFormRowStartPadding, 0, 0, 0),
              helper: helper,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // TODO tap color effect
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapDateHandler,
                    child: Padding(
                      padding: helper != null ? kDefaultCupertinoFormRowWithHelperPadding : kDefaultCupertinoFormRowPadding,
                      child: Text(
                        // TODO locale
                        field.value != null ? DateFormat('EEE, dd/MM/yyyy').format(field.value!) : '',
                        style: textStyle,
                      ),
                    ),
                  ),
                  // TODO tap color effect
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapTimeHandler,
                    child: Padding(
                      padding: helper != null ? kDefaultCupertinoFormRowWithHelperPadding : kDefaultCupertinoFormRowPadding,
                      child: Text(
                        // TODO locale
                        field.value != null ? DateFormat('HH:mm').format(field.value!) : '',
                        style: textStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  final Widget? prefix;

  final DateTimePickerController? controller;

  final Widget? helper;

  @override
  _CupertinoDateTimeFormFieldRowState createState() =>
      _CupertinoDateTimeFormFieldRowState();

}

class _CupertinoDateTimeFormFieldRowState extends FormFieldState<DateTime> {
  DateTimePickerController? _controller;

  DateTimePickerController? get _effectiveController =>
      widget.controller ?? _controller;

  @override
  CupertinoDateTimeFormFieldRow get widget =>
      super.widget as CupertinoDateTimeFormFieldRow;

  @override
  void initState() {
    super.initState();
    setValue(widget.initialValue);
    if (widget.controller == null) {
      _controller = DateTimePickerController(widget.initialValue);
    }
    else {
      widget.controller!.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(CupertinoDateTimeFormFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);

      if (oldWidget.controller != null && widget.controller == null) {
        _controller = DateTimePickerController(oldWidget.controller!.value);
      }

      if (widget.controller != null) {
        setValue(widget.controller!.value);
        if (oldWidget.controller == null) {
          _controller = null;
        }
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void didChange(DateTime? value) {
    super.didChange(value);

    if (value != null && _effectiveController!.value != value) {
      _effectiveController!.value = value;
    }
  }

  @override
  void reset() {
    super.reset();

    if (widget.initialValue != null) {
      setState(() {
        _effectiveController!.value = widget.initialValue;
      });
    }
  }

  void _handleControllerChanged() {
    // Suppress changes that originated from within this class.
    //
    // In the case where a controller has been passed in to this widget, we
    // register this change listener. In these cases, we'll also receive change
    // notifications for changes originating from within this class -- for
    // example, the reset() method. In such cases, the FormField value will
    // already have been set.
    if (_effectiveController!.value != value) {
      didChange(_effectiveController!.value);
    }
  }

}
