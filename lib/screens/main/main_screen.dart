import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

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
  final GoogleServiceAccountService? googleServiceAccountService;
  final BookFlightCalendarService? bookFlightCalendarService;
  final FlightLogBookService? flightLogBookService;
  final ActivitiesService? activitiesService;
  final MetadataService? metadataService;

  const MainNavigation(this.appConfig, {super.key})
      : googleServiceAccountService = null,
        bookFlightCalendarService = null,
        flightLogBookService = null,
        activitiesService = null,
        metadataService = null;

  /// Mainly for integration testing.
  @Deprecated('Use dependency injection')
  @visibleForTesting
  const MainNavigation.withServices(
    this.appConfig, {
    super.key,
    this.googleServiceAccountService,
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

  @override
  void initState() {
    _tabController = PlatformTabController();
    widget.appConfig.addListener(_resetTabController);
    super.initState();
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
    return [
      if (widget.appConfig.hasFeature('book_flight'))
        () => const BookFlightScreen(),
      if (widget.appConfig.hasFeature('flight_log'))
        () => const FlightLogScreen(),
      if (widget.appConfig.hasFeature('activities'))
        () => const ActivitiesScreen(),
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
