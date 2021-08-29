
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/future_progress_dialog.dart';
import '../../helpers/utils.dart';
import '../../models/book_flight_models.dart';
import '../../services/book_flight_services.dart';

final Logger _log = Logger((FlightBooking).toString());

class BookFlightModal extends StatefulWidget {

  const BookFlightModal(this.event);

  final FlightBooking event;

  @override
  _BookFlightModalState createState() => _BookFlightModalState();

}

class _BookFlightModalState extends State<BookFlightModal> {

  // event data
  late String _pilotName;
  @Deprecated('Use _startDateController')
  late DateTime _startDate;
  @Deprecated('Use _startDateController')
  late TimeOfDay _startTime;
  @Deprecated('Use _endDateController')
  late DateTime _endDate;
  @Deprecated('Use _endDateController')
  late TimeOfDay _endTime;
  String? _notes;

  final DateTimePickerController _startDateController = DateTimePickerController(null);
  final DateTimePickerController _endDateController = DateTimePickerController(null);

  late BookFlightCalendarService _service;
  late AppConfig _appConfig;

  bool get _isEditing => widget.event.id != null;

  @override
  void initState() {
    _updateEventData();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _service = Provider.of<BookFlightCalendarService>(context);
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant BookFlightModal oldWidget) {
    _updateEventData();
    super.didUpdateWidget(oldWidget);
  }

  void _updateEventData() {
    _pilotName = widget.event.pilotName;
    _notes = widget.event.notes;
    _startDateController.value = widget.event.from;
    _startDate = widget.event.from;
    _endDate = widget.event.to;
    _endDateController.value = widget.event.to;
    _startTime = TimeOfDay(hour: _startDate.hour, minute: _startDate.minute);
    _endTime = TimeOfDay(hour: _endDate.hour, minute: _endDate.minute);
  }

