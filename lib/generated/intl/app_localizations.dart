import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'intl/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// The application name. Do not translate.
  ///
  /// In en, this message translates to:
  /// **'Airborne'**
  String get appName;

  /// No description provided for @dialog_button_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dialog_button_ok;

  /// No description provided for @dialog_button_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialog_button_cancel;

  /// No description provided for @dialog_button_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dialog_button_done;

  /// No description provided for @dialog_title_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get dialog_title_error;

  /// No description provided for @mainNav_bookFlight.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get mainNav_bookFlight;

  /// No description provided for @mainNav_logBook.
  ///
  /// In en, this message translates to:
  /// **'Log book'**
  String get mainNav_logBook;

  /// No description provided for @mainNav_activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get mainNav_activities;

  /// No description provided for @mainNav_about.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get mainNav_about;

  /// No description provided for @button_goToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get button_goToday;

  /// No description provided for @button_bookFlight.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get button_bookFlight;

  /// No description provided for @button_logFlight.
  ///
  /// In en, this message translates to:
  /// **'Log flight'**
  String get button_logFlight;

  /// No description provided for @button_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get button_error_retry;

  /// No description provided for @error_generic_network_timeout.
  ///
  /// In en, this message translates to:
  /// **'Server did not respond.'**
  String get error_generic_network_timeout;

  /// No description provided for @relativeDate_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {date}'**
  String relativeDate_yesterday(String date);

  /// No description provided for @relativeDate_today.
  ///
  /// In en, this message translates to:
  /// **'Today, {date}'**
  String relativeDate_today(String date);

  /// No description provided for @relativeDate_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {date}'**
  String relativeDate_tomorrow(String date);

  /// No description provided for @bookFlight_view_schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get bookFlight_view_schedule;

  /// No description provided for @bookFlight_view_month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get bookFlight_view_month;

  /// No description provided for @bookFlight_view_week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get bookFlight_view_week;

  /// No description provided for @bookFlight_view_day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get bookFlight_view_day;

  /// No description provided for @bookFlight_span_days.
  ///
  /// In en, this message translates to:
  /// **'Day {current} / {total}'**
  String bookFlight_span_days(int current, int total);

  /// No description provided for @bookFlight_message_flight_added.
  ///
  /// In en, this message translates to:
  /// **'Flight booked successfully.'**
  String get bookFlight_message_flight_added;

  /// No description provided for @bookFlight_message_flight_canceled.
  ///
  /// In en, this message translates to:
  /// **'Flight canceled successfully.'**
  String get bookFlight_message_flight_canceled;

  /// No description provided for @bookFlight_message_flight_updated.
  ///
  /// In en, this message translates to:
  /// **'Flight saved successfully.'**
  String get bookFlight_message_flight_updated;

  /// No description provided for @bookFlightModal_title_create.
  ///
  /// In en, this message translates to:
  /// **'Book flight'**
  String get bookFlightModal_title_create;

  /// No description provided for @bookFlightModal_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get bookFlightModal_title_edit;

  /// No description provided for @bookFlightModal_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bookFlightModal_button_save;

  /// No description provided for @bookFlightModal_button_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bookFlightModal_button_close;

  /// No description provided for @bookFlightModal_button_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bookFlightModal_button_delete;

  /// No description provided for @bookFlightModal_label_pilot.
  ///
  /// In en, this message translates to:
  /// **'Pilot'**
  String get bookFlightModal_label_pilot;

  /// No description provided for @bookFlightModal_label_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get bookFlightModal_label_start;

  /// No description provided for @bookFlightModal_label_end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get bookFlightModal_label_end;

  /// No description provided for @bookFlightModal_hint_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get bookFlightModal_hint_notes;

  /// No description provided for @bookFlightModal_error_notOwnBooking_edit.
  ///
  /// In en, this message translates to:
  /// **'Flight is not yours, you cannot modify it.'**
  String get bookFlightModal_error_notOwnBooking_edit;

  /// No description provided for @bookFlightModal_error_notOwnBooking_delete.
  ///
  /// In en, this message translates to:
  /// **'Flight is not yours, you cannot delete it.'**
  String get bookFlightModal_error_notOwnBooking_delete;

  /// No description provided for @bookFlightModal_error_bookingForOthers.
  ///
  /// In en, this message translates to:
  /// **'You can\'t book flight for another pilot.'**
  String get bookFlightModal_error_bookingForOthers;

  /// No description provided for @bookFlightModal_error_timeConflict.
  ///
  /// In en, this message translates to:
  /// **'Another flight is already booked for this time slot!'**
  String get bookFlightModal_error_timeConflict;

  /// No description provided for @bookFlightModal_dialog_changePilot_title.
  ///
  /// In en, this message translates to:
  /// **'Change pilot?'**
  String get bookFlightModal_dialog_changePilot_title;

  /// No description provided for @bookFlightModal_dialog_changePilot_message.
  ///
  /// In en, this message translates to:
  /// **'You are changing the pilot for this flight.'**
  String get bookFlightModal_dialog_changePilot_message;

  /// No description provided for @bookFlightModal_dialog_pastDateTime_title.
  ///
  /// In en, this message translates to:
  /// **'Past date/time!'**
  String get bookFlightModal_dialog_pastDateTime_title;

  /// No description provided for @bookFlightModal_dialog_pastDateTime_message.
  ///
  /// In en, this message translates to:
  /// **'You are booking a date or time in the past. Are you sure?'**
  String get bookFlightModal_dialog_pastDateTime_message;

  /// No description provided for @bookFlightModal_dialog_working.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get bookFlightModal_dialog_working;

  /// No description provided for @bookFlightModal_dialog_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get bookFlightModal_dialog_delete_title;

  /// No description provided for @bookFlightModal_dialog_delete_message.
  ///
  /// In en, this message translates to:
  /// **'Do not delete flights booked by others without the pilot knowing.'**
  String get bookFlightModal_dialog_delete_message;

  /// No description provided for @bookFlightModal_dialog_selectPilot.
  ///
  /// In en, this message translates to:
  /// **'Select pilot'**
  String get bookFlightModal_dialog_selectPilot;

  /// No description provided for @flightLog_title.
  ///
  /// In en, this message translates to:
  /// **'Log book'**
  String get flightLog_title;

  /// No description provided for @flightLog_message_flight_added.
  ///
  /// In en, this message translates to:
  /// **'Flight registered successfully.'**
  String get flightLog_message_flight_added;

  /// No description provided for @flightLog_message_flight_canceled.
  ///
  /// In en, this message translates to:
  /// **'Flight deleted successfully.'**
  String get flightLog_message_flight_canceled;

  /// No description provided for @flightLog_message_flight_updated.
  ///
  /// In en, this message translates to:
  /// **'Flight saved successfully.'**
  String get flightLog_message_flight_updated;

  /// No description provided for @flightLog_error_noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No registered flights.'**
  String get flightLog_error_noItemsFound;

  /// No description provided for @flightLog_error_firstPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get flightLog_error_firstPageIndicator;

  /// No description provided for @flightLog_error_newPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Tap to retry.'**
  String get flightLog_error_newPageIndicator;

  /// No description provided for @flightLogModal_title_create.
  ///
  /// In en, this message translates to:
  /// **'Log flight'**
  String get flightLogModal_title_create;

  /// No description provided for @flightLogModal_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit flight'**
  String get flightLogModal_title_edit;

  /// No description provided for @flightLogModal_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get flightLogModal_button_save;

  /// No description provided for @flightLogModal_button_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get flightLogModal_button_close;

  /// No description provided for @flightLogModal_button_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get flightLogModal_button_delete;

  /// No description provided for @flightLogModal_label_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get flightLogModal_label_date;

  /// No description provided for @flightLogModal_label_pilot.
  ///
  /// In en, this message translates to:
  /// **'Pilot'**
  String get flightLogModal_label_pilot;

  /// No description provided for @flightLogModal_label_startHour.
  ///
  /// In en, this message translates to:
  /// **'Hour meter start'**
  String get flightLogModal_label_startHour;

  /// No description provided for @flightLogModal_label_endHour.
  ///
  /// In en, this message translates to:
  /// **'Hour meter end'**
  String get flightLogModal_label_endHour;

  /// No description provided for @flightLogModal_label_origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get flightLogModal_label_origin;

  /// No description provided for @flightLogModal_label_destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get flightLogModal_label_destination;

  /// No description provided for @flightLogModal_label_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get flightLogModal_label_home;

  /// No description provided for @flightLogModal_label_fuel_material.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get flightLogModal_label_fuel_material;

  /// No description provided for @flightLogModal_hint_fuel_material.
  ///
  /// In en, this message translates to:
  /// **'liters'**
  String get flightLogModal_hint_fuel_material;

  /// No description provided for @flightLogModal_hint_fuel_price.
  ///
  /// In en, this message translates to:
  /// **'Fuel price'**
  String get flightLogModal_hint_fuel_price;

  /// No description provided for @flightLogModal_hint_fuel_cost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get flightLogModal_hint_fuel_cost;

  /// No description provided for @flightLogModal_label_fuel_cupertino.
  ///
  /// In en, this message translates to:
  /// **'Fuel (liters)'**
  String get flightLogModal_label_fuel_cupertino;

  /// No description provided for @flightLogModal_label_fuel_price_cupertino.
  ///
  /// In en, this message translates to:
  /// **'Fuel price'**
  String get flightLogModal_label_fuel_price_cupertino;

  /// No description provided for @flightLogModal_label_fuel_cost_cupertino.
  ///
  /// In en, this message translates to:
  /// **'Fuel cost ({currency})'**
  String flightLogModal_label_fuel_cost_cupertino(String currency);

  /// No description provided for @flightLogModal_label_fuel_myfuel.
  ///
  /// In en, this message translates to:
  /// **'My price'**
  String get flightLogModal_label_fuel_myfuel;

  /// No description provided for @flightLogModal_hint_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get flightLogModal_hint_notes;

  /// No description provided for @flightLogModal_text_totalFlightTime_simple.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Total flight time: 1 minute} other{Total flight time: {minutes} minutes}}'**
  String flightLogModal_text_totalFlightTime_simple(int minutes);

  /// No description provided for @flightLogModal_text_totalFlightTime_extended.
  ///
  /// In en, this message translates to:
  /// **'Total flight time: {minutes} minutes ({spec})'**
  String flightLogModal_text_totalFlightTime_extended(int minutes, String spec);

  /// No description provided for @flightLogModal_dialog_selectPilot.
  ///
  /// In en, this message translates to:
  /// **'Select pilot'**
  String get flightLogModal_dialog_selectPilot;

  /// No description provided for @flightLogModal_error_fuel_invalid_number.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get flightLogModal_error_fuel_invalid_number;

  /// No description provided for @flightLogModal_error_fuelCost_invalid_number.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get flightLogModal_error_fuelCost_invalid_number;

  /// No description provided for @flightLogModal_error_notOwnFlight_delete.
  ///
  /// In en, this message translates to:
  /// **'Flight is not yours, you cannot delete it.'**
  String get flightLogModal_error_notOwnFlight_delete;

  /// No description provided for @flightLogModal_error_invalid_hourmeter.
  ///
  /// In en, this message translates to:
  /// **'Invalid hour meter.'**
  String get flightLogModal_error_invalid_hourmeter;

  /// No description provided for @flightLogModal_error_invalid_locations.
  ///
  /// In en, this message translates to:
  /// **'Please provide origin and destination of flight.'**
  String get flightLogModal_error_invalid_locations;

  /// No description provided for @flightLogModal_error_invalid_fuel.
  ///
  /// In en, this message translates to:
  /// **'Invalid fuel quantity.'**
  String get flightLogModal_error_invalid_fuel;

  /// No description provided for @flightLogModal_error_invalid_fuel_empty.
  ///
  /// In en, this message translates to:
  /// **'Please provide fuel quantity.'**
  String get flightLogModal_error_invalid_fuel_empty;

  /// No description provided for @flightLogModal_error_invalid_fuelPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid fuel price.'**
  String get flightLogModal_error_invalid_fuelPrice;

  /// No description provided for @flightLogModal_error_invalid_fuelCost_empty.
  ///
  /// In en, this message translates to:
  /// **'Please provide total fuel cost.'**
  String get flightLogModal_error_invalid_fuelCost_empty;

  /// No description provided for @flightLogModal_error_invalid_fuelCost.
  ///
  /// In en, this message translates to:
  /// **'Invalid fuel cost.'**
  String get flightLogModal_error_invalid_fuelCost;

  /// No description provided for @flightLogModal_error_notOwnFlight_edit.
  ///
  /// In en, this message translates to:
  /// **'Flight is not yours, you cannot modify it.'**
  String get flightLogModal_error_notOwnFlight_edit;

  /// No description provided for @flightLogModal_error_alteringTestFlight.
  ///
  /// In en, this message translates to:
  /// **'This is a test flight, you cannot change the pilot.'**
  String get flightLogModal_error_alteringTestFlight;

  /// No description provided for @flightLogModal_error_dataChanged.
  ///
  /// In en, this message translates to:
  /// **'Someone else changed the flight log. Go back, refresh the log book and try again.'**
  String get flightLogModal_error_dataChanged;

  /// No description provided for @flightLogModal_dialog_changePilot_title.
  ///
  /// In en, this message translates to:
  /// **'Change pilot?'**
  String get flightLogModal_dialog_changePilot_title;

  /// No description provided for @flightLogModal_dialog_changePilot_message.
  ///
  /// In en, this message translates to:
  /// **'You are changing the pilot of a registered flight.'**
  String get flightLogModal_dialog_changePilot_message;

  /// No description provided for @flightLogModal_dialog_changePilotNoPilot_message.
  ///
  /// In en, this message translates to:
  /// **'You are turning this flight into a test flight.'**
  String get flightLogModal_dialog_changePilotNoPilot_message;

  /// No description provided for @flightLogModal_error_loggingForOthers.
  ///
  /// In en, this message translates to:
  /// **'You can\'t log flights for other pilots.'**
  String get flightLogModal_error_loggingForOthers;

  /// No description provided for @flightLogModal_dialog_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get flightLogModal_dialog_delete_title;

  /// No description provided for @flightLogModal_dialog_delete_message.
  ///
  /// In en, this message translates to:
  /// **'You are deleting a registered flight. You won\'t be able to undo this!'**
  String get flightLogModal_dialog_delete_message;

  /// No description provided for @flightLogModal_dialog_working.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get flightLogModal_dialog_working;

  /// No description provided for @activities_title.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities_title;

  /// No description provided for @activities_error_noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do!'**
  String get activities_error_noItemsFound;

  /// No description provided for @activities_error_firstPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get activities_error_firstPageIndicator;

  /// No description provided for @activities_error_newPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Tap to retry.'**
  String get activities_error_newPageIndicator;

  /// No description provided for @activities_activity_type_note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get activities_activity_type_note;

  /// No description provided for @activities_activity_type_minor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get activities_activity_type_minor;

  /// No description provided for @activities_activity_type_notice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get activities_activity_type_notice;

  /// No description provided for @activities_activity_type_important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get activities_activity_type_important;

  /// No description provided for @activities_activity_type_critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get activities_activity_type_critical;

  /// No description provided for @addAircraft_title.
  ///
  /// In en, this message translates to:
  /// **'Setup aircraft'**
  String get addAircraft_title;

  /// No description provided for @addAircraft_text1.
  ///
  /// In en, this message translates to:
  /// **'Please type in the address to the aircraft data and its password.'**
  String get addAircraft_text1;

  /// No description provided for @addAircraft_label_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addAircraft_label_address;

  /// No description provided for @addAircraft_hint_address.
  ///
  /// In en, this message translates to:
  /// **'Aircraft data address'**
  String get addAircraft_hint_address;

  /// No description provided for @addAircraft_hint_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get addAircraft_hint_password;

  /// No description provided for @addAircraft_button_install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get addAircraft_button_install;

  /// No description provided for @addAircraft_dialog_downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get addAircraft_dialog_downloading;

  /// No description provided for @addAircraft_error_invalid_address.
  ///
  /// In en, this message translates to:
  /// **'Please insert a valid address'**
  String get addAircraft_error_invalid_address;

  /// No description provided for @addAircraft_error_storing.
  ///
  /// In en, this message translates to:
  /// **'Unable to store aircraft data file.'**
  String get addAircraft_error_storing;

  /// No description provided for @addAircraft_error_bad_datafile_format.
  ///
  /// In en, this message translates to:
  /// **'Invalid data file, maybe wrong password?'**
  String get addAircraft_error_bad_datafile_format;

  /// No description provided for @addAircraft_error_invalid_datafile.
  ///
  /// In en, this message translates to:
  /// **'Not a valid aircraft data file.'**
  String get addAircraft_error_invalid_datafile;

  /// No description provided for @pilotSelect_title.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get pilotSelect_title;

  /// No description provided for @pilotSelect_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm?'**
  String get pilotSelect_confirm_title;

  /// No description provided for @pilotSelect_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'So you are **{name}**.'**
  String pilotSelect_confirm_message(String name);

  /// No description provided for @about_aircraft_info.
  ///
  /// In en, this message translates to:
  /// **'Aircraft'**
  String get about_aircraft_info;

  /// No description provided for @about_aircraft_callsign.
  ///
  /// In en, this message translates to:
  /// **'Call Sign'**
  String get about_aircraft_callsign;

  /// No description provided for @about_aircraft_hangar.
  ///
  /// In en, this message translates to:
  /// **'Hangar'**
  String get about_aircraft_hangar;

  /// No description provided for @about_aircraft_hangar_open_maps.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get about_aircraft_hangar_open_maps;

  /// No description provided for @about_aircraft_location_weather_live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get about_aircraft_location_weather_live;

  /// No description provided for @about_aircraft_location_weather_forecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get about_aircraft_location_weather_forecast;

  /// No description provided for @about_aircraft_documents_archive.
  ///
  /// In en, this message translates to:
  /// **'Documents archive'**
  String get about_aircraft_documents_archive;

  /// No description provided for @about_aircraft_documents_archive_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the documents archive of the aircraft'**
  String get about_aircraft_documents_archive_subtitle;

  /// No description provided for @about_aircraft_pilots.
  ///
  /// In en, this message translates to:
  /// **'Pilots'**
  String get about_aircraft_pilots;

  /// No description provided for @about_app_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get about_app_version;

  /// No description provided for @about_app_homepage.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get about_app_homepage;

  /// No description provided for @about_app_homepage_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Go to the app source code'**
  String get about_app_homepage_subtitle;

  /// No description provided for @about_app_issues.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get about_app_issues;

  /// No description provided for @about_app_issues_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a bug to report an issue with the app'**
  String get about_app_issues_subtitle;

  /// No description provided for @about_app_update_aircraft.
  ///
  /// In en, this message translates to:
  /// **'Update aircraft'**
  String get about_app_update_aircraft;

  /// No description provided for @about_app_update_aircraft_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Update aircraft data from network'**
  String get about_app_update_aircraft_subtitle;

  /// No description provided for @about_app_disconnect_aircraft.
  ///
  /// In en, this message translates to:
  /// **'Disconnect aircraft'**
  String get about_app_disconnect_aircraft;

  /// No description provided for @about_app_disconnect_aircraft_subtitle.
  ///
  /// In en, this message translates to:
  /// **'For switching to another aircraft or download aircraft data again'**
  String get about_app_disconnect_aircraft_subtitle;

  /// No description provided for @about_update_password_title.
  ///
  /// In en, this message translates to:
  /// **'Update aircraft'**
  String get about_update_password_title;

  /// No description provided for @about_update_password_message.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if a password is not needed.'**
  String get about_update_password_message;

  /// No description provided for @about_disconnect_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Disconnect aircraft?'**
  String get about_disconnect_confirm_title;

  /// No description provided for @about_disconnect_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'You will need to provide aircraft data address again.'**
  String get about_disconnect_confirm_message;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
