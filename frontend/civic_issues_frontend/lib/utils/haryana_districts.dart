// Haryana Districts Data

class HaryanaDistricts {
  static const List<String> all = [
    'Ambala',
    'Bhiwani',
    'Charkhi Dadri',
    'Faridabad',
    'Fatehabad',
    'Gurugram',
    'Hisar',
    'Jhajjar',
    'Jind',
    'Kaithal',
    'Karnal',
    'Kurukshetra',
    'Mahendragarh',
    'Nuh',
    'Palwal',
    'Panchkula',
    'Panipat',
    'Rewari',
    'Rohtak',
    'Sirsa',
    'Sonipat',
    'Yamunanagar',
  ];

  static const Map<String, String> descriptions = {
    'Gurugram': 'IT Hub & Financial Capital',
    'Faridabad': 'Industrial Hub',
    'Panchkula': 'Planned City',
    'Karnal': 'Rice Bowl of India',
    'Panipat': 'Textile City',
    'Ambala': 'Cantonment City',
    'Hisar': 'Agricultural Market',
    'Rohtak': 'Educational Hub',
  };

  static String? getDescription(String district) {
    return descriptions[district];
  }

  static bool isValid(String district) {
    return all.contains(district);
  }
}