  void _onStartDateChanged(DateTime? date, bool time) {
    if (date != null && date != _startDate) {
      setState(() {
        final Duration dateDifference =
          _endDate.difference(_startDate);
        _startDate = DateTime(
          date.year,
          date.month,
          date.day,
          _startTime.hour,
          _startTime.minute
        );
        _endDate = _startDate.add(dateDifference);
        _endTime = TimeOfDay(
          hour: _endDate.hour,
          minute: _endDate.minute,
        );

        if (time) {
          _startTime = TimeOfDay(
            hour: date.hour,
            minute: date.minute
          );
          final Duration timeDifference =
          _endDate.difference(_startDate);
          _startDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );
          _endDate = _startDate.add(timeDifference);
          _endTime = TimeOfDay(
            hour: _endDate.hour,
            minute: _endDate.minute
          );
        }

        _endDateController.value = _endDate;
      });
    }
  }

  void _onEndDateChanged(DateTime? date, bool time) {
    if (date != null && date != _endDate) {
      setState(() {
        final Duration dateDifference =
        _endDate.difference(_startDate);
        _endDate = DateTime(
          date.year,
          date.month,
          date.day,
          _endTime.hour,
          _endTime.minute,
        );
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate.subtract(dateDifference);
          _startTime = TimeOfDay(
            hour: _startDate.hour,
            minute: _startDate.minute
          );
          _startDateController.value = _startDate;
        }

        if (time) {
          _endTime = TimeOfDay(
            hour: date.hour,
            minute: date.minute
          );
          final Duration timeDifference =
          _endDate.difference(_startDate);
          _endDate = DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate.subtract(timeDifference);
            _startTime = TimeOfDay(
              hour: _startDate.hour,
              minute: _startDate.minute
            );
            _startDateController.value = _startDate;
          }
        }
      });
    }
  }

  Widget _buildCupertinoForm(BuildContext context, AppConfig appConfig, SunTimes startSunTimes, SunTimes endSunTimes) {
    return Column(
      children: [
        const SizedBox(height: kDefaultCupertinoFormTopMargin),
        CupertinoFormSection(children: <Widget>[
          // TODO selected color
          GestureDetector(
            onTap: () => _onTapPilot(context, appConfig),
            behavior: HitTestBehavior.opaque,
            child: CupertinoFormRow(
              padding: kDefaultCupertinoFormRowPadding,
              prefix: Text(
                AppLocalizations.of(context)!.bookFlightModal_label_pilot,
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _pilotName,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  CircleAvatar(backgroundImage: appConfig.getPilotAvatar(_pilotName)),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          CupertinoDateTimeFormFieldRow(
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.bookFlightModal_label_start),
            onChanged: (value) => _onStartDateChanged(value, true),
            controller: _startDateController,
          ),
          // TODO sunrise/sunset for start date
          CupertinoDateTimeFormFieldRow(
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.bookFlightModal_label_end),
            onChanged: (value) => _onEndDateChanged(value, true),
            controller: _endDateController,
          ),
          // TODO sunrise/sunset for end date
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          CupertinoTextFormFieldRow(
            // FIXME doesn't work because TextFormFieldRow can't pass padding to the text field -- padding: kDefaultCupertinoFormRowPadding,
            controller: TextEditingController(text: _notes),
            // TODO cursorColor: widget.model.backgroundColor,
            onChanged: (String value) {
              _notes = value;
            },
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 3,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            placeholder: AppLocalizations.of(context)!.bookFlightModal_hint_notes,
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: () => _onDelete(context),
                  child: Text(AppLocalizations.of(context)!.bookFlightModal_button_delete,
                    style: const TextStyle(color: CupertinoColors.destructiveRed),),
                ),
              ),
            ],
          )
        ]),
      ],
    );
  }

  Widget _buildMaterialForm(BuildContext context, AppConfig appConfig, SunTimes startSunTimes, SunTimes endSunTimes) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
          leading: CircleAvatar(backgroundImage: appConfig.getPilotAvatar(_pilotName)),
          title: Text(
            _pilotName,
            style: const TextStyle(
              fontSize: 20,
            ),
          ),
          onTap: () => _onTapPilot(context, appConfig),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // start date/time
        _DateTimeListTile(
          selectedDate: _startDate,
          selectedTime: _startTime,
          onDateSelected: (date) => _onStartDateChanged(date, false),
          onTimeSelected: (time) {
            if (time != null && time != _startTime) {
              setState(() {
                _startTime = time;
                final Duration difference =
                _endDate.difference(_startDate);
                // TODO time zone
                _startDate = DateTime(
                  _startDate.year,
                  _startDate.month,
                  _startDate.day,
                  _startTime.hour,
                  _startTime.minute,
                );
                _endDate = _startDate.add(difference);
                _endTime = TimeOfDay(
                    hour: _endDate.hour,
                    minute: _endDate.minute);
              });
            }
          },
        ),
        _SunTimesListTile(sunrise: startSunTimes.sunrise, sunset: startSunTimes.sunset),
        // end date/time
        _DateTimeListTile(
          selectedDate: _endDate,
          selectedTime: _endTime,
          showIcon: false,
          onDateSelected: (date) => _onEndDateChanged(date, false),
          onTimeSelected: (time) {
            if (time != null && time != _endTime) {
              setState(() {
                _endTime = time;
                final Duration difference =
                _endDate.difference(_startDate);
                // TODO time zone
                _endDate = DateTime(
                  _endDate.year,
                  _endDate.month,
                  _endDate.day,
                  _endTime.hour,
                  _endTime.minute,
                );
                if (_endDate.isBefore(_startDate)) {
                  _startDate = _endDate.subtract(difference);
                  _startTime = TimeOfDay(
                      hour: _startDate.hour,
                      minute: _startDate.minute);
                }
              });
            }
          },
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          child: _SunTimesListTile(sunrise: endSunTimes.sunrise, sunset: endSunTimes.sunset),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        ListTile(
          // FIXME TextField inside ListTile caused enter key to act as onPressed
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const Icon(
            Icons.subject,
          ),
          title: TextField(
            controller: TextEditingController(text: _notes),
            // TODO cursorColor: widget.model.backgroundColor,
            onChanged: (String value) {
              _notes = value;
            },
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: AppLocalizations.of(context)!.bookFlightModal_hint_notes,
            ),
          ),
        ),
      ],
    );
  }

  // FIXME use AppConfig state instance
  Widget _getEventEditor(BuildContext context, AppConfig appConfig) {
    final SunTimes startSunTimes = getSunTimes(appConfig.locationLatitude, appConfig.locationLongitude, _startDate, appConfig.locationTimeZone);
    final SunTimes endSunTimes = getSunTimes(appConfig.locationLatitude, appConfig.locationLongitude, _endDate, appConfig.locationTimeZone);

    return isCupertino(context) ?
      _buildCupertinoForm(context, appConfig, startSunTimes, endSunTimes) :
      _buildMaterialForm(context, appConfig, startSunTimes, endSunTimes);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> trailingActions;
    Widget? leadingAction;

    if (isCupertino(context)) {
      leadingAction = CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context)!.bookFlightModal_button_close),
      );
      trailingActions = [PlatformButton(
        onPressed: () => _onSave(context),
        cupertino: (_, __) => CupertinoButtonData(
          // workaround for https://github.com/flutter/flutter/issues/32701
          padding: EdgeInsets.zero,
        ),
        child: Text(AppLocalizations.of(context)!.bookFlightModal_button_save),
      )];
    }
    else {
      leadingAction = null;
      trailingActions = [
        PlatformIconButton(
          onPressed: () => _onSave(context),
          icon: const Icon(Icons.check_sharp),
          material: (_, __) => MaterialIconButtonData(
            tooltip: AppLocalizations.of(context)!.bookFlightModal_button_save,
          ),
        ),
      ];
      if (_isEditing) {
        trailingActions.insert(0, PlatformIconButton(
            onPressed: () => _onDelete(context),
            icon: const Icon(Icons.delete_sharp),
            material: (_, __) => MaterialIconButtonData(
              tooltip: AppLocalizations.of(context)!.bookFlightModal_button_delete,
            ),
          ),
        );
      }
    }

    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(_isEditing ?
          AppLocalizations.of(context)!.bookFlightModal_title_edit :
          AppLocalizations.of(context)!.bookFlightModal_title_create
        ),
        leading: leadingAction,
        trailingActions: trailingActions,
      ),
      body: Stack(
        children: <Widget>[
          _getEventEditor(context, _appConfig)
        ],
      ),
    );
  }

  void _onSave(BuildContext context) {
    // TODO no validate necessary here?

    if (_isEditing) {
      if (!_appConfig.admin) {
        if (_appConfig.pilotName != widget.event.pilotName) {
          _showError(AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_edit);
          return;
        }
      }
      else {
        // TODO allow pilot change but only to the non-pilot

        if (_pilotName != widget.event.pilotName) {
          _showConfirm(
            text: AppLocalizations.of(context)!.bookFlightModal_dialog_changePilot_message,
            title: AppLocalizations.of(context)!.bookFlightModal_dialog_changePilot_title,
            okCallback: () => _doSave(context)
          );
          return;
        }
      }
    }
    else {
      if (!_appConfig.admin) {
        if (_appConfig.pilotName != _pilotName) {
          _showError(AppLocalizations.of(context)!.bookFlightModal_error_bookingForOthers);
          return;
        }
      }
    }

    // no reason to stop
    _doSave(context);
  }

  void _doSave(BuildContext context) {
    final event = FlightBooking(
      widget.event.id,
      _pilotName,
      TZDateTime.from(_startDate, _appConfig.locationTimeZone),
      TZDateTime.from(_endDate, _appConfig.locationTimeZone),
      _notes,
    );

    final Future task = _service.bookingConflicts(_appConfig.googleCalendarId, event).then((conflict) {
      if (conflict) {
        throw Exception(AppLocalizations.of(context)!.bookFlightModal_error_timeConflict);
      }
      else {
        if (_isEditing) {
          return _service.updateBooking(_appConfig.googleCalendarId, event);
        }
        else {
          return _service.createBooking(_appConfig.googleCalendarId, event);
        }
      }
    });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(
        task.catchError((error, StackTrace stacktrace) {
          _log.warning('SAVE ERROR', error, stacktrace);
          // TODO analyze exception somehow (e.g. TimeoutException)
          WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
            _showError(getExceptionMessage(error));
          });
        }),
        message: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context).pop(value);
      }
    });
  }

  void _onDelete(BuildContext context) {
    if (!_appConfig.admin) {
      if (_appConfig.pilotName != widget.event.pilotName) {
        _showError(AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_delete);
        return;
      }
    }

    _showConfirm(
     text: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_message,
     title: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_title,
     okCallback: () => _doDelete(context),
     destructiveOk: true,
    );
  }

  void _doDelete(BuildContext context) {
    final Future task = _service.deleteBooking(_appConfig.googleCalendarId, widget.event);

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(
        task.catchError((error, StackTrace stacktrace) {
          _log.warning('DELETE ERROR', error, stacktrace);
          // TODO analyze exception somehow (e.g. TimeoutException)
          WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
            _showError(getExceptionMessage(error));
          });
        }),
        message: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context, rootNavigator: true).pop(value);
      }
    });
  }

  void _showError(String text) {
    showPlatformDialog(
      context: context,
      builder: (_context) => PlatformAlertDialog(
        title: Text(AppLocalizations.of(context)!.dialog_title_error),
        content: Text(text),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(_context);
            },
            child: Text(AppLocalizations.of(context)!.dialog_button_ok),
          ),
        ],
      ),
    );
  }

  void _showConfirm({
    required String text,
    required String title,
    required void Function() okCallback,
    bool destructiveOk = false
  }) {
    showPlatformDialog(
      context: context,
      builder: (_context) => PlatformAlertDialog(
        title: Text(title),
        content: Text(text),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () => Navigator.pop(_context),
            child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
          ),
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(_context);
              okCallback();
            },
            // TODO destructiveOk for material
            cupertino: (_, __) => CupertinoDialogActionData(isDestructiveAction: destructiveOk),
            child: Text(AppLocalizations.of(context)!.dialog_button_ok),
          ),
        ],
      ),
    );
  }

  // TODO use AppConfig state instance
  void _onTapPilot(BuildContext context, AppConfig appConfig) {
    final items = appConfig.pilotNames;
    if (isCupertino(context)) {
      showCupertinoModalPopup(
        context: context,
        semanticsDismissible: true,
        builder: (_context) => _PilotSelectList(
            pilotNames: items,
            selectedName: _pilotName,
            onSelection: (selected) {
              setState(() {
                _pilotName = selected;
              });
            }),
      );
    }
    else {
      showPlatformDialog(
        context: context,
        builder: (_context) => PlatformAlertDialog(
          title: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_selectPilot,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: _PilotSelectList(
              pilotNames: items,
              selectedName: _pilotName,
              onSelection: (selected) {
                setState(() {
                  _pilotName = selected;
                });
                Navigator.of(_context).pop();
              }
            ),
          ),
          material: (context, platform) => MaterialAlertDialogData(
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      );
    }
  }
}

