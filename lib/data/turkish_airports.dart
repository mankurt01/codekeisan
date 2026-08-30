/// Turkish IATA airport codes database
/// Used to distinguish between domestic and international layovers
library;

const Set<String> turkishAirportCodes = {
  // Major Airports
  'IST', // Istanbul Airport
  'SAW', // Istanbul Sabiha Gokcen
  'AYT', // Antalya
  'ESB', // Ankara Esenboga
  'ADB', // Izmir Adnan Menderes
  'DLM', // Dalaman
  'BJV', // Bodrum Milas
  
  // Black Sea Region
  'TZX', // Trabzon
  'SZF', // Samsun Carsamba
  'OGU', // Ordu-Giresun
  'NOP', // Sinop
  
  // Eastern Anatolia
  'ERZ', // Erzurum
  'VAN', // Van
  'KSY', // Kars
  'IGD', // Igdir
  'MSR', // Mus
  'BGG', // Bingol
  'AJI', // Agri
  
  // Southeastern Anatolia
  'GZT', // Gaziantep
  'DIY', // Diyarbakir
  'MLX', // Malatya
  'EZS', // Elazig
  'GNY', // Sanliurfa GAP
  'SFQ', // Sanliurfa
  'BAL', // Batman
  'NKT', // Sirnak
  'MQM', // Mardin
  'ADF', // Adiyaman
  
  // Central Anatolia
  'KYA', // Konya
  'ASR', // Kayseri
  'NAV', // Nevsehir
  'VAS', // Sivas
  'TJK', // Tokat
  
  // Mediterranean Region
  'HTY', // Hatay
  'KZR', // Kahramanmaras
  
  // Aegean Region
  'DNZ', // Denizli Cardak
  'USQ', // Usak
  'AFY', // Afyon
  'ISE', // Isparta
  
  // Marmara Region
  'YEI', // Bursa Yenisehir
  'BZI', // Balikesir
  'EDO', // Edremit Korfez
  'CKZ', // Canakkale
  'TEQ', // Tekirdag Corlu
  'KCO', // Kocaeli Cengiz Topel
  'AOE', // Eskisehir
  
  // Other
  'MZH', // Merzifon
  'KFS', // Kastamonu
  'ONQ', // Zonguldak
  'SIC', // Sinop
  'GKD', // Gokceada
};

/// Check if an airport code is a Turkish airport
bool isTurkishAirport(String code) {
  return turkishAirportCodes.contains(code.toUpperCase());
}
