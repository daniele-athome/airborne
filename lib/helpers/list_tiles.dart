import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils.dart';

@immutable
class DateListTile extends StatelessWidget {
  final DateTimePickerController controller;
  final Function(DateTime selected)? onDateSelected;
  final bool showIcon;
  final TextStyle? textStyle;

  static final DateFormat _dateFormatter = DateFormat.yMEd();

  const DateListTile({
    super.key,
    required this.controller,
    this.onDateSelected,
    // ignore: unused_element
    this.showIcon = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: showIcon
          ? const Icon(
              Icons.access_time,
            )
          : const Text(''),
      title: Text(
        controller.value != null
            ? _dateFormatter.format(controller.value!)
            : '',
        textAlign: TextAlign.left,
        style: textStyle,
      ),
      onTap: () async {
        final DateTime? date = await showDatePicker(
          context: context,
          initialDate: controller.value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          /* TODO builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData(
                              brightness:
                              widget.model.themeData.brightness,
                              colorScheme:
                              _getColorScheme(widget.model, true),
                              accentColor: widget.model.backgroundColor,
                              primaryColor:
                              widget.model.backgroundColor,
                            ),
                            child: child!,
                          );
                        }*/
        );
        if (date != null) {
          controller.value = date;
          if (onDateSelected != null) {
            onDateSelected!(date);
          }
        }
      },
    );
  }
}

@immutable
class DateTimeListTile extends StatelessWidget {
  final DateTimePickerController controller;
  final Function(DateTime selected, DateTime oldValue)? onDateSelected;
  final Function(DateTime selected, DateTime oldValue)? onTimeSelected;
  final bool showIcon;

  static final DateFormat _dateFormatter = DateFormat.yMEd();

  const DateTimeListTile({
    super.key,
    required this.controller,
    required this.onDateSelected,
    required this.onTimeSelected,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 7,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            leading: showIcon
                ? const Icon(
                    Icons.access_time,
                  )
                : const Text(''),
            title: Text(
              controller.value != null
                  ? getRelativeDateString(
                      context, _dateFormatter, controller.value!)
                  : '',
              textAlign: TextAlign.left,
            ),
            onTap: () async {
              final initialDate =
                  controller.value != null ? controller.value! : DateTime.now();
              final DateTime? date = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                /* TODO builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: ThemeData(
                                    brightness:
                                    widget.model.themeData.brightness,
                                    colorScheme:
                                    _getColorScheme(widget.model, true),
                                    accentColor: widget.model.backgroundColor,
                                    primaryColor:
                                    widget.model.backgroundColor,
                                  ),
                                  child: child!,
                                );
                              }*/
              );
              if (date != null) {
                final oldValue = initialDate;
                final newValue = _setDate(date);
                if (onDateSelected != null) {
                  onDateSelected!(newValue, oldValue);
                }
              }
            },
          ),
        ),
        Expanded(
          flex: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            title: Text(
              controller.value != null
                  ? DateFormat(kAviationTimeFormat).format(controller.value!)
                  : '',
              textAlign: TextAlign.right,
            ),
            onTap: () async {
              final initialDate =
                  controller.value != null ? controller.value! : DateTime.now();
              final TimeOfDay? time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: initialDate.hour, minute: initialDate.minute),
                /* TODO builder: (BuildContext context,
                                  Widget? child) {
                                return Theme(
                                  data: ThemeData(
                                    brightness: widget.model
                                        .themeData.brightness,
                                    colorScheme: _getColorScheme(
                                        widget.model, false),
                                    accentColor: widget
                                        .model.backgroundColor,
                                    primaryColor: widget
                                        .model.backgroundColor,
                                  ),
                                  child: child!,
                                );
                              }*/
              );
              if (time != null) {
                final oldValue = initialDate;
                final date = _setTime(time);
                if (onTimeSelected != null) {
                  onTimeSelected!(date, oldValue);
                }
              }
            },
          ),
        )
      ],
    );
  }

  DateTime _setDate(DateTime date) {
    var currentDate = controller.value;
    currentDate ??= DateTime.now();
    return controller.value = DateTime(
        date.year, date.month, date.day, currentDate.hour, currentDate.minute);
  }

  DateTime _setTime(TimeOfDay time) {
    var currentDate = controller.value;
    currentDate ??= DateTime.now();
    return controller.value = DateTime(currentDate.year, currentDate.month,
        currentDate.day, time.hour, time.minute);
  }
}
