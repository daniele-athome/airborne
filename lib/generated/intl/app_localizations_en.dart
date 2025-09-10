// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Airborne';

  @override
  String get dialog_button_ok => 'OK';

  @override
  String get dialog_button_cancel => 'Cancel';

  @override
  String get dialog_button_done => 'Done';

  @override
  String get dialog_title_error => 'Error';

  @override
  String get mainNav_bookFlight => 'Bookings';

  @override
  String get mainNav_logBook => 'Log book';

  @override
  String get mainNav_activities => 'Activities';

  @override
  String get mainNav_about => 'Info';

  @override
  String get button_goToday => 'Today';

  @override
  String get button_bookFlight => 'Book';

  @override
  String get button_logFlight => 'Log flight';

  @override
  String get button_error_retry => 'Retry';

  @override
  String get error_generic_network_timeout => 'Server did not respond.';

  @override
  String relativeDate_yesterday(String date) {
    return 'Yesterday, $date';
  }

  @override
  String relativeDate_today(String date) {
    return 'Today, $date';
  }

  @override
  String relativeDate_tomorrow(String date) {
    return 'Tomorrow, $date';
  }

  @override
  String get bookFlight_view_schedule => 'Schedule';

  @override
  String get bookFlight_view_month => 'Month';

  @override
  String get bookFlight_view_week => 'Week';

  @override
  String get bookFlight_view_day => 'Day';

  @override
  String bookFlight_span_days(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Day $currentString / $totalString';
  }

  @override
  String get bookFlight_message_flight_added => 'Flight booked successfully.';

  @override
  String get bookFlight_message_flight_canceled =>
      'Flight canceled successfully.';

  @override
  String get bookFlight_message_flight_updated => 'Flight saved successfully.';

  @override
  String get bookFlightModal_title_create => 'Book flight';

  @override
  String get bookFlightModal_title_edit => 'Edit';

  @override
  String get bookFlightModal_button_save => 'Save';

  @override
  String get bookFlightModal_button_close => 'Close';

  @override
  String get bookFlightModal_button_delete => 'Delete';

  @override
  String get bookFlightModal_label_pilot => 'Pilot';

  @override
  String get bookFlightModal_label_start => 'Start';

  @override
  String get bookFlightModal_label_end => 'End';

  @override
  String get bookFlightModal_hint_notes => 'Notes';

  @override
  String get bookFlightModal_error_notOwnBooking_edit =>
      'Flight is not yours, you cannot modify it.';

  @override
  String get bookFlightModal_error_notOwnBooking_delete =>
      'Flight is not yours, you cannot delete it.';

  @override
  String get bookFlightModal_error_bookingForOthers =>
      'You can\'t book flight for another pilot.';

  @override
  String get bookFlightModal_error_timeConflict =>
      'Another flight is already booked for this time slot!';

  @override
  String get bookFlightModal_dialog_changePilot_title => 'Change pilot?';

  @override
  String get bookFlightModal_dialog_changePilot_message =>
      'You are changing the pilot for this flight.';

  @override
  String get bookFlightModal_dialog_pastDateTime_title => 'Past date/time!';

  @override
  String get bookFlightModal_dialog_pastDateTime_message =>
      'You are booking a date or time in the past. Are you sure?';

  @override
  String get bookFlightModal_dialog_working => 'Please wait...';

  @override
  String get bookFlightModal_dialog_delete_title => 'Delete?';

  @override
  String get bookFlightModal_dialog_delete_message =>
      'Do not delete flights booked by others without the pilot knowing.';

  @override
  String get bookFlightModal_dialog_selectPilot => 'Select pilot';

  @override
  String get flightLog_title => 'Log book';

  @override
  String get flightLog_message_flight_added =>
      'Flight registered successfully.';

  @override
  String get flightLog_message_flight_canceled =>
      'Flight deleted successfully.';

  @override
  String get flightLog_message_flight_updated => 'Flight saved successfully.';

  @override
  String get flightLog_error_noItemsFound => 'No registered flights.';

  @override
  String get flightLog_error_firstPageIndicator => 'Something went wrong.';

  @override
  String get flightLog_error_newPageIndicator =>
      'Something went wrong. Tap to retry.';

  @override
  String get flightLogModal_title_create => 'Log flight';

  @override
  String get flightLogModal_title_edit => 'Edit flight';

  @override
  String get flightLogModal_button_save => 'Save';

  @override
  String get flightLogModal_button_close => 'Close';

  @override
  String get flightLogModal_button_delete => 'Delete';

  @override
  String get flightLogModal_label_date => 'Date';

  @override
  String get flightLogModal_label_pilot => 'Pilot';

  @override
  String get flightLogModal_label_startHour => 'Hour meter start';

  @override
  String get flightLogModal_label_endHour => 'Hour meter end';

  @override
  String get flightLogModal_label_origin => 'Origin';

  @override
  String get flightLogModal_label_destination => 'Destination';

  @override
  String get flightLogModal_label_home => 'Home';

  @override
  String get flightLogModal_label_fuel_material => 'Fuel';

  @override
  String get flightLogModal_hint_fuel_material => 'liters';

  @override
  String get flightLogModal_hint_fuel_price => 'Fuel price';

  @override
  String get flightLogModal_hint_fuel_cost => 'Total cost';

  @override
  String get flightLogModal_label_fuel_cupertino => 'Fuel (liters)';

  @override
  String get flightLogModal_label_fuel_price_cupertino => 'Fuel price';

  @override
  String flightLogModal_label_fuel_cost_cupertino(String currency) {
    return 'Fuel cost ($currency)';
  }

  @override
  String get flightLogModal_label_fuel_myfuel => 'My price';

  @override
  String get flightLogModal_hint_notes => 'Notes';

  @override
  String flightLogModal_text_totalFlightTime_simple(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Total flight time: $minutes minutes',
      one: 'Total flight time: 1 minute',
    );
    return '$_temp0';
  }

  @override
  String flightLogModal_text_totalFlightTime_extended(
      int minutes, String spec) {
    return 'Total flight time: $minutes minutes ($spec)';
  }

  @override
  String get flightLogModal_dialog_selectPilot => 'Select pilot';

  @override
  String get flightLogModal_error_fuel_invalid_number => 'Invalid number';

  @override
  String get flightLogModal_error_fuelCost_invalid_number => 'Invalid number';

  @override
  String get flightLogModal_error_notOwnFlight_delete =>
      'Flight is not yours, you cannot delete it.';

  @override
  String get flightLogModal_error_invalid_hourmeter => 'Invalid hour meter.';

  @override
  String get flightLogModal_error_invalid_locations =>
      'Please provide origin and destination of flight.';

  @override
  String get flightLogModal_error_invalid_fuel => 'Invalid fuel quantity.';

  @override
  String get flightLogModal_error_invalid_fuel_empty =>
      'Please provide fuel quantity.';

  @override
  String get flightLogModal_error_invalid_fuelPrice => 'Invalid fuel price.';

  @override
  String get flightLogModal_error_invalid_fuelCost_empty =>
      'Please provide total fuel cost.';

  @override
  String get flightLogModal_error_invalid_fuelCost => 'Invalid fuel cost.';

  @override
  String get flightLogModal_error_notOwnFlight_edit =>
      'Flight is not yours, you cannot modify it.';

  @override
  String get flightLogModal_error_alteringTestFlight =>
      'This is a test flight, you cannot change the pilot.';

  @override
  String get flightLogModal_error_dataChanged =>
      'Someone else changed the flight log. Go back, refresh the log book and try again.';

  @override
  String get flightLogModal_dialog_changePilot_title => 'Change pilot?';

  @override
  String get flightLogModal_dialog_changePilot_message =>
      'You are changing the pilot of a registered flight.';

  @override
  String get flightLogModal_dialog_changePilotNoPilot_message =>
      'You are turning this flight into a test flight.';

  @override
  String get flightLogModal_error_loggingForOthers =>
      'You can\'t log flights for other pilots.';

  @override
  String get flightLogModal_dialog_delete_title => 'Delete?';

  @override
  String get flightLogModal_dialog_delete_message =>
      'You are deleting a registered flight. You won\'t be able to undo this!';

  @override
  String get flightLogModal_dialog_working => 'Please wait...';

  @override
  String get activities_title => 'Activities';

  @override
  String get activities_error_noItemsFound => 'Nothing to do!';

  @override
  String get activities_error_firstPageIndicator => 'Something went wrong.';

  @override
  String get activities_error_newPageIndicator =>
      'Something went wrong. Tap to retry.';

  @override
  String get activities_activity_type_note => 'Note';

  @override
  String get activities_activity_type_minor => 'Minor';

  @override
  String get activities_activity_type_notice => 'Notice';

  @override
  String get activities_activity_type_important => 'Important';

  @override
  String get activities_activity_type_critical => 'Critical';

  @override
  String get addAircraft_title => 'Setup aircraft';

  @override
  String get addAircraft_text1 =>
      'Please type in the address to the aircraft data and its password.';

  @override
  String get addAircraft_label_address => 'Address';

  @override
  String get addAircraft_hint_address => 'Aircraft data address';

  @override
  String get addAircraft_hint_password => 'Password';

  @override
  String get addAircraft_button_install => 'Install';

  @override
  String get addAircraft_dialog_downloading => 'Downloading...';

  @override
  String get addAircraft_error_invalid_address =>
      'Please insert a valid address';

  @override
  String get addAircraft_error_storing => 'Unable to store aircraft data file.';

  @override
  String get addAircraft_error_bad_datafile_format =>
      'Invalid data file, maybe wrong password?';

  @override
  String get addAircraft_error_invalid_datafile =>
      'Not a valid aircraft data file.';

  @override
  String get pilotSelect_title => 'Who are you?';

  @override
  String get pilotSelect_confirm_title => 'Confirm?';

  @override
  String pilotSelect_confirm_message(String name) {
    return 'So you are $name.';
  }

  @override
  String get about_aircraft_info => 'Aircraft';

  @override
  String get about_aircraft_callsign => 'Call Sign';

  @override
  String get about_aircraft_hangar => 'Hangar';

  @override
  String get about_aircraft_hangar_open_maps => 'Open in maps';

  @override
  String get about_aircraft_location_weather_live => 'Live';

  @override
  String get about_aircraft_location_weather_forecast => 'Forecast';

  @override
  String get about_aircraft_documents_archive => 'Documents archive';

  @override
  String get about_aircraft_documents_archive_subtitle =>
      'Open the documents archive of the aircraft';

  @override
  String get about_aircraft_pilots => 'Pilots';

  @override
  String get about_app_version => 'Version';

  @override
  String get about_app_homepage => 'Source code';

  @override
  String get about_app_homepage_subtitle => 'Go to the app source code';

  @override
  String get about_app_issues => 'Report issue';

  @override
  String get about_app_issues_subtitle =>
      'Open a bug to report an issue with the app';

  @override
  String get about_app_update_aircraft => 'Update aircraft';

  @override
  String get about_app_update_aircraft_subtitle =>
      'Update aircraft data from network';

  @override
  String get about_app_disconnect_aircraft => 'Disconnect aircraft';

  @override
  String get about_app_disconnect_aircraft_subtitle =>
      'For switching to another aircraft or download aircraft data again';

  @override
  String get about_update_password_title => 'Update aircraft';

  @override
  String get about_update_password_message =>
      'Leave empty if a password is not needed.';

  @override
  String get about_disconnect_confirm_title => 'Disconnect aircraft?';

  @override
  String get about_disconnect_confirm_message =>
      'You will need to provide aircraft data address again.';
}
