import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import '../../generated/intl/app_localizations.dart';
import '../../helpers/config.dart';
import '../../helpers/googleapis.dart';
import '../../helpers/utils.dart';
import '../../services/activities_services.dart';
import '../../services/book_flight_services.dart';
import '../../services/flight_log_services.dart';
import '../../services/metadata_services.dart';
import '../about/about_screen.dart';
import '../activities/activities_screen.dart';
import '../book_flight/book_flight_screen.dart';
import '../flight_log/flight_log_screen.dart';

class MainNavigation extends StatefulWidget {
  final AppConfig appConfig;

  // FIXME these should be provided via dependency injection and not built/given here
  final BookFlightCalendarService? bookFlightCalendarService;
  final FlightLogBookService? flightLogBookService;
  final ActivitiesService? activitiesService;
  final MetadataService? metadataService;

  // TODO other services one day...

  const MainNavigation(this.appConfig, {super.key})
      : bookFlightCalendarService = null,
        flightLogBookService = null,
        activitiesService = null,
        metadataService = null;

  /// Mainly for integration testing.
  @visibleForTesting
  const MainNavigation.withServices(
    this.appConfig, {
    super.key,
    this.bookFlightCalendarService,
    this.flightLogBookService,
    this.activitiesService,
    this.metadataService,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late PlatformTabController _tabController;
  late BookFlightCalendarService? _bookFlightCalendarService;
  late FlightLogBookService? _flightLogBookService;
  late ActivitiesService? _activitiesService;

  @override
  void initState() {
    _tabController = PlatformTabController();
    widget.appConfig.addListener(_resetTabController);
    _rebuildServices();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    _rebuildServices();
    super.didUpdateWidget(oldWidget);
  }

  void _rebuildServices() {
    // FIXME if the services are already built (or provided) these variables are not used
    final account = GoogleServiceAccountService(
        json: widget.appConfig.googleServiceAccountJson);
    final metadataService = widget.metadataService ??
        (widget.appConfig.hasFeature('metadata')
            ? MetadataService(account, widget.appConfig.metadataBackendInfo)
            : null);

    _bookFlightCalendarService = widget.bookFlightCalendarService ??
        (widget.appConfig.hasFeature('book_flight')
            ? BookFlightCalendarService(
                account, widget.appConfig.googleCalendarId)
            : null);
    _flightLogBookService = widget.flightLogBookService ??
        (widget.appConfig.hasFeature('flight_log')
            ? FlightLogBookService(
                account, metadataService, widget.appConfig.flightlogBackendInfo)
            : null);
    _activitiesService = widget.activitiesService ??
        (widget.appConfig.hasFeature('activities')
            ? ActivitiesService(account, metadataService,
                widget.appConfig.activitiesBackendInfo)
            : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _resetTabController() {
    if (mounted) {
      _tabController.setIndex(context, 0);
    }
  }

  @override
  void dispose() {
    widget.appConfig.removeListener(_resetTabController);
    super.dispose();
  }

  Widget _buildTab(BuildContext context, int index) {
    // FIXME find a more efficient way to do this
    return [
      if (widget.appConfig.hasFeature('book_flight'))
        () => Provider.value(
              value: _bookFlightCalendarService,
              child: const BookFlightScreen(),
            ),
      if (widget.appConfig.hasFeature('flight_log'))
        () => Provider.value(
              value: _flightLogBookService,
              child: const FlightLogScreen(),
            ),
      if (widget.appConfig.hasFeature('activities'))
        () => Provider.value(
              value: _activitiesService,
              child: const ActivitiesScreen(),
            ),
      () => const AboutScreen(),
    ][index]();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      if (widget.appConfig.hasFeature('book_flight'))
        BottomNavigationBarItem(
          icon: Icon(
            isCupertino(context)
                ? CupertinoIcons.calendar
                : Icons.calendar_today_rounded,
            key: const Key('nav_book_flight'),
          ),
          backgroundColor: getBrightness(context) == Brightness.dark
              ? Colors.tealAccent
              : Colors.deepOrange,
          label: AppLocalizations.of(context)!.mainNav_bookFlight,
          tooltip: '',
        ),
      if (widget.appConfig.hasFeature('flight_log'))
        BottomNavigationBarItem(
          icon: Icon(
            isCupertino(context)
                ? CupertinoIcons.book_solid
                : Icons.menu_book_sharp,
            key: const Key('nav_flight_log'),
          ),
          backgroundColor: getBrightness(context) == Brightness.dark
              ? const Color(0xffffff00)
              : Colors.green.shade500,
          label: AppLocalizations.of(context)!.mainNav_logBook,
          tooltip: '',
        ),
      if (widget.appConfig.hasFeature('activities'))
        BottomNavigationBarItem(
          icon: Icon(
            PlatformIcons(context).flag,
            key: const Key('nav_activities'),
          ),
          backgroundColor: getBrightness(context) == Brightness.dark
              ? Colors.white
              : Colors.amber.shade700,
          label: AppLocalizations.of(context)!.mainNav_activities,
          tooltip: '',
        ),
      BottomNavigationBarItem(
        icon: Icon(
          PlatformIcons(context).info,
          key: const Key('nav_info'),
        ),
        backgroundColor: getBrightness(context) == Brightness.dark
            ? const Color(0xff40c4ff)
            : Colors.deepPurple,
        label: AppLocalizations.of(context)!.mainNav_about,
        tooltip: '',
      ),
    ];

    if (items.length >= 2) {
      return PlatformTabScaffold(
        iosContentBottomPadding: true,
        // appBar is owned by screen
        bodyBuilder: (context, index) => _buildTab(context, index),
        tabController: _tabController,
        items: items,
        materialTabs: (_, __) => MaterialNavBarData(
          type: BottomNavigationBarType.fixed,
        ),
        material: (_, __) => MaterialTabScaffoldData(
            // TODO
            ),
        cupertino: (_, __) => CupertinoTabScaffoldData(
            // TODO
            ),
      );
    } else {
      return PlatformScaffold(
        body: const AboutScreen(),
      );
    }
  }
}
