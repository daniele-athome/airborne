
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/future_progress_dialog.dart';
import '../../helpers/list_tiles.dart';
import '../../helpers/pilot_select_list.dart';
import '../../helpers/utils.dart';
import '../../models/book_flight_models.dart';
import '../../services/book_flight_services.dart';

final Logger _log = Logger((FlightBooking).toString());

class BookFlightModal extends StatefulWidget {

  const BookFlightModal(this.event, {
    Key? key
  }) : super(key: key);

  final FlightBooking event;

  @override
  State<BookFlightModal> createState() => _BookFlightModalState();

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
  void didChangeDependencies() {
    _service = Provider.of<BookFlightCalendarService>(context);
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    _updateEventData();
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
    _startDateController.value = widget.event.tzFrom(_appConfig.locationTimeZone);
    _startDate = widget.event.tzFrom(_appConfig.locationTimeZone);
    _endDate = widget.event.tzTo(_appConfig.locationTimeZone);
    _endDateController.value = widget.event.tzTo(_appConfig.locationTimeZone);
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
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return ListView(
      padding: kDefaultCupertinoFormMargin,
      children: [
        CupertinoFormSection(children: <Widget>[
          CupertinoFormButtonRow(
            onPressed: () => _onTapPilot(context),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(
              AppLocalizations.of(context)!.bookFlightModal_label_pilot,
              style: textStyle.copyWith(
                fontSize: 20,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _pilotName,
                  style: textStyle.copyWith(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 14),
                CircleAvatar(foregroundImage: appConfig.getPilotAvatar(_pilotName)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          // start date/time
          CupertinoDateTimeFormFieldRow(
            prefix: Text(AppLocalizations.of(context)!.bookFlightModal_label_start),
            helper: _SunTimesListTile(sunrise: startSunTimes.sunrise, sunset: startSunTimes.sunset),
            doneButtonText: AppLocalizations.of(context)!.dialog_button_done,
            onChanged: (value) => _onStartDateChanged(value, true),
            controller: _startDateController,
          ),
          // end date/time
          CupertinoDateTimeFormFieldRow(
            prefix: Text(AppLocalizations.of(context)!.bookFlightModal_label_end),
            helper: _SunTimesListTile(sunrise: endSunTimes.sunrise, sunset: endSunTimes.sunset),
            doneButtonText: AppLocalizations.of(context)!.dialog_button_done,
            onChanged: (value) => _onEndDateChanged(value, true),
            controller: _endDateController,
          ),
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
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 3,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            placeholder: AppLocalizations.of(context)!.bookFlightModal_hint_notes,
          ),
        ]),
        if (_isEditing) const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        if (_isEditing) CupertinoFormSection(children: <Widget>[
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: () => _onDelete(context),
                  child: Text(AppLocalizations.of(context)!.bookFlightModal_button_delete,
                    style: const TextStyle(color: CupertinoColors.destructiveRed),
                  ),
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
          leading: CircleAvatar(foregroundImage: appConfig.getPilotAvatar(_pilotName)),
          title: Text(
            _pilotName,
            style: const TextStyle(
              fontSize: 20,
            ),
          ),
          onTap: () => _onTapPilot(context),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // start date/time
        DateTimeListTile(
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
        DateTimeListTile(
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
            textCapitalization: TextCapitalization.sentences,
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
        key: const Key('button_bookFlightModal_close'),
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context)!.bookFlightModal_button_close),
      );
      trailingActions = [PlatformTextButton(
        widgetKey: const Key('button_bookFlightModal_save'),
        onPressed: () => _onSave(context),
        cupertino: (_, __) => CupertinoTextButtonData(
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
          widgetKey: const Key('button_bookFlightModal_save'),
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
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
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
          showError(context, AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_edit);
          return;
        }
      }
      else {
        if (_pilotName != widget.event.pilotName) {
          showConfirm(
            context: context,
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
          showError(context, AppLocalizations.of(context)!.bookFlightModal_error_bookingForOthers);
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
      TZDateTime.from(_startDate, _appConfig.locationTimeZone).toUtc(),
      TZDateTime.from(_endDate, _appConfig.locationTimeZone).toUtc(),
      _notes,
    );

    final Future<FlightBooking?> task = _service.bookingConflicts(event)
      .timeout(kNetworkRequestTimeout)
      .then((conflict) {
        if (conflict) {
          throw Exception(AppLocalizations.of(context)!.bookFlightModal_error_timeConflict);
        }
        else {
          return (_isEditing ? _service.updateBooking(event) :
              _service.createBooking(event))
            .timeout(kNetworkRequestTimeout);
        }
      })
      .then((value) => Future<FlightBooking?>.value(value))
      .catchError((error, StackTrace stacktrace) {
        _log.warning('SAVE ERROR', error, stacktrace);
        final String message;
        // TODO specialize exceptions (e.g. network errors, others...)
        if (error is TimeoutException) {
          message = AppLocalizations.of(context)!.error_generic_network_timeout;
        }
        else {
          message = getExceptionMessage(error);
        }
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          showError(context, message);
        });
        return null;
      });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(task,
        message: isCupertino(context) ? null :
          Text(AppLocalizations.of(context)!.bookFlightModal_dialog_working),
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
        showError(context, AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_delete);
        return;
      }
    }

    showConfirm(
      context: context,
      text: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_message,
      title: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_title,
      okCallback: () => _doDelete(context),
      destructiveOk: true,
    );
  }

  void _doDelete(BuildContext context) {
    final Future task = _service.deleteBooking(widget.event)
      .timeout(kNetworkRequestTimeout)
      .catchError((error, StackTrace stacktrace) {
        _log.warning('DELETE ERROR', error, stacktrace);
        final String message;
        // TODO specialize exceptions (e.g. network errors, others...)
        if (error is TimeoutException) {
          message = AppLocalizations.of(context)!.error_generic_network_timeout;
        }
        else {
          message = getExceptionMessage(error);
        }
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          showError(context, message);
        });
      });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(task,
        message: isCupertino(context) ? null :
          Text(AppLocalizations.of(context)!.bookFlightModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context, rootNavigator: true).pop(value);
      }
    });
  }

  void _onTapPilot(BuildContext context) {
    final Future<String?> dialog;
    final items = _appConfig.pilotNames;
    if (isCupertino(context)) {
      Widget pageRouteBuilder(BuildContext context) => PlatformScaffold(
        iosContentPadding: true,
        appBar: PlatformAppBar(
          title: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_selectPilot),
        ),
        cupertino: (context, platform) => CupertinoPageScaffoldData(
          backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
        ),
        body: PilotSelectList(
            pilotNames: items,
            selectedName: _pilotName,
            avatarProvider: (name) => _appConfig.getPilotAvatar(name),
            onSelection: (selected) {
              Navigator.of(context).pop(selected);
            }),
      );

      dialog = Navigator.of(context, rootNavigator: true)
          .push(CupertinoPageRoute(
        builder: pageRouteBuilder,
      ));
    }
    else {
      dialog = showPlatformDialog(
        context: context,
        builder: (dialogContext) => PlatformAlertDialog(
          title: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_selectPilot,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.minPositive,
            child: PilotSelectList(
                pilotNames: items,
                selectedName: _pilotName,
                avatarProvider: (name) => _appConfig.getPilotAvatar(name),
                onSelection: (selected) {
                  Navigator.of(dialogContext).pop(selected);
                }
            ),
          ),
          material: (context, platform) => MaterialAlertDialogData(
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      );
    }

    dialog.then((value) {
      if (value != null) {
        setState(() {
            _pilotName = value;
        });
      }
    });
  }
}

// TODO move to another file?
class _SunTimesListTile extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;

  const _SunTimesListTile({
    Key? key,
    required this.sunrise,
    required this.sunset,
  }) : super(key: key);

  Color? _getIconColor(BuildContext context) =>
      getBrightness(context) == Brightness.dark
      ? null
      : Colors.black45;

  @override
  Widget build(BuildContext context) {
    final textStyle = isCupertino(context) ?
      CupertinoTheme.of(context).textTheme.textStyle :
      Theme.of(context).textTheme.subtitle1;

    return Container(
      padding: isCupertino(context) ?
        const EdgeInsetsDirectional.fromSTEB(15, 2, 15, 10) :
        const EdgeInsets.symmetric(vertical: 2, horizontal: 15),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: isCupertino(context) ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Icon(Icons.wb_sunny, color: _getIconColor(context)),
            const SizedBox(width: 10, height: 0),
            Text(DateFormat(kAviationTimeFormat).format(sunrise), style: textStyle),
            SizedBox(width: MediaQuery.of(context).size.width * 0.2, height: 0),
            Icon(Icons.nightlight_round, color: _getIconColor(context)),
            const SizedBox(width: 10, height: 0),
            Text(DateFormat(kAviationTimeFormat).format(sunset), style: textStyle),
          ],
        ),
      ),
    );
  }
}
