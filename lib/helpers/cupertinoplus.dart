import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:cupertino_calendar_picker/src/picker/button/cupertino_picker_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils.dart';

// dummy mandatory values for the date picker
final DateTime _kDatePickerMinimumDate = DateTime.now().subtract(
  Duration(days: 50 * 365),
);
final DateTime _kDatePickerMaximumDate = DateTime.now().add(
  Duration(days: 50 * 365),
);

const double kDefaultCupertinoFormRowStartPadding = 20.0;

const EdgeInsetsGeometry kDefaultCupertinoFormRowPadding = EdgeInsets.symmetric(
  horizontal: kDefaultCupertinoFormRowStartPadding,
  vertical: 6.0,
);

const EdgeInsetsGeometry kDefaultCupertinoFormRowHorizontalPadding =
    EdgeInsets.symmetric(horizontal: kDefaultCupertinoFormRowStartPadding);

const EdgeInsetsGeometry kDefaultCupertinoFormRowVerticalPadding =
    EdgeInsets.symmetric(vertical: 6.0);

const EdgeInsetsGeometry kDefaultCupertinoDateTimeFormRowPadding =
    EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0);

/// Margin between form sections.
const double kDefaultCupertinoFormSectionMargin = 22.0;

/// Top and bottom margins for the first and last [CupertinoFormSection] (use as padding for the ListView)
const kDefaultCupertinoFormMargin = EdgeInsets.only(
  top: kDefaultCupertinoFormSectionMargin / 2,
  bottom: kDefaultCupertinoFormSectionMargin,
);

/// A trick for making the background of dialogs a little darker when in light mode.
CupertinoDynamicColor kCupertinoDialogScaffoldBackgroundColor(
  BuildContext context,
) => CupertinoDynamicColor.withBrightness(
  //color: CupertinoTheme.of(context).barBackgroundColor,
  // FIXME non-transparent version of the above color, since it was causing problems with page transitions
  color: const Color(0xFFF2F2F7),
  darkColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
);

/// From [CupertinoFormSection].
Widget buildCupertinoFormRowDivider(BuildContext context, bool shortDivider) {
  final Color dividerColor = CupertinoColors.separator.resolveFrom(context);
  final double dividerHeight = 1.0 / MediaQuery.of(context).devicePixelRatio;

  return Container(
    margin: (shortDivider)
        ? const EdgeInsetsDirectional.only(start: 15.0)
        : null,
    color: dividerColor,
    height: dividerHeight,
  );
}

