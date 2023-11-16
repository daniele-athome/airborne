import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:material_segmented_control/material_segmented_control.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:timezone/timezone.dart';

import '../../helpers/config.dart';
import '../../helpers/utils.dart';
import '../../models/book_flight_models.dart';
import '../../services/book_flight_services.dart';
import 'book_flight_data.dart';
import 'book_flight_modal.dart';

final Logger _log = Logger((FlightBooking).toString());

// TODO find suitable colors (especially for light brightness)
const _kEventBackgroundColor = Colors.blue;
const _kEventBackgroundDarkColor = Colors.blue;

Color _resolveEventBackgroundColor(BuildContext context) =>
    getBrightness(context) == Brightness.dark
        ? _kEventBackgroundDarkColor
        : _kEventBackgroundColor;

const _kEventDefaultDuration = Duration(hours: 1);

class BookFlightScreen extends StatefulWidget {
  const BookFlightScreen({super.key});

  @override
  BookFlightScreenState createState() => BookFlightScreenState();
}

@visibleForTesting
class BookFlightScreenState extends State<BookFlightScreen> {
  final GlobalKey<ScaffoldMessengerState> _snackbarKey =
      GlobalKey<ScaffoldMessengerState>();

  /// When null, appName will be used.
  String? _appBarTitle;

  late FToast _fToast;
  late CalendarController _calendarController;
  late FlightBookingDataSource _dataSource;
  List<DateTime> _visibleDates = [];
  late AppConfig _appConfig;
  late BookFlightCalendarService _calendarService;

  static const List<CalendarView> _calendarViews = [
    CalendarView.schedule,
    CalendarView.month,
    CalendarView.week,
    CalendarView.day,
  ];

  CalendarController get calendarController => _calendarController;

  @override
  void initState() {
    _log.finest('INIT');
    _fToast = FToast();
    _fToast.init(context);
    _calendarController = CalendarController();
    _calendarController.view = CalendarView.schedule;
    _goToday();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    _calendarService =
        Provider.of<BookFlightCalendarService>(context, listen: false);
    _rebuildData();
    super.didChangeDependencies();
  }

