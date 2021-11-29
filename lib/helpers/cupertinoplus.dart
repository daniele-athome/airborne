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

/// Top and bottom margins for the first and last [CupertinoFormSection] (use as padding for the ListView)
const kDefaultCupertinoFormMargin = EdgeInsets.only(
  top: kDefaultCupertinoFormSectionMargin / 2,
  bottom: kDefaultCupertinoFormSectionMargin,
);

/// A trick for making the background of dialogs a little darker when in light mode.
CupertinoDynamicColor kCupertinoDialogScaffoldBackgroundColor(BuildContext context) =>
  CupertinoDynamicColor.withBrightness(
    //color: CupertinoTheme.of(context).barBackgroundColor,
    // FIXME non-transparent version of the above color, since it was causing problems with page transitions
    color: const Color(0xFFEDEEEE),
    darkColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
  );

/// From [CupertinoFormSection].
Widget buildCupertinoFormRowDivider(BuildContext context, bool shortDivider) {
  final Color dividerColor = CupertinoColors.separator.resolveFrom(context);
  final double dividerHeight = 1.0 / MediaQuery.of(context).devicePixelRatio;

  return Container(
    margin: (shortDivider) ? const EdgeInsetsDirectional.only(start: 15.0) : null,
    color: dividerColor,
    height: dividerHeight,
  );
}

/// An [InkWell] equivalent for Cupertino. Simply colors the background of the container.
class CupertinoInkWell extends StatefulWidget {
  const CupertinoInkWell({
    Key? key,
    required this.child,
    required this.onPressed,
  }) : super(key: key);

  final Widget child;
  final VoidCallback? onPressed;

  bool get enabled => onPressed != null;

  @override
  State<CupertinoInkWell> createState() => _CupertinoInkWellState();
}

class _CupertinoInkWellState extends State<CupertinoInkWell> {

  bool _buttonHeldDown = false;

  void _handleTapDown(TapDownDetails event) {
    if (!_buttonHeldDown) {
      setState(() {
        _buttonHeldDown = true;
      });
    }
  }

  void _handleTapUp(TapUpDetails event) {
    if (_buttonHeldDown) {
      setState(() {
        _buttonHeldDown = false;
      });
    }
  }

  void _handleTapCancel() {
    if (_buttonHeldDown) {
      setState(() {
        _buttonHeldDown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? _handleTapDown : null,
      onTapUp: enabled ? _handleTapUp : null,
      onTapCancel: enabled ? _handleTapCancel : null,
      onTap: widget.onPressed,
      child: Semantics(
        button: true,
        child: _buttonHeldDown ? Container(
          color: CupertinoColors.secondarySystemFill.resolveFrom(context),
          child: widget.child,
        ) : widget.child,
      ),
    );
  }
}

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
/// TODO animate the background color (or even better convert to [CupertinoInkWell])
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

  @override
  Widget build(BuildContext context) {
    return CupertinoInkWell(
      onPressed: widget.onPressed,
      child: Container(
        constraints:
        const BoxConstraints(minHeight: kMinInteractiveDimensionCupertino),
        alignment: Alignment.center,
        child: CupertinoFormRow(
            prefix: widget.prefix,
            helper: widget.helper,
            error: widget.error,
            padding: widget.padding,
            child: widget.child
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
    bool showDate = true,
    bool showTime = true,
    required this.doneButtonText,
    DateTime? initialValue,
    ValueChanged<DateTime>? onChanged,
    FormFieldSetter<DateTime>? onSaved,
  }) :
      assert(showDate || showTime, 'showDate and showTime cannot be both false!'),
      super(
        key: key,
        initialValue: controller?.value ?? initialValue ?? DateTime.now(),
        onSaved: onSaved,
        builder: (FormFieldState<DateTime> field) {
          void onTapDateHandler() {
            showCupertinoModalPopup(
              context: field.context,
              builder: (context) => Container(
                height: 300,
                color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CupertinoButton(
                          child: Text(doneButtonText),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        onDateTimeChanged: (value) {
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
                        },
                        initialDateTime: field.value,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          void onTapTimeHandler() {
            showCupertinoModalPopup(
              context: field.context,
              builder: (context) => Container(
                height: 300,
                color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CupertinoButton(
                          child: Text(doneButtonText),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        onDateTimeChanged: (value) {
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
                        },
                        use24hFormat: true,
                        initialDateTime: field.value,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final TextStyle textStyle = CupertinoTheme.of(field.context).textTheme.textStyle;

          // TODO refactor this
          return showDate != showTime ?
            CupertinoFormButtonRow(
              onPressed: showDate ? onTapDateHandler : onTapTimeHandler,
              padding: kDefaultCupertinoFormRowPadding,
              prefix: prefix,
              helper: helper,
              child: showDate ? Text(
                // TODO locale
                field.value != null ? DateFormat('EEE, dd/MM/yyyy').format(field.value!) : '',
                style: textStyle,
              ) : Text(
                // TODO locale
                field.value != null ? DateFormat('HH:mm').format(field.value!) : '',
                style: textStyle,
              ),
            ) :
            CupertinoFormRowContainer(
              child: CupertinoFormRow(
                prefix: prefix,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    kDefaultCupertinoFormRowStartPadding, 0, 0, 0),
                helper: helper,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // TODO tap color effect
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapDateHandler,
                      child: Padding(
                        padding: helper != null
                            ? kDefaultCupertinoFormRowWithHelperPadding
                            : kDefaultCupertinoFormRowPadding,
                        child: Text(
                          // TODO locale
                          field.value != null ? DateFormat('EEE, dd/MM/yyyy')
                              .format(field.value!) : '',
                          style: textStyle,
                        ),
                      ),
                    ),
                    // TODO tap color effect
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapTimeHandler,
                      child: Padding(
                        padding: helper != null
                            ? kDefaultCupertinoFormRowWithHelperPadding
                            : kDefaultCupertinoFormRowPadding,
                        child: Text(
                          // TODO locale
                          field.value != null ? DateFormat('HH:mm').format(
                              field.value!) : '',
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

  final String doneButtonText;

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
