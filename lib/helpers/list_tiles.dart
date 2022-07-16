
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils.dart';

@immutable
class DateListTile extends StatelessWidget {
  final DateTimePickerController controller;
  final Function(DateTime? selected)? onDateSelected;
  final bool showIcon;
  final TextStyle? textStyle;

  final DateFormat _dateFormatter = DateFormat.yMEd();

  DateListTile({
    Key? key,
    required this.controller,
    this.onDateSelected,
    // ignore: unused_element
    this.showIcon = true,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: showIcon ? const Icon(
        Icons.access_time,
      ) : const Text(''),
      title: Text(
        controller.value != null ? _dateFormatter.format(controller.value!) : '',
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

// FIXME refactor into widget + controller (e.g. like a text field)
@immutable
class DateTimeListTile extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final Function(DateTime? selected) onDateSelected;
  final Function(TimeOfDay? selected) onTimeSelected;
  final bool showIcon;

  final DateFormat _dateFormatter = DateFormat.yMEd();

  DateTimeListTile({
    Key? key,
    required this.onDateSelected,
    required this.onTimeSelected,
    required this.selectedDate,
    required this.selectedTime,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 7,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            leading: showIcon ? const Icon(
              Icons.access_time,
            ) : const Text(''),
            title: Text(
              _dateFormatter.format(selectedDate),
              textAlign: TextAlign.left,
            ),
            onTap: () async {
              final DateTime? date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
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
              onDateSelected(date);
            },
          ),
        ),
        Expanded(
          flex: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            title: Text(
              DateFormat(kAviationTimeFormat).format(selectedDate),
              textAlign: TextAlign.right,
            ),
            onTap: () async {
              final TimeOfDay? time =
              await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: selectedTime.hour,
                    minute: selectedTime.minute
                ),
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

              onTimeSelected(time);
            },
          ),
        )
      ],
    );
  }

}
