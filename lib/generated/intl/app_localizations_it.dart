// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Airborne';

  @override
  String get dialog_button_ok => 'OK';

  @override
  String get dialog_button_cancel => 'Annulla';

  @override
  String get dialog_button_done => 'Chiudi';

  @override
  String get dialog_title_error => 'Errore';

  @override
  String get mainNav_bookFlight => 'Prenota';

  @override
  String get mainNav_logBook => 'Log book';

  @override
  String get mainNav_activities => 'Attività';

  @override
  String get mainNav_about => 'Info';

  @override
  String get button_goToday => 'Oggi';

  @override
  String get button_bookFlight => 'Prenota';

  @override
  String get button_logFlight => 'Registra volo';

  @override
  String get button_error_retry => 'Riprova';

  @override
  String get error_generic_network_timeout => 'Il server non risponde.';

  @override
  String relativeDate_yesterday(String date) {
    return 'Ieri, $date';
  }

  @override
  String relativeDate_today(String date) {
    return 'Oggi, $date';
  }

  @override
  String relativeDate_tomorrow(String date) {
    return 'Domani, $date';
  }

  @override
  String get bookFlight_view_schedule => 'Agenda';

  @override
  String get bookFlight_view_month => 'Mese';

  @override
  String get bookFlight_view_week => 'Settimana';

  @override
  String get bookFlight_view_day => 'Giorno';

  @override
  String bookFlight_span_days(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Giorno $currentString / $totalString';
  }

  @override
  String get bookFlight_message_flight_added => 'Prenotazione effettuata.';

  @override
  String get bookFlight_message_flight_canceled => 'Prenotazione cancellata.';

  @override
  String get bookFlight_message_flight_updated => 'Prenotazione modificata.';

  @override
  String get bookFlightModal_title_create => 'Prenota';

  @override
  String get bookFlightModal_title_edit => 'Modifica';

  @override
  String get bookFlightModal_button_save => 'Salva';

  @override
  String get bookFlightModal_button_close => 'Chiudi';

  @override
  String get bookFlightModal_button_delete => 'Elimina';

  @override
  String get bookFlightModal_label_pilot => 'Pilota';

  @override
  String get bookFlightModal_label_start => 'Inizio';

  @override
  String get bookFlightModal_label_end => 'Fine';

  @override
  String get bookFlightModal_hint_notes => 'Note';

  @override
  String get bookFlightModal_error_notOwnBooking_edit =>
      'La prenotazione non è tua, non puoi modificarla.';

  @override
  String get bookFlightModal_error_notOwnBooking_delete =>
      'La prenotazione non è tua, non puoi cancellarla.';

  @override
  String get bookFlightModal_error_bookingForOthers =>
      'Non puoi prenotare voli per un altro pilota.';

  @override
  String get bookFlightModal_error_timeConflict =>
      'Un\'altra prenotazione è già presente per l\'orario indicato!';

  @override
  String get bookFlightModal_dialog_changePilot_title => 'Cambiare pilota?';

  @override
  String get bookFlightModal_dialog_changePilot_message =>
      'Stai cambiando il pilota di una prenotazione.';

  @override
  String get bookFlightModal_dialog_pastDateTime_title => 'Data/ora passate!';

  @override
  String get bookFlightModal_dialog_pastDateTime_message =>
      'Stai prenotando un volo nel passato. Sei sicuro?';

  @override
  String get bookFlightModal_dialog_working => 'Un attimo...';

  @override
  String get bookFlightModal_dialog_delete_title => 'Cancellare?';

  @override
  String get bookFlightModal_dialog_delete_message =>
      'Non cancellare prenotazioni altrui senza il consenso del pilota.';

  @override
  String get bookFlightModal_dialog_selectPilot => 'Seleziona pilota';

  @override
  String get flightLog_title => 'Log book';

  @override
  String get flightLog_message_flight_added => 'Volo registrato.';

  @override
  String get flightLog_message_flight_canceled => 'Volo cancellato.';

  @override
  String get flightLog_message_flight_updated => 'Volo modificato.';

  @override
  String get flightLog_error_noItemsFound => 'Nessun volo registrato.';

  @override
  String get flightLog_error_firstPageIndicator => 'Qualcosa è andato storto.';

  @override
  String get flightLog_error_newPageIndicator =>
      'Qualcosa è andato storto. Tocca per riprovare.';

  @override
  String get flightLogModal_title_create => 'Registra';

  @override
  String get flightLogModal_title_edit => 'Modifica';

  @override
  String get flightLogModal_button_save => 'Salva';

  @override
  String get flightLogModal_button_close => 'Chiudi';

  @override
  String get flightLogModal_button_delete => 'Elimina';

  @override
  String get flightLogModal_label_date => 'Data';

  @override
  String get flightLogModal_label_pilot => 'Pilota';

  @override
  String get flightLogModal_label_startHour => 'Orametro inizio';

  @override
  String get flightLogModal_label_endHour => 'Orametro fine';

  @override
  String get flightLogModal_label_origin => 'Partenza';

  @override
  String get flightLogModal_label_destination => 'Arrivo';

  @override
  String get flightLogModal_label_home => 'Casa';

  @override
  String get flightLogModal_label_fuel_material => 'Benzina';

  @override
  String get flightLogModal_hint_fuel_material => 'litri';

  @override
  String get flightLogModal_hint_fuel_price => 'Prezzo benzina';

  @override
  String get flightLogModal_hint_fuel_cost => 'Costo totale';

  @override
  String get flightLogModal_label_fuel_cupertino => 'Benzina (litri)';

  @override
  String get flightLogModal_label_fuel_price_cupertino => 'Prezzo benzina';

  @override
  String flightLogModal_label_fuel_cost_cupertino(String currency) {
    return 'Costo benzina ($currency)';
  }

  @override
  String get flightLogModal_label_fuel_myfuel => 'Il mio prezzo';

  @override
  String get flightLogModal_hint_notes => 'Note';

  @override
  String flightLogModal_text_totalFlightTime_simple(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Tempo di volo: $minutes minuti',
      one: 'Tempo di volo: 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String flightLogModal_text_totalFlightTime_extended(
      int minutes, String spec) {
    return 'Tempo di volo: $minutes minuti ($spec)';
  }

  @override
  String get flightLogModal_dialog_selectPilot => 'Seleziona pilota';

  @override
  String get flightLogModal_error_fuel_invalid_number => 'Numero non valido';

  @override
  String get flightLogModal_error_fuelCost_invalid_number =>
      'Numero non valido';

  @override
  String get flightLogModal_error_notOwnFlight_delete =>
      'Il volo non è tuo, non puoi cancellarlo.';

  @override
  String get flightLogModal_error_invalid_hourmeter => 'Orametro non valido.';

  @override
  String get flightLogModal_error_invalid_locations =>
      'Inserisci partenza e arrivo del volo.';

  @override
  String get flightLogModal_error_invalid_fuel =>
      'Quantità di benzina non valida.';

  @override
  String get flightLogModal_error_invalid_fuel_empty =>
      'Inserisci la quantità di benzina.';

  @override
  String get flightLogModal_error_invalid_fuelPrice =>
      'Prezzo benzina non valido.';

  @override
  String get flightLogModal_error_invalid_fuelCost_empty =>
      'Inserisci il costo totale della benzina.';

  @override
  String get flightLogModal_error_invalid_fuelCost =>
      'Costo totale benzina non valido.';

  @override
  String get flightLogModal_error_notOwnFlight_edit =>
      'Il volo non è tuo, non puoi modificarlo.';

  @override
  String get flightLogModal_error_alteringTestFlight =>
      'Il volo è una prova tecnica, non puoi cambiare pilota.';

  @override
  String get flightLogModal_error_dataChanged =>
      'Qualcun altro ha cambiato il log book. Torna indietro, ricarica il log book e riprova.';

  @override
  String get flightLogModal_dialog_changePilot_title => 'Cambiare pilota?';

  @override
  String get flightLogModal_dialog_changePilot_message =>
      'Stai cambiando il pilota di un volo registrato.';

  @override
  String get flightLogModal_dialog_changePilotNoPilot_message =>
      'Stai trasformando il volo in una prova tecnica.';

  @override
  String get flightLogModal_error_loggingForOthers =>
      'Non puoi registrare voli di un altro pilota.';

  @override
  String get flightLogModal_dialog_delete_title => 'Cancellare?';

  @override
  String get flightLogModal_dialog_delete_message =>
      'Stai cancellando un volo registrato. Non potrai recuperarlo!';

  @override
  String get flightLogModal_dialog_working => 'Un attimo...';

  @override
  String get activities_title => 'Attività';

  @override
  String get activities_error_noItemsFound => 'Nulla da segnalare!';

  @override
  String get activities_error_firstPageIndicator => 'Qualcosa è andato storto.';

  @override
  String get activities_error_newPageIndicator =>
      'Qualcosa è andato storto. Tocca per riprovare.';

  @override
  String get activities_activity_type_note => 'Nota';

  @override
  String get activities_activity_type_minor => 'Minore';

  @override
  String get activities_activity_type_notice => 'Avviso';

  @override
  String get activities_activity_type_important => 'Importante';

  @override
  String get activities_activity_type_critical => 'Critico';

  @override
  String get addAircraft_title => 'Configura aereo';

  @override
  String get addAircraft_text1 =>
      'Inserisci l\'indirizzo della configurazione dell\'aereo e la sua password.';

  @override
  String get addAircraft_label_address => 'Indirizzo';

  @override
  String get addAircraft_hint_address => 'Indirizzo aereo';

  @override
  String get addAircraft_hint_password => 'Password';

  @override
  String get addAircraft_button_install => 'Installa';

  @override
  String get addAircraft_dialog_downloading => 'Download in corso...';

  @override
  String get addAircraft_error_invalid_address =>
      'Inserisci un indirizzo valido';

  @override
  String get addAircraft_error_storing =>
      'Errore durante l\'installazione dell\'aereo.';

  @override
  String get addAircraft_error_bad_datafile_format =>
      'File non valido, forse password errata?';

  @override
  String get addAircraft_error_invalid_datafile =>
      'Configurazione dell\'aereo non valida.';

  @override
  String get pilotSelect_title => 'Chi sei?';

  @override
  String get pilotSelect_confirm_title => 'Confermi?';

  @override
  String pilotSelect_confirm_message(String name) {
    return 'Dici di essere $name.';
  }

  @override
  String get about_aircraft_info => 'Aeromobile';

  @override
  String get about_aircraft_callsign => 'Marche';

  @override
  String get about_aircraft_hangar => 'Hangar';

  @override
  String get about_aircraft_hangar_open_maps => 'Apri in mappe';

  @override
  String get about_aircraft_location_weather_live => 'Meteo live';

  @override
  String get about_aircraft_location_weather_forecast => 'Previsioni';

  @override
  String get about_aircraft_documents_archive => 'Archivio documenti';

  @override
  String get about_aircraft_documents_archive_subtitle =>
      'Apri l\'archivio dei documenti dell\'aereo';

  @override
  String get about_aircraft_pilots => 'Piloti';

  @override
  String get about_app_version => 'Versione';

  @override
  String get about_app_homepage => 'Codice sorgente';

  @override
  String get about_app_homepage_subtitle => 'Vai al codice sorgente dell\'app';

  @override
  String get about_app_issues => 'Segnala problema';

  @override
  String get about_app_issues_subtitle =>
      'Apri un bug per segnalare un problema con l\'app';

  @override
  String get about_app_update_aircraft => 'Aggiorna aereo';

  @override
  String get about_app_update_aircraft_subtitle =>
      'Aggiorna i dati dell\'aereo dalla rete';

  @override
  String get about_app_disconnect_aircraft => 'Disconnetti aereo';

  @override
  String get about_app_disconnect_aircraft_subtitle =>
      'Per cambiare aereo e riscaricare i dati';

  @override
  String get about_update_password_title => 'Aggiorna aereo';

  @override
  String get about_update_password_message =>
      'Lascia vuota la password se non serve.';

  @override
  String get about_disconnect_confirm_title => 'Disconnettere l\'aereo?';

  @override
  String get about_disconnect_confirm_message =>
      'Dovrai immettere di nuovo l\'indirizzo dei dati dell\'aereo.';
}
