/// DOSS App Constants v6 — Ride + Shuttle

class AppConstants {
  AppConstants._();

  // ── API ────────────────────────────────────────────────────────────────────
  static const String defaultApiUrl =
      'https://doss-backend-production.up.railway.app';

  // ── WebSocket ──────────────────────────────────────────────────────────────
  static const String riderNamespace  = '/riders';
  static const String driverNamespace = '/drivers';

  // ── Dispatch ──────────────────────────────────────────────────────────────
  static const int offerTimeoutSeconds   = 30;
  static const int locationUpdateIntervalMs = 3000;

  // ── Map ────────────────────────────────────────────────────────────────────
  static const double defaultLat  = 30.0444;
  static const double defaultLng  = 31.2357;
  static const double defaultZoom = 14.0;

  // ── Pricing ────────────────────────────────────────────────────────────────
  // Car:    15 EGP base + 5.5 EGP/km + 0.85 EGP/min,  min 25 EGP
  // Bike:   8.5 EGP base + 3.2 EGP/km + 0.45 EGP/min, min 15 EGP
  // Shuttle: fixed fare per station-to-station route

  // ── Subscription Fees (EGP/day) ────────────────────────────────────────────
  static const int subscriptionFeeCar     = 200;  // EGP per day
  static const int subscriptionFeeBike    = 100;  // EGP per day
  static const int subscriptionFeeShuttle = 350;  // EGP per day
  static const String instapayNumber      = '01100500022';

  // ── Shuttle Configuration ─────────────────────────────────────────────────
  static const int shuttleCapacity   = 14;   // 14-passenger microbus
  static const int shuttleTimeoutSec = 45;   // longer timeout for shuttle offers

  // ── Governorates ──────────────────────────────────────────────────────────
  static const List<String> governorates = [
    'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
    'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qalyubia',
    'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
    'Damietta', 'Sharkia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
    'Luxor', 'Qena', 'North Sinai', 'Sohag',
  ];