  void _rebuildData() {
    _dataSource = FlightBookingDataSource(_calendarService, (error) {
      _log.warning('Error fetching data', error);
      final String message;
      // TODO specialize exceptions (e.g. network errors, others...)
      if (error is TimeoutException) {
        message = AppLocalizations.of(context)!.error_generic_network_timeout;
      } else {
        message = getExceptionMessage(error);
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _showError(message, null, _retryFetchData);
      });
    });
  }

  void _retryFetchData() {
    setState(() {
      _dataSource.dispose();
      _rebuildData();
    });
  }

  @override
  Widget build(BuildContext context) {
    _log.finest('BUILD');
    Widget? fab;
    Widget? leadingAction;
    Widget trailingAction;

    if (isCupertino(context)) {
      leadingAction = PlatformIconButton(
        onPressed: () => setState(() => _goToday()),
        icon: Icon(
          CupertinoIcons.calendar_today,
          semanticLabel: AppLocalizations.of(context)!.button_goToday,
        ),
        cupertino: (_, __) => CupertinoIconButtonData(
          // workaround for https://github.com/flutter/flutter/issues/32701
          padding: EdgeInsets.zero,
        ),
      );
      trailingAction = PlatformIconButton(
        key: const Key('button_bookFlight'),
        onPressed: () => _bookFlight(context, _appConfig, null),
        icon: Icon(
          CupertinoIcons.airplane,
          color: CupertinoColors.systemRed,
          semanticLabel: AppLocalizations.of(context)!.button_bookFlight,
        ),
        // TODO not ready yet
        //color: CupertinoColors.systemRed,
        cupertino: (_, __) => CupertinoIconButtonData(
          // workaround for https://github.com/flutter/flutter/issues/32701
          padding: EdgeInsets.zero,
        ),
      );
    } else {
      trailingAction = PlatformIconButton(
        onPressed: () => setState(() => _goToday()),
        icon: const Icon(Icons.calendar_today_sharp),
        material: (_, __) => MaterialIconButtonData(
          tooltip: AppLocalizations.of(context)!.button_goToday,
        ),
      );
      fab = FloatingActionButton(
        key: const Key('button_bookFlight'),
        onPressed: () => _bookFlight(context, _appConfig, null),
        tooltip: AppLocalizations.of(context)!.button_bookFlight,
        child: const Icon(Icons.airplanemode_active_sharp),
        // TODO colors
      );
    }

    final scaffold = PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(_appBarTitle ?? AppLocalizations.of(context)!.appName),
        leading: leadingAction,
        trailingActions: [
          trailingAction,
        ],
        material: (context, platform) => MaterialAppBarData(
          toolbarHeight:
              MediaQuery.of(context).orientation == Orientation.portrait
                  ? kPortraitToolbarHeight
                  : kLandscapeToolbarHeight,
        ),
      ),
      material: (_, __) => MaterialScaffoldData(
        floatingActionButton: fab,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 12,
          ),
          _buildViewSelector(context),
          const SizedBox(
            height: 12,
          ),
          Expanded(
            child: _buildCalendar(context, _appConfig),
          ),
        ],
      ),
    );

    return isCupertino(context)
        ? scaffold
        : ScaffoldMessenger(
            key: _snackbarKey,
            child: scaffold,
          );
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  void _setTitle() {
    if (_visibleDates.isEmpty) {
      _appBarTitle = null;
      return;
    }

    switch (_calendarController.view) {
      case CalendarView.schedule:
        _appBarTitle = null;
        break;
      case CalendarView.month:
        final mainDate = _visibleDates[_visibleDates.length ~/ 2];
        final year = mainDate.year;
        final month = mainDate.month;
        _appBarTitle = DateFormat.yMMMM().format(DateTime(year, month));
        break;
      case CalendarView.week:
        _appBarTitle =
            '${DateFormat.yMMMd().format(_visibleDates.reduce((a, b) => a.isBefore(b) ? a : b))} - ${DateFormat.yMMMd().format(_visibleDates.reduce((a, b) => a.isBefore(b) ? b : a))}';
        break;
      case CalendarView.day:
        _appBarTitle = DateFormat.yMMMMd().format(_visibleDates[0]);
        break;
      default:
        throw UnsupportedError('Unsupported calendar view');
    }
  }

  void _goToday() {
    final now = DateTime.now();
    _calendarController.selectedDate = now;
    _calendarController.displayDate = now;
  }

  void _changeView(int index) {
    _calendarController.view = _calendarViews[index];
    _setTitle();
  }

  void _goToEventDate(FlightBooking event) {
    // SfCalendar doesn't have timezone support so we need to help it
    var date = TZDateTime.from(event.from, _appConfig.locationTimeZone);
    switch (_calendarController.view) {
      case CalendarView.month:
        _calendarController.selectedDate = date;
        final mainDate = _visibleDates[_visibleDates.length ~/ 2];
        if (mainDate.year != date.year || mainDate.month != date.month) {
          _calendarController.displayDate = date;
        }
        break;
      case CalendarView.schedule:
        _calendarController.selectedDate = date;
        _calendarController.displayDate = date;
        break;
      case CalendarView.week:
      case CalendarView.day:
        // FIXME doesn't work...
        break;
      default:
        throw UnsupportedError('Unsupported calendar view');
    }
  }

  void _refresh(FlightBooking updatedEvent, bool newEvent) {
    setState(() {
      if (updatedEvent is DeletedFlightBooking) {
        _dataSource.deleteEvent(updatedEvent);
      } else {
        _dataSource.updateEvent(updatedEvent, newEvent);
        _goToEventDate(updatedEvent);
      }
      _setTitle();
    });
  }

  void _showError(String text, String? title, void Function() retryCallback) {
    if (isCupertino(context)) {
      showPlatformDialog(
        context: context,
        builder: (dialogContext) => PlatformAlertDialog(
          title:
              Text(title ?? AppLocalizations.of(context)!.dialog_title_error),
          content: Text(text),
          actions: <Widget>[
            PlatformDialogAction(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
            ),
            PlatformDialogAction(
              onPressed: () {
                Navigator.pop(dialogContext);
                retryCallback();
              },
              child: Text(AppLocalizations.of(context)!.button_error_retry),
            ),
          ],
        ),
      );
    } else {
      final snackBar = SnackBar(
        content: Text(text),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.button_error_retry,
          textColor: Colors.white,
          onPressed: () {
            _hideError();
            retryCallback();
          },
        ),
      );
      _snackbarKey.currentState!.showSnackBar(snackBar);
    }
  }

  void _hideError() {
    if (!isCupertino(context)) {
      // workaround for possible (?) SnackBar bug (DON'T use clearSnackBars)
      _snackbarKey.currentState!
          .removeCurrentSnackBar(reason: SnackBarClosedReason.action);
    }
  }

  void _changeVisibleDates(List<DateTime> visibleDates) {
    _visibleDates = visibleDates;
    _setTitle();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {});
    });
  }

  /// Only in month view: go to day view on selected date.
  /// Only in schedule view: go to month view for selected month.
  void _onLongPressCalendaer(BuildContext context, AppConfig appConfig,
      CalendarLongPressDetails calendarLongPressDetails) {
    if (calendarLongPressDetails.targetElement ==
            CalendarElement.calendarCell &&
        _calendarController.view == CalendarView.month) {
      setState(() {
        _calendarController.selectedDate = calendarLongPressDetails.date;
        _calendarController.displayDate = calendarLongPressDetails.date;
        _calendarController.view = CalendarView.day;
      });
    } else if (calendarLongPressDetails.targetElement ==
            CalendarElement.header &&
        _calendarController.view == CalendarView.schedule) {
      setState(() {
        _calendarController.selectedDate = calendarLongPressDetails.date;
        _calendarController.displayDate = calendarLongPressDetails.date;
        _calendarController.view = CalendarView.month;
      });
    }
  }

  void _onTapCalendar(BuildContext context, AppConfig appConfig,
      CalendarTapDetails calendarTapDetails) {
    if (calendarTapDetails.targetElement == CalendarElement.header ||
        calendarTapDetails.targetElement == CalendarElement.resourceHeader) {
      return;
    }

    if (calendarTapDetails.appointments != null &&
        calendarTapDetails.targetElement == CalendarElement.appointment) {
      final selectedAppointment =
          calendarTapDetails.appointments![0] as FlightBooking;
      _bookFlight(context, appConfig, selectedAppointment);
    } else if ((_calendarController.view == CalendarView.week ||
            _calendarController.view == CalendarView.day) &&
        calendarTapDetails.date != null &&
        calendarTapDetails.targetElement == CalendarElement.calendarCell) {
      // TODO look for conflicting events and fit the new event to avoid conflicts (before and after)
      final newAppointment = FlightBooking(
        null,
        appConfig.pilotName!,
        TZDateTime.from(calendarTapDetails.date!, appConfig.locationTimeZone),
        TZDateTime.from(calendarTapDetails.date!.add(const Duration(hours: 1)),
            appConfig.locationTimeZone),
        null,
      );
      _bookFlight(context, appConfig, newAppointment);
    }
  }

  void _bookFlight(
      BuildContext context, AppConfig appConfig, FlightBooking? event) {
    final FlightBooking model;
    if (event == null) {
      // start date is tomorrow 12:00
      DateTime now = DateTime.now();
      final date =
          TZDateTime(appConfig.locationTimeZone, now.year, now.month, now.day)
              .add(const Duration(days: 1, hours: 12));
      final dateFrom = date;
      final dateTo = date.add(_kEventDefaultDuration);

      model = FlightBooking(
        null,
        appConfig.pilotName!,
        dateFrom,
        dateTo,
        null,
      );
    } else {
      model = event;
    }

    Widget pageRouteBuilder(BuildContext context) => Provider.value(
          value: _calendarService,
          child: BookFlightModal(model),
        );

    final route = isCupertino(context)
        ? CupertinoPageRoute(
            builder: pageRouteBuilder,
            fullscreenDialog: true,
          )
        : MaterialPageRoute(
            builder: pageRouteBuilder,
            fullscreenDialog: true,
          );
    Navigator.of(context, rootNavigator: true).push(route).then((result) {
      if (result != null) {
        final String message;
        if (event == null) {
          message =
              AppLocalizations.of(context)!.bookFlight_message_flight_added;
        } else if (result is DeletedFlightBooking) {
          message =
              AppLocalizations.of(context)!.bookFlight_message_flight_canceled;
        } else {
          message =
              AppLocalizations.of(context)!.bookFlight_message_flight_updated;
        }
        showToast(_fToast, message, const Duration(seconds: 2));
        _refresh(result, event == null);
      }
    });
  }

  Map<int, Widget> _buildCalendarSwitches(BuildContext context) {
    final textStyle = !isCupertino(context)
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return {
      0: Text(AppLocalizations.of(context)!.bookFlight_view_schedule,
          key: const Key("button_bookFlight_view_schedule"), style: textStyle),
      1: Text(AppLocalizations.of(context)!.bookFlight_view_month,
          key: const Key("button_bookFlight_view_month"), style: textStyle),
      2: Text(AppLocalizations.of(context)!.bookFlight_view_week,
          key: const Key("button_bookFlight_view_week"), style: textStyle),
      3: Text(AppLocalizations.of(context)!.bookFlight_view_day,
          key: const Key("button_bookFlight_view_day"), style: textStyle),
    };
  }

  int get _currentCalendarSwitch =>
      _calendarViews.indexOf(_calendarController.view!);

  Widget _buildViewSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: isCupertino(context)
              ? CupertinoSegmentedControl<int>(
                  children: _buildCalendarSwitches(context),
                  groupValue: _currentCalendarSwitch,
                  onValueChanged: _changeView,
                )
              : MaterialSegmentedControl<int>(
                  children: _buildCalendarSwitches(context),
                  selectionIndex: _currentCalendarSwitch,
                  borderColor: Colors.grey,
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  unselectedColor: Theme.of(context).dialogBackgroundColor,
                  onSegmentTapped: _changeView,
                ),
        )
      ],
    );
  }

  Widget _scheduleViewBuilder(
      BuildContext buildContext, ScheduleViewMonthHeaderDetails details) {
    final dateStr = DateFormat.yMMMM().format(details.date);
    final text = dateStr[0].toUpperCase() + dateStr.substring(1);
    return Stack(
      children: <Widget>[
        Image(
            image: ExactAssetImage(
                'assets/images/month_${details.date.month}.png'),
            fit: BoxFit.cover,
            width: details.bounds.width,
            height: details.bounds.height),
        Positioned(
          left: 55,
          right: 0,
          top: 20,
          bottom: 0,
          child: Text(
            text,
            style: const TextStyle(fontSize: 20, color: Colors.white, shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(0, 0.1),
                blurRadius: 1.0,
              ),
              Shadow(
                color: Colors.black,
                offset: Offset(0.1, 0),
                blurRadius: 1.0,
              ),
              Shadow(
                color: Colors.black,
                offset: Offset(0, -0.1),
                blurRadius: 1.0,
              ),
              Shadow(
                color: Colors.black,
                offset: Offset(-0.1, 0),
                blurRadius: 1.0,
              ),
            ]),
          ),
        )
      ],
    );
  }

  // TODO test sizes on different resolutions and screen densities
  // TODO handle multiday events (especially in month view)
  Widget _appointmentBuilder(
      BuildContext context, CalendarAppointmentDetails details) {
    final event = details.appointments.first as FlightBooking;

    // event spanning multiple days
    final eventStartDate =
        DateTime(event.from.year, event.from.month, event.from.day);
    final eventEndDate = DateTime(event.to.year, event.to.month, event.to.day);
    final currentDate =
        DateTime(details.date.year, details.date.month, details.date.day);
    final multiDayEvent = eventEndDate.isAfter(currentDate) ||
        eventStartDate.isBefore(currentDate);
    int thisDay = 0;
    int spanDays = 0;
    if (multiDayEvent) {
      final DateTime today = (_calendarController.view == CalendarView.day ||
              _calendarController.view == CalendarView.week)
          ? _visibleDates.last
          : currentDate;
      thisDay = today.difference(eventStartDate).inDays + 1;
      spanDays = eventEndDate.difference(eventStartDate).inDays + 1;
    }
    String eventText = event.pilotName;
    if (multiDayEvent && _calendarController.view != CalendarView.week) {
      eventText +=
          ' (${AppLocalizations.of(context)!.bookFlight_span_days(thisDay, spanDays)})';
    }

    if (_calendarController.view == CalendarView.schedule ||
        _calendarController.view == CalendarView.month) {
      String timeText =
          '${DateFormat(kAviationTimeFormat).format(event.tzFrom(_appConfig.locationTimeZone))} -'
          ' ${DateFormat(kAviationTimeFormat).format(event.tzTo(_appConfig.locationTimeZone))}';
      if (event.notes != null) {
        timeText += ' (${event.notes})';
      }
      return DefaultTextStyle(
        style: const TextStyle(fontSize: 13),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // TODO boxShadow: [BoxShadow(color: Color(0x77000000), offset: Offset(3, 3), blurRadius: 2.0)],
            color: _resolveEventBackgroundColor(context),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                  foregroundImage: _appConfig.getPilotAvatar(event.pilotName)),
              const SizedBox(width: 6),
              // the Flexible is to make the ellipsis work
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(eventText),
                    Text(
                      timeText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (multiDayEvent && thisDay < spanDays)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('»', style: TextStyle(fontSize: 26)),
                )
            ],
          ),
        ),
      );
    } else {
      if (multiDayEvent) {
        // this should span in the hour view, but I don't think it's supported by SfCalendar
        return DefaultTextStyle(
            style: const TextStyle(fontSize: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _resolveEventBackgroundColor(context),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: [
                  Expanded(child: Text(eventText)),
                  if (thisDay < spanDays)
                    const Text(
                      '»',
                      // FIXME not sure using height is the right way to do this
                      style: TextStyle(fontSize: 18, height: 0.9),
                    )
                ],
              ),
            ));
      }

      return DefaultTextStyle(
        style: const TextStyle(fontSize: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: _resolveEventBackgroundColor(context),
          ),
          padding: _calendarController.view == CalendarView.day
              ? const EdgeInsets.symmetric(vertical: 4, horizontal: 6)
              : const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eventText),
                    if (_calendarController.view == CalendarView.day &&
                        event.notes != null &&
                        event.notes!.isNotEmpty)
                      Text(event.notes!, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (_calendarController.view == CalendarView.day)
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                        '${DateFormat(kAviationTimeFormat).format(event.tzFrom(_appConfig.locationTimeZone))} - ${DateFormat(kAviationTimeFormat).format(event.tzTo(_appConfig.locationTimeZone))}',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCalendar(BuildContext context, AppConfig appConfig) {
    final firstDayOfWeekIndex =
        MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return Theme(
      data: getBrightness(context) == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      child: SfCalendar(
        key: ValueKey(_dataSource),
        controller: _calendarController,
        appointmentTimeTextFormat: kAviationTimeFormat,
        firstDayOfWeek: firstDayOfWeekIndex == 0 ? 7 : firstDayOfWeekIndex,
        headerHeight: 0,
        showNavigationArrow: false,
        showDatePickerButton: false,
        showCurrentTimeIndicator: true,
        appointmentBuilder: _appointmentBuilder,
        timeZone: appConfig.locationTimeZone.name,
        monthViewSettings: const MonthViewSettings(
          agendaItemHeight: 50,
          showAgenda: true,
        ),
        timeSlotViewSettings: const TimeSlotViewSettings(
          timeFormat: kAviationHourFormat,
          startHour: 5,
          endHour: 22,
        ),
        scheduleViewMonthHeaderBuilder: _scheduleViewBuilder,
        scheduleViewSettings: const ScheduleViewSettings(
          appointmentItemHeight: 50,
        ),
        // TODO other configurations (e.g. time of day range)
        dataSource: _dataSource,
        loadMoreWidgetBuilder:
            (BuildContext context, LoadMoreCallback loadMoreEvents) {
          return FutureBuilder<void>(
            future: loadMoreEvents(),
            builder: (context, snapShot) {
              if (snapShot.connectionState == ConnectionState.waiting) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  _hideError();
                });
              }
              return Container(
                height: double.infinity,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                alignment: _calendarController.view ==
                        // ugly trick to get alignment decided by SfCalendar. Don't do this at home!!
                        CalendarView.schedule
                    ? context
                        .findAncestorWidgetOfExactType<Container>()!
                        .alignment
                    : Alignment.center,
                color: getModalBarrierColor(context),
                child: isCupertino(context)
                    ? const CupertinoActivityIndicator(
                        radius: 20,
                      )
                    : const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.blue)),
              );
            },
          );
        },
        onTap: (calendarTapDetails) =>
            _onTapCalendar(context, appConfig, calendarTapDetails),
        onLongPress: (calendarLongPressDetails) =>
            _onLongPressCalendaer(context, appConfig, calendarLongPressDetails),
        onViewChanged: (ViewChangedDetails details) {
          _changeVisibleDates(details.visibleDates);
        },
      ),
    );
  }
}
