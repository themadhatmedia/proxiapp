import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// US English date/time formatting (MM/DD/YYYY) for display and pickers.
class UsDateFormat {
  UsDateFormat._();

  static const Locale locale = Locale('en', 'US');

  static final DateFormat shortDate = DateFormat('MM/dd/yyyy', 'en_US');
  static final DateFormat mediumDate = DateFormat('MMM d, yyyy', 'en_US');
  static final DateFormat longDate = DateFormat('MMMM d, yyyy', 'en_US');
  static final DateFormat dateTime = DateFormat('MMM d, yyyy h:mm a', 'en_US');

  static String formatShortDate(DateTime date) => shortDate.format(date.toLocal());

  static String formatMediumDate(DateTime date) => mediumDate.format(date.toLocal());

  static String formatLongDate(DateTime date) => longDate.format(date.toLocal());

  static String formatDateTime(DateTime date) => dateTime.format(date.toLocal());

  /// Material date picker with US locale (month/day/year).
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      locale: locale,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
}