  // ── Pre-defined Shuttle Stations (Cairo + Alexandria) ─────────────────────
  //
  // Coordinates and names match real-world locations used by Uber Shuttle Egypt.
  // Fares based on Uber Shuttle Egypt pricing intelligence (2024):
  //   Short (<5km):  8–15 EGP
  //   Medium (<12km): 15–25 EGP
  //   Long (>12km):  25–40 EGP
  //
  // These stations are the seed data — backend can override via API.
  //
  static const List<Map<String, dynamic>> shuttleStations = [
    // ── Greater Cairo ─────────────────────────────────────────────
    {
      'id': 'nasr_city_stadium',
      'nameEn': 'Nasr City — Stadium',
      'nameAr': 'مدينة نصر — الاستاد',
      'location': {'lat': 30.0646, 'lng': 31.3162},
      'governorate': 'cairo',
      'area': 'Nasr City',
    },
    {
      'id': 'nasr_city_rabaa',
      'nameEn': 'Nasr City — Rabaa',
      'nameAr': 'مدينة نصر — رابعة',
      'location': {'lat': 30.0618, 'lng': 31.3289},
      'governorate': 'cairo',
      'area': 'Nasr City',
    },
    {
      'id': 'heliopolis_center',
      'nameEn': 'Heliopolis — City Center',
      'nameAr': 'مصر الجديدة — وسط البلد',
      'location': {'lat': 30.0935, 'lng': 31.3202},
      'governorate': 'cairo',
      'area': 'Heliopolis',
    },
    {
      'id': 'heliopolis_airport_road',
      'nameEn': 'Heliopolis — Airport Road',
      'nameAr': 'مصر الجديدة — طريق المطار',
      'location': {'lat': 30.1019, 'lng': 31.3428},
      'governorate': 'cairo',
      'area': 'Heliopolis',
    },
    {
      'id': 'maadi_corniche',
      'nameEn': 'Maadi — Corniche',
      'nameAr': 'المعادي — الكورنيش',
      'location': {'lat': 29.9596, 'lng': 31.2506},
      'governorate': 'cairo',
      'area': 'Maadi',
    },
    {
      'id': 'maadi_degla',
      'nameEn': 'Maadi — Degla',
      'nameAr': 'المعادي — دجلة',
      'location': {'lat': 29.9535, 'lng': 31.2684},
      'governorate': 'cairo',
      'area': 'Maadi',
    },
    {
      'id': 'downtown_tahrir',
      'nameEn': 'Downtown — Tahrir Square',
      'nameAr': 'وسط البلد — ميدان التحرير',
      'location': {'lat': 30.0444, 'lng': 31.2357},
      'governorate': 'cairo',
      'area': 'Downtown',
    },
    {
      'id': 'zamalek_center',
      'nameEn': 'Zamalek — 26 July',
      'nameAr': 'الزمالك — 26 يوليو',
      'location': {'lat': 30.0618, 'lng': 31.2196},
      'governorate': 'cairo',
      'area': 'Zamalek',
    },
    {
      'id': 'mohandessin_gameat',
      'nameEn': 'Mohandessin — Gameat El Dowal',
      'nameAr': 'المهندسين — جامعة الدول',
      'location': {'lat': 30.0531, 'lng': 31.1996},
      'governorate': 'giza',
      'area': 'Mohandessin',
    },
    {
      'id': 'dokki_center',
      'nameEn': 'Dokki — City Center',
      'nameAr': 'الدقي — وسط',
      'location': {'lat': 30.0359, 'lng': 31.2073},
      'governorate': 'giza',
      'area': 'Dokki',
    },
    {
      'id': 'new_cairo_fifth',
      'nameEn': 'New Cairo — 5th Settlement',
      'nameAr': 'القاهرة الجديدة — التجمع الخامس',
      'location': {'lat': 30.0076, 'lng': 31.4787},
      'governorate': 'cairo',
      'area': 'New Cairo',
    },
    {
      'id': 'new_cairo_rehab',
      'nameEn': 'New Cairo — Rehab City',
      'nameAr': 'القاهرة الجديدة — مدينة الرحاب',
      'location': {'lat': 30.0578, 'lng': 31.4935},
      'governorate': 'cairo',
      'area': 'New Cairo',
    },
    {
      'id': '6th_oct_center',
      'nameEn': '6th October — City Center',
      'nameAr': 'السادس من أكتوبر — وسط',
      'location': {'lat': 29.9343, 'lng': 30.9176},
      'governorate': 'giza',
      'area': '6th October',
    },
    // ── Alexandria ────────────────────────────────────────────────
    {
      'id': 'alex_smouha',
      'nameEn': 'Alexandria — Smouha',
      'nameAr': 'الإسكندرية — سموحة',
      'location': {'lat': 31.2001, 'lng': 29.9187},
      'governorate': 'alexandria',
      'area': 'Smouha',
    },
    {
      'id': 'alex_roushdy',
      'nameEn': 'Alexandria — Roushdy',
      'nameAr': 'الإسكندرية — رشدي',
      'location': {'lat': 31.2279, 'lng': 29.9538},
      'governorate': 'alexandria',
      'area': 'Roushdy',
    },
    {
      'id': 'alex_stanley',
      'nameEn': 'Alexandria — Stanley',
      'nameAr': 'الإسكندرية — ستانلي',
      'location': {'lat': 31.2403, 'lng': 29.9673},
      'governorate': 'alexandria',
      'area': 'Stanley',
    },
    {
      'id': 'alex_downtown',
      'nameEn': 'Alexandria — Downtown',
      'nameAr': 'الإسكندرية — وسط البلد',
      'location': {'lat': 31.2001, 'lng': 29.9187},
      'governorate': 'alexandria',
      'area': 'Downtown',
    },
  ];