/// TODO export this into a generic pilot selection popup widget (remember to handle the non-pilot too)
class _PilotSelectList extends StatefulWidget {
  final List<String> pilotNames;
  final String selectedName;
  final Function(String selected) onSelection;

  const _PilotSelectList({
    Key? key,
    required this.pilotNames,
    required this.selectedName,
    required this.onSelection
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PilotSelectListState();
}

class _PilotSelectListState extends State<_PilotSelectList> {

  late int _selectedIndex;
  late AppConfig _appConfig;

  @override
  void initState() {
    _selectedIndex = widget.pilotNames.indexOf(widget.selectedName);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.pilotNames.map((e) => Text(e)).toList(growable: false);
    if (isCupertino(context)) {
      // TODO round corners
      return Container(
          height: 250,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CupertinoPicker(
                    // TODO height?
                    itemExtent: 30,
                    backgroundColor: Colors.white70,
                    magnification: 1.1,
                    scrollController: FixedExtentScrollController(initialItem: _selectedIndex),
                    onSelectedItemChanged: (index) => _selectedIndex = index,
                    children: children,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: () {
                        widget.onSelection(widget.pilotNames[_selectedIndex]);
                        Navigator.of(context).pop();
                      },
                      child: Text(AppLocalizations.of(context)!.dialog_button_ok),
                    ),
                  ),
                ],
              ),
            ],
          )
      );
    }
    else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.pilotNames.map((e) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(backgroundImage: _appConfig.getPilotAvatar(e)),
          title: Text(e),
          onTap: () {
            _selectedIndex = widget.pilotNames.indexOf(e);
            widget.onSelection(e);
          },
        )).toList(growable: false),
      );
    }
  }

}

