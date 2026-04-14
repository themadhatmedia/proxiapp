/// Full-word, capitalized labels for pulse search radius and per-user distance from API [distance_unit].

/// First letter uppercase, rest lowercase (e.g. "Yards", "Miles").
String _capitalizeUnitWord(String word) {
  if (word.isEmpty) return word;
  final t = word.trim();
  return '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}';
}

/// Plural unit name for radius chips and headers (e.g. "Yards", "Miles").
String pulseDistanceUnitDisplay(String? distanceUnit) {
  final u = (distanceUnit ?? 'yards').toLowerCase().trim();
  switch (u) {
    case 'yards':
    case 'yard':
      return 'Yards';
    case 'miles':
    case 'mile':
      return 'Miles';
    case 'meters':
    case 'meter':
    case 'metres':
    case 'metre':
      return 'Meters';
    case 'kilometers':
    case 'kilometer':
    case 'kilometres':
    case 'kilometre':
      return 'Kilometers';
    default:
      if (u.isEmpty) return 'Yards';
      return _capitalizeUnitWord(u);
  }
}

/// Second line under the numeric radius in the pulse selector (full word).
String pulseRadiusChipSubtitle(String? distanceUnit) {
  return pulseDistanceUnitDisplay(distanceUnit);
}

/// "50 Yards away" / "1.2 Miles away" style for list rows.
String formatPulseDistanceAway(double distance, String? distanceUnit) {
  final u = (distanceUnit ?? 'yards').toLowerCase().trim();
  final value = _formatDistanceValue(distance, u);
  final word = _distanceUnitWord(u, distance);
  return '$value ${_capitalizeUnitWord(word)} away';
}

/// Compact label for profile chips, e.g. "250 Yards" or "Miles".
String formatPulseDistanceCompact(double distance, String? distanceUnit) {
  final u = (distanceUnit ?? 'yards').toLowerCase().trim();
  final value = _formatDistanceValue(distance, u);
  final word = _distanceUnitWord(u, distance);
  return '$value ${_capitalizeUnitWord(word)}';
}

String _formatDistanceValue(double distance, String unitNorm) {
  if (distance <= 0) return '0';
  if (unitNorm == 'miles' ||
      unitNorm == 'mile' ||
      unitNorm == 'kilometers' ||
      unitNorm == 'kilometer' ||
      unitNorm == 'kilometres' ||
      unitNorm == 'kilometre') {
    if (distance < 10) return distance.toStringAsFixed(1);
  }
  return distance.toStringAsFixed(0);
}

String _distanceUnitWord(String u, double distance) {
  final n = distance.round();
  switch (u) {
    case 'yards':
    case 'yard':
      return n == 1 ? 'yard' : 'yards';
    case 'miles':
    case 'mile':
      if (distance > 0 && (distance - 1.0).abs() < 0.06) return 'mile';
      return 'miles';
    case 'meters':
    case 'meter':
    case 'metres':
    case 'metre':
      return n == 1 ? 'meter' : 'meters';
    case 'kilometers':
    case 'kilometer':
    case 'kilometres':
    case 'kilometre':
      if (distance > 0 && distance < 1.05) return 'kilometer';
      return n == 1 ? 'kilometer' : 'kilometers';
    default:
      return u;
  }
}