  // ── Pre-defined Shuttle Routes with fixed fares ────────────────────────────
  //
  // Pricing methodology: Uber Shuttle Egypt 2024 benchmark rates
  //   Base Shuttle fare ≈ 8 EGP for first 3km, +2 EGP per km after
  //   Maximum Shuttle fare (Cairo intra-city): 40 EGP
  //   Minimum Shuttle fare: 8 EGP
  //
  static const List<Map<String, dynamic>> shuttleRoutes = [
    // Cairo Routes
    {
      'routeId': 'nasr_city_downtown',
      'origin':       'nasr_city_stadium',
      'destination':  'downtown_tahrir',
      'fareEgp':      20.0,
      'distanceKm':   8.5,
      'durationMinutes': 25,
      'governorate':  'cairo',
    },
    {
      'routeId': 'heliopolis_downtown',
      'origin':       'heliopolis_center',
      'destination':  'downtown_tahrir',
      'fareEgp':      25.0,
      'distanceKm':   10.2,
      'durationMinutes': 30,
      'governorate':  'cairo',
    },
    {
      'routeId': 'maadi_downtown',
      'origin':       'maadi_corniche',
      'destination':  'downtown_tahrir',
      'fareEgp':      20.0,
      'distanceKm':   9.0,
      'durationMinutes': 22,
      'governorate':  'cairo',
    },
    {
      'routeId': 'new_cairo_downtown',
      'origin':       'new_cairo_fifth',
      'destination':  'downtown_tahrir',
      'fareEgp':      55.0,
      'distanceKm':   28.0,
      'durationMinutes': 55,
      'governorate':  'cairo',
    },
    {
      'routeId': 'new_cairo_nasr_city',
      'origin':       'new_cairo_fifth',
      'destination':  'nasr_city_stadium',
      'fareEgp':      35.0,
      'distanceKm':   18.0,
      'durationMinutes': 35,
      'governorate':  'cairo',
    },
    {
      'routeId': 'nasr_heliopolis',
      'origin':       'nasr_city_stadium',
      'destination':  'heliopolis_center',
      'fareEgp':      15.0,
      'distanceKm':   5.0,
      'durationMinutes': 15,
      'governorate':  'cairo',
    },
    {
      'routeId': 'mohandessin_downtown',
      'origin':       'mohandessin_gameat',
      'destination':  'downtown_tahrir',
      'fareEgp':      18.0,
      'distanceKm':   5.5,
      'durationMinutes': 18,
      'governorate':  'giza',
    },
    {
      'routeId': 'maadi_nasr_city',
      'origin':       'maadi_corniche',
      'destination':  'nasr_city_stadium',
      'fareEgp':      35.0,
      'distanceKm':   14.0,
      'durationMinutes': 35,
      'governorate':  'cairo',
    },
    {
      'routeId': 'rehab_downtown',
      'origin':       'new_cairo_rehab',
      'destination':  'downtown_tahrir',
      'fareEgp':      60.0,
      'distanceKm':   30.0,
      'durationMinutes': 58,
      'governorate':  'cairo',
    },
    {
      'routeId': '6oct_downtown',
      'origin':       '6th_oct_center',
      'destination':  'downtown_tahrir',
      'fareEgp':      45.0,
      'distanceKm':   24.0,
      'durationMinutes': 50,
      'governorate':  'giza',
    },
    {
      'routeId': 'downtown_zamalek',
      'origin':       'downtown_tahrir',
      'destination':  'zamalek_center',
      'fareEgp':      15.0,
      'distanceKm':   3.0,
      'durationMinutes': 10,
      'governorate':  'cairo',
    },
    {
      'routeId': 'dokki_downtown',
      'origin':       'dokki_center',
      'destination':  'downtown_tahrir',
      'fareEgp':      15.0,
      'distanceKm':   5.0,
      'durationMinutes': 15,
      'governorate':  'giza',
    },
    // Alexandria Routes
    {
      'routeId': 'alex_smouha_downtown',
      'origin':       'alex_smouha',
      'destination':  'alex_downtown',
      'fareEgp':      20.0,
      'distanceKm':   7.0,
      'durationMinutes': 20,
      'governorate':  'alexandria',
    },
    {
      'routeId': 'alex_stanley_downtown',
      'origin':       'alex_stanley',
      'destination':  'alex_downtown',
      'fareEgp':      25.0,
      'distanceKm':   9.0,
      'durationMinutes': 25,
      'governorate':  'alexandria',
    },
  ];
}