// FIXME refactor into widget + controller (e.g. like a text field)
class _DateTimeListTile extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final Function(DateTime? selected) onDateSelected;
  final Function(TimeOfDay? selected) onTimeSelected;
  final bool showIcon;

  const _DateTimeListTile({
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
              // TODO locale
              DateFormat('EEE, dd/MM/yyyy').format(selectedDate),
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
              // TODO locale
              DateFormat('HH:mm').format(selectedDate),
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

class _SunTimesListTile extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;

  const _SunTimesListTile({
    Key? key,
    required this.sunrise,
    required this.sunset,
  }) : super(key: key);

  Color? _getIconColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? null : Colors.black45;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 15),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.wb_sunny, color: _getIconColor(context)),
            const SizedBox(width: 10, height: 0),
            // TODO locale
            Text(DateFormat('HH:mm').format(sunrise), style: Theme.of(context).textTheme.subtitle1),
            SizedBox(width: MediaQuery.of(context).size.width * 0.2, height: 0),
            Icon(Icons.nightlight_round, color: _getIconColor(context)),
            const SizedBox(width: 10, height: 0),
            // TODO locale
            Text(DateFormat('HH:mm').format(sunset), style: Theme.of(context).textTheme.subtitle1),
          ],
        ),
      ),
    );
  }
}
