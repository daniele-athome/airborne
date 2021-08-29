import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils.dart';

const EdgeInsetsGeometry kDefaultCupertinoFormRowPadding =
    EdgeInsetsDirectional.fromSTEB(20.0, 6.0, 20.0, 6.0);

/// Margin between form sections.
const double kDefaultCupertinoFormSectionMargin = 28.0;

/// Top margin for the first [CupertinoFormSection]
const double kDefaultCupertinoFormTopMargin = kDefaultCupertinoFormSectionMargin / 2;

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

/// A Cupertino form field row that activates and date and time picker on tap.
/// Inspired by [CupertinoTextFormFieldRow].
class CupertinoDateTimeFormFieldRow extends FormField<DateTime> {

  // TODO other constructor parameters
  CupertinoDateTimeFormFieldRow({
    Key? key,
    this.prefix,
    this.padding,
    this.controller,
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

          return CupertinoFormRowContainer(
            child: CupertinoFormRow(
              prefix: prefix,
              padding: padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // TODO tap color effect
                  GestureDetector(
                    onTap: onTapDateHandler,
                    child: Text(
                      // TODO locale
                      field.value != null ? DateFormat('EEE, dd/MM/yyyy').format(field.value!) : '',
                    ),
                  ),
                  const SizedBox(width: 20),
                  // TODO tap color effect
                  GestureDetector(
                    onTap: onTapTimeHandler,
                    child: Text(
                      // TODO locale
                      field.value != null ? DateFormat('HH:mm').format(field.value!) : '',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  final Widget? prefix;

  final EdgeInsetsGeometry? padding;

  final DateTimePickerController? controller;

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