/// An [InkWell] equivalent for Cupertino. Simply colors the background of the container.
class CupertinoInkWell extends StatefulWidget {
  const CupertinoInkWell({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

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
        child: Container(
          color: _buttonHeldDown
              ? CupertinoColors.secondarySystemFill.resolveFrom(context)
              : widget.backgroundColor,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A standard-sized container for a [CupertinoFormRow] child.
class CupertinoFormRowContainer extends StatelessWidget {
  const CupertinoFormRowContainer({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: kMinInteractiveDimensionCupertino,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// A button-like [CupertinoFormRow]. Heavily inspired by [CupertinoButton].
class CupertinoFormButtonRow extends StatefulWidget {
  const CupertinoFormButtonRow({
    super.key,
    required this.child,
    this.prefix,
    this.padding,
    this.helper,
    this.error,
    this.pressedOpacity = 0.4,
    required this.onPressed,
  });

  final Widget? prefix;
  final EdgeInsetsGeometry? padding;
  final Widget? helper;
  final Widget? error;
  final double? pressedOpacity;
  final VoidCallback? onPressed;
  final Widget child;

  bool get enabled => onPressed != null;

  @override
  State<CupertinoFormButtonRow> createState() => _CupertinoFormButtonRowState();
}

class _CupertinoFormButtonRowState extends State<CupertinoFormButtonRow>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return CupertinoInkWell(
      onPressed: widget.onPressed,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimensionCupertino,
        ),
        alignment: Alignment.center,
        child: CupertinoFormRow(
          prefix: widget.prefix,
          helper: widget.helper,
          error: widget.error,
          padding: widget.padding,
          child: widget.child,
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
    super.key,
    this.prefix,
    this.controller,
    this.helper,
    bool showDate = true,
    bool showTime = true,
    DateTime? initialValue,
    void Function(DateTime value, DateTime oldValue)? onChanged,
    super.onSaved,
  }) : assert(
         showDate || showTime,
         'showDate and showTime cannot be both false!',
       ),
       super(
         initialValue: controller?.value ?? initialValue ?? DateTime.now(),
         builder: (FormFieldState<DateTime> field) {
           // FIXME too messy
           return ChangeNotifierProvider<ExpansibleController>(
             create: (context) => ExpansibleController(),
             builder: (context, child) => Consumer<ExpansibleController>(
               builder: (context, expansibleController, child) =>
                   CupertinoDateTimeFormRowContainer(
                     prefix: prefix,
                     helper: helper,
                     showDate: showDate,
                     showTime: showTime,
                     field: field,
                   ),
             ),
           );
         },
       );

  final Widget? prefix;

  final DateTimePickerController? controller;

  final Widget? helper;

  @override
  FormFieldState<DateTime> createState() =>
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
    } else {
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

class CupertinoDateTimeFormRowContainer extends StatefulWidget {
  const CupertinoDateTimeFormRowContainer({super.key,
    required this.field,
    this.prefix,
    this.controller,
    this.helper,
    this.showDate = true,
    this.showTime = true,
  });

  final Widget? prefix;

  final DateTimePickerController? controller;

  final Widget? helper;

  final bool showDate;

  final bool showTime;

  final FormFieldState<DateTime> field;

  @override
  State<CupertinoDateTimeFormRowContainer> createState() =>
      _CupertinoDateTimeFormRowContainerState();
}

class _CupertinoDateTimeFormRowContainerState
    extends State<CupertinoDateTimeFormRowContainer> {

  late final ExpansibleController _expansibleController;

  @override
  void initState() {
    super.initState();
    _expansibleController = ExpansibleController();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoFormRowContainer(
      child: Expansible(
        controller: _expansibleController,
        bodyBuilder: (context, animation) => CupertinoCalendar(
          minimumDateTime: _kDatePickerMinimumDate,
          maximumDateTime: _kDatePickerMaximumDate,
        ),
        headerBuilder: (context, animation) => CupertinoFormRow(
          prefix: widget.prefix,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: kDefaultCupertinoFormRowStartPadding,
          ),
          helper: widget.helper,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.showDate)
                Padding(
                  padding:
                  kDefaultCupertinoDateTimeFormRowPadding,
                  child: CupertinoPickerButton<DateTime?>(
                    // TODO
                    title: 'TODO',
                    mainColor: CupertinoColors.systemRed,
                    showPickerFunction: (renderBox) async {
                      // TODO
                      _expansibleController.expand();
                      await Future.delayed(Duration(seconds: 5));
                      _expansibleController.collapse();
                      return null;
                    },
                    onPressed: () {
                      // TODO
                    },
                  ),
                  /*child: CupertinoCalendarPickerButton(
                               initialDateTime: field.value,
                               minimumDateTime: _kDatePickerMinimumDate,
                               maximumDateTime: _kDatePickerMaximumDate,
                               onDateSelected: (value) {
                                 final oldValue = field.value!;
                                 final newValue = DateTime(
                                   value.year,
                                   value.month,
                                   value.day,
                                   field.value!.hour,
                                   field.value!.minute,
                                 );
                                 field.didChange(newValue);
                                 if (onChanged != null) {
                                   onChanged(newValue, oldValue);
                                 }
                               },
                             ),*/
                ),
              if (widget.showTime)
                Padding(
                  padding:
                  kDefaultCupertinoDateTimeFormRowPadding,
                  child: CupertinoTimePickerButton(
                    initialTime: TimeOfDay.fromDateTime(
                      widget.field.value!,
                    ),
                    use24hFormat: true,
                    onTimeChanged: (value) {
                      final oldValue = widget.field.value!;
                      final newValue = DateTime(
                        widget.field.value!.year,
                        widget.field.value!.month,
                        widget.field.value!.day,
                        value.hour,
                        value.minute,
                      );
                      widget.field.didChange(newValue);
                      /* TODO if (onChanged != null) {
                        onChanged(newValue, oldValue);
                      }*/
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
