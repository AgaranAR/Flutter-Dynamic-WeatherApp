import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; // For pi constant and math functions
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Main entry point
void main() => runApp(const AestheticClock());

/// Main application widget
class AestheticClock extends StatelessWidget {
  const AestheticClock({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aesthetic Clock',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: ClockScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Models and constants for the application
class AppConstants {
  // API constants
  static const String weatherApiKey = '17e83178ffea48ecab693702251505';
  static const String weatherApiBaseUrl = 'http://api.weatherapi.com/v1/current.json';

  // Default settings
  static const String defaultCity = 'kodaikanal';
  static const bool defaultIs24HourFormat = true;
  static const bool defaultShowSeconds = true;
  static const bool defaultUseAnimations = true;

  // Weather refresh interval in minutes
  static const int weatherRefreshInterval = 30;
}

/// Clock preferences model
class ClockPreferences {
  String city;
  bool is24HourFormat;
  bool showSeconds;
  bool useAnimations;

  ClockPreferences({
    required this.city,
    required this.is24HourFormat,
    required this.showSeconds,
    required this.useAnimations,
  });

  // Create a default instance
  factory ClockPreferences.defaultPrefs() {
    return ClockPreferences(
      city: AppConstants.defaultCity,
      is24HourFormat: AppConstants.defaultIs24HourFormat,
      showSeconds: AppConstants.defaultShowSeconds,
      useAnimations: AppConstants.defaultUseAnimations,
    );
  }

  // Convert to/from JSON for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'is24HourFormat': is24HourFormat,
      'showSeconds': showSeconds,
      'useAnimations': useAnimations,
    };
  }

  factory ClockPreferences.fromJson(Map<String, dynamic> json) {
    return ClockPreferences(
      city: json['city'] ?? AppConstants.defaultCity,
      is24HourFormat: json['is24HourFormat'] ?? AppConstants.defaultIs24HourFormat,
      showSeconds: json['showSeconds'] ?? AppConstants.defaultShowSeconds,
      useAnimations: json['useAnimations'] ?? AppConstants.defaultUseAnimations,
    );
  }
}

/// Weather data model
class WeatherData {
  final String condition;
  final double temperature;
  final double feelsLike;
  final String iconUrl;
  final DateTime lastUpdated;

  WeatherData({
    required this.condition,
    required this.temperature,
    required this.feelsLike,
    required this.iconUrl,
    required this.lastUpdated,
  });

  // Factory constructor to create weather data from API response
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['current']['condition']['text'] ?? 'Unknown',
      temperature: (json['current']['temp_c'] ?? 0).toDouble(),
      feelsLike: (json['current']['feelslike_c'] ?? 0).toDouble(),
      iconUrl: 'https:${json['current']['condition']['icon'] ?? ''}',
      lastUpdated: DateTime.now(),
    );
  }

  // Create a default instance for error cases
  factory WeatherData.defaultData() {
    return WeatherData(
      condition: 'Clear',
      temperature: 25.0,
      feelsLike: 25.0,
      iconUrl: '',
      lastUpdated: DateTime.now(),
    );
  }

  // Get the simplified weather condition for animations
  String get simplifiedCondition {
    final weatherCondition = condition.toLowerCase();

    if (weatherCondition.contains('rain') || weatherCondition.contains('drizzle')) {
      return 'rainy';
    } else if (weatherCondition.contains('cloud') || weatherCondition.contains('overcast')) {
      return 'cloudy';
    } else if (weatherCondition.contains('snow') || weatherCondition.contains('sleet') ||
        weatherCondition.contains('ice')) {
      return 'snowy';
    } else if (weatherCondition.contains('thunder') || weatherCondition.contains('storm')) {
      return 'stormy';
    } else {
      return 'clear';
    }
  }
}

/// Weather service for fetching weather data
class WeatherService {
  /// Fetch weather data for the specified city
  static Future<WeatherData> fetchWeatherData(String city) async {
    final url = '${AppConstants.weatherApiBaseUrl}?key=${AppConstants.weatherApiKey}&q=$city&aqi=no';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return WeatherData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching weather data: $e');
      return WeatherData.defaultData();
    }
  }
}

/// Preferences service for managing app settings
class PreferencesService {
  static const String _prefsKey = 'clock_preferences';

  /// Save preferences to persistent storage
  static Future<bool> savePreferences(ClockPreferences prefs) async {
    try {
      final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
      return await sharedPrefs.setString(_prefsKey, jsonEncode(prefs.toJson()));
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      return false;
    }
  }

  /// Load preferences from persistent storage
  static Future<ClockPreferences> loadPreferences() async {
    try {
      final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
      final String? prefsJson = sharedPrefs.getString(_prefsKey);

      if (prefsJson != null) {
        return ClockPreferences.fromJson(jsonDecode(prefsJson));
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }

    return ClockPreferences.defaultPrefs();
  }
}

/// Main clock screen widget
class ClockScreen extends StatefulWidget {
  @override
  _ClockScreenState createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with TickerProviderStateMixin {
  late TimeOfDay _time; // Current time (hour & minute)
  late Timer _timer; // Timer for updating the clock
  WeatherData? _weatherData; // Current weather data
  late ClockPreferences _preferences; // User preferences
  bool _isLoading = true; // Loading state
  bool _showSettings = false; // Settings panel visibility
  bool _isRefreshingWeather = false; // Weather refresh state

  // Animation controllers
  late AnimationController _weatherAnimationController;
  late AnimationController _transitionController;
  late Animation<double> _settingsPanelAnimation;

  // Text editing controller for city input
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize the application
  void _initializeApp() async {
    // Load preferences
    _preferences = await PreferencesService.loadPreferences();
    _cityController.text = _preferences.city;

    // Set initial time
    _time = TimeOfDay.now();

    // Initialize animation controllers
    _weatherAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _settingsPanelAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );

    // Start animations if enabled
    if (_preferences.useAnimations) {
      _weatherAnimationController.repeat();
    }

    // Start the clock timer
    _startClockTimer();

    // Fetch initial weather data
    await _fetchWeather();

    // Set up timer for updating weather periodically
    Timer.periodic(
      Duration(minutes: AppConstants.weatherRefreshInterval),
          (_) => _fetchWeather(),
    );

    setState(() {
      _isLoading = false;
    });
  }

  /// Start the clock timer
  void _startClockTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        _time = TimeOfDay.now(); // Update time every second
      });
    });
  }

  /// Fetch weather data for the current city
  Future<void> _fetchWeather() async {
    try {
      setState(() {
        _isRefreshingWeather = true;
      });

      final data = await WeatherService.fetchWeatherData(_preferences.city);

      setState(() {
        _weatherData = data;
        _isRefreshingWeather = false;
      });

    } catch (e) {
      debugPrint('Error updating weather: $e');
      setState(() {
        _isRefreshingWeather = false;
      });
    }
  }

  /// Format the current time according to preferences
  String get formattedTime {
    final hour = _preferences.is24HourFormat
        ? _time.hour.toString().padLeft(2, '0')
        : (_time.hour > 12 ? (_time.hour - 12) : (_time.hour == 0 ? 12 : _time.hour)).toString().padLeft(2, '0');
    final minute = _time.minute.toString().padLeft(2, '0');

    if (_preferences.showSeconds) {
      final second = DateTime.now().second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    } else {
      return '$hour:$minute';
    }
  }

  /// Get the AM/PM indicator for 12-hour format
  String get amPmIndicator {
    if (_preferences.is24HourFormat) return '';
    return _time.hour < 12 ? 'AM' : 'PM';
  }

  /// Calculate background colors based on time and weather
  List<Color> getBackgroundColors(TimeOfDay time, [String weatherCondition = 'clear']) {
    final hour = time.hour;
    List<Color> timeColors;

    // First determine time-based colors
    if (hour >= 6 && hour < 12) {
      // Morning
      timeColors = [Colors.orange.shade100, Colors.yellow.shade200];
    } else if (hour >= 12 && hour < 18) {
      // Afternoon
      timeColors = [Colors.lightBlue.shade300, Colors.white];
    } else if (hour >= 18 && hour < 21) {
      // Evening
      timeColors = [Colors.deepOrange.shade300, Colors.purple.shade200];
    } else {
      // Night
      timeColors = [Colors.indigo.shade900, Colors.black];
    }

    // Then adjust based on weather
    switch (weatherCondition) {
      case 'rainy':
        return [
          timeColors[0].withBlue(min(255, timeColors[0].blue + 40)).withOpacity(0.9),
          timeColors[1].withBlue(min(255, timeColors[1].blue + 40)).withOpacity(0.8)
        ];
      case 'cloudy':
        return [
          timeColors[0].withOpacity(0.9),
          timeColors[1].withOpacity(0.8)
        ];
      case 'snowy':
        return [
          Colors.white.withOpacity(0.8),
          timeColors[1].withOpacity(0.9)
        ];
      case 'stormy':
        return [
          Colors.grey.shade700,
          Colors.indigo.shade900
        ];
      default:
        return timeColors;
    }
  }

  /// Calculate sun position based on time of day
  double getSunPosition(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;

    // Sun visible from 6:00 to 18:00
    if (hour < 6 || hour >= 18) return -1; // Not visible

    // Calculate position (0.0 at 6am, 1.0 at 6pm)
    return (hour - 6 + minute / 60) / 12;
  }

  /// Calculate moon position based on time of day
  double getMoonPosition(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;

    // Moon visible from 18:00 to 6:00
    if (hour >= 6 && hour < 18) return -1; // Not visible

    // Calculate position (0.0 at 6pm, 1.0 at 6am)
    if (hour >= 18) {
      return (hour - 18 + minute / 60) / 12;
    } else {
      return (hour + 6 + minute / 60) / 12;
    }
  }

  /// Toggle settings panel visibility
  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });

    if (_showSettings) {
      _transitionController.forward();
    } else {
      _transitionController.reverse();
    }
  }

  /// Save the updated preferences
  Future<void> _savePreferences() async {
    final newPreferences = ClockPreferences(
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _preferences.city,
      is24HourFormat: _preferences.is24HourFormat,
      showSeconds: _preferences.showSeconds,
      useAnimations: _preferences.useAnimations,
    );

    final bool cityChanged = newPreferences.city != _preferences.city;

    setState(() {
      _preferences = newPreferences;
    });

    await PreferencesService.savePreferences(_preferences);

    // If city changed, refresh weather data
    if (cityChanged) {
      await _fetchWeather();
    }

    // Update animations based on preference
    if (_preferences.useAnimations) {
      _weatherAnimationController.repeat();
    } else {
      _weatherAnimationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final weatherCondition = _weatherData?.simplifiedCondition ?? 'clear';
    final colors = getBackgroundColors(_time, weatherCondition);
    final sunPosition = getSunPosition(_time);
    final moonPosition = getMoonPosition(_time);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Celestial bodies
            if (sunPosition >= 0 && _preferences.useAnimations)
              _buildSunImage(sunPosition, size),
            if (moonPosition >= 0 && _preferences.useAnimations)
              _buildMoonImage(moonPosition, size),

            // Weather elements
            if (_preferences.useAnimations)
              ..._buildWeatherElements(weatherCondition, size),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clock display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedTime,
                          style: GoogleFonts.orbitron(
                            fontSize: 60,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(2, 2),
                              )
                            ],
                          ),
                        ),
                        if (!_preferences.is24HourFormat)
                          Text(
                            amPmIndicator,
                            style: GoogleFonts.orbitron(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Date display
                  const SizedBox(height: 16),
                  Text(
                    _getFormattedDate(),
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Weather display
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: _isRefreshingWeather ? null : _fetchWeather,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      _isRefreshingWeather
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : _getWeatherIcon(weatherCondition),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _weatherData?.condition.toUpperCase() ?? 'UNKNOWN',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_weatherData?.temperature.toStringAsFixed(1) ?? 'N/A'}°C',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Location display
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _preferences.city.toUpperCase(),
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Settings button
            Positioned(
              bottom: 30,
              right: 30,
              child: FloatingActionButton(
                onPressed: _toggleSettings,
                backgroundColor: Colors.black.withOpacity(0.3),
                child: Icon(
                  _showSettings ? Icons.close : Icons.settings,
                  color: Colors.white,
                ),
              ),
            ),

            // Settings panel
            if (_showSettings)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _settingsPanelAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _settingsPanelAnimation.value,
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * _settingsPanelAnimation.value),
                        child: _buildSettingsPanel(context),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build the settings panel
  Widget _buildSettingsPanel(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.lato(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // City input
            TextField(
              controller: _cityController,
              style: GoogleFonts.lato(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'City',
                labelStyle: GoogleFonts.lato(color: Colors.white70),
                prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Time format toggle
            SwitchListTile(
              title: Text(
                '24-Hour Format',
                style: GoogleFonts.lato(color: Colors.white),
              ),
              value: _preferences.is24HourFormat,
              onChanged: (value) {
                setState(() {
                  _preferences.is24HourFormat = value;
                });
              },
              activeColor: Colors.blue,
              contentPadding: EdgeInsets.zero,
            ),

            // Show seconds toggle
            SwitchListTile(
              title: Text(
                'Show Seconds',
                style: GoogleFonts.lato(color: Colors.white),
              ),
              value: _preferences.showSeconds,
              onChanged: (value) {
                setState(() {
                  _preferences.showSeconds = value;
                });
              },
              activeColor: Colors.blue,
              contentPadding: EdgeInsets.zero,
            ),

            // Animations toggle
            SwitchListTile(
              title: Text(
                'Enable Animations',
                style: GoogleFonts.lato(color: Colors.white),
              ),
              value: _preferences.useAnimations,
              onChanged: (value) {
                setState(() {
                  _preferences.useAnimations = value;
                });
              },
              activeColor: Colors.blue,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: () {
                _savePreferences();
                _toggleSettings();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Save Settings',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format the current date
  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final day = days[now.weekday - 1];
    final month = months[now.month - 1];

    return '$day, $month ${now.day}, ${now.year}';
  }

  // VISUAL ELEMENT BUILDERS

  /// Build the sun as an image with glow effect
  Widget _buildSunImage(double position, Size size) {
    // Calculate sun position on an arc path
    final double centerX = size.width / 2;
    final double angle = position * pi;
    final double x = centerX + centerX * cos(angle);
    final double y = size.height - sin(angle) * size.height * 0.8;

    return Positioned(
      left: x - 50,
      top: y - 50,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 80,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Colors.yellow.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/sun.png',
          // Replace with placeholder for demo
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    Colors.yellow.shade300,
                    Colors.orange.shade400,
                  ],
                  stops: const [0.2, 0.7, 1.0],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build the moon as an image with glow effect
  Widget _buildMoonImage(double position, Size size) {
    // Calculate moon position on an arc path
    final double centerX = size.width / 2;
    final double angle = position * pi;
    final double x = centerX + centerX * cos(angle);
    final double y = size.height - sin(angle) * size.height * 0.8;

    return Positioned(
      left: x - 40,
      top: y - 40,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/moon.png',
          // Replace with placeholder for demo
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    const Color(0xFFF5F5F5),
                    const Color(0xFFE0E0E0),
                  ],
                  stops: const [0.2, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build weather elements based on current condition
  List<Widget> _buildWeatherElements(String weatherCondition, Size size) {
    switch (weatherCondition) {
      case 'rainy':
        return _buildRainElements(size);
      case 'cloudy':
        return _buildCloudElements(size);
      case 'snowy':
        return _buildSnowElements(size);
      case 'stormy':
        return _buildStormElements(size);
      default:
        return [];
    }
  }

  /// Rain animation with multiple droplets
  List<Widget> _buildRainElements(Size size) {
    List<Widget> rainDrops = [];
    final rng = Random(); // No fixed seed = more natural variation

    for (int i = 0; i < 30; i++) {
      final startX = rng.nextDouble() * size.width;
      final dropSize = rng.nextDouble() * 10 + 10;
      final initialOffset = rng.nextDouble(); // helps vary each drop's phase

      rainDrops.add(
        AnimatedBuilder(
          animation: _weatherAnimationController,
          builder: (context, child) {
            final progress = (_weatherAnimationController.value + initialOffset) % 1.0;
            final yOffset = progress * size.height;

            return Positioned(
              left: startX,
              top: yOffset - dropSize, // ensures it falls from top
              child: Opacity(
                opacity: 0.8,
                child: Image.asset(
                  'assets/images/raindrop.png',
                  width: dropSize,
                  height: dropSize * 3,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 2,
                      height: dropSize,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return rainDrops;
  }

  /// Cloud elements with slow animation
  List<Widget> _buildCloudElements(Size size) {
    List<Widget> clouds = [];

    // Define cloud positions with explicit types
    final cloudPositions = [
      {'left': size.width * 0.7, 'top': size.height * 0.15, 'size': size.width * 0.3},
      {'left': size.width * 0.2, 'top': size.height * 0.25, 'size': size.width * 0.25},
      {'left': size.width * 0.4, 'top': size.height * 0.1, 'size': size.width * 0.2},
    ];

    for (int i = 0; i < cloudPositions.length; i++) {
      final pos = cloudPositions[i];
      final double leftPos = pos['left'] as double;
      final double topPos = pos['top'] as double;
      final double cloudSize = pos['size'] as double;

      clouds.add(
        AnimatedBuilder(
          animation: _weatherAnimationController,
          builder: (context, child) {
            // Gentle floating animation
            final xOffset = sin(_weatherAnimationController.value * 2 * pi + i) * 10;

            return Positioned(
              left: leftPos + xOffset,
              top: topPos,
              child: Opacity(
                opacity: 0.8,
                child: Image.asset(
                  'assets/images/cloud.png',
                  width: cloudSize,
                  // Replace with placeholder for demo
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: cloudSize,
                      height: cloudSize * 0.6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return clouds;
  }

  /// Snow elements with falling animation
  List<Widget> _buildSnowElements(Size size) {
    List<Widget> snowflakes = [];
    final rng = Random(2); // Fixed seed for consistent pattern

    for (int i = 0; i < 40; i++) {
      final startX = rng.nextDouble() * size.width;
      final startY = rng.nextDouble() * size.height * 0.5 - 100;
      final flakeSize = rng.nextDouble() * 15 + 10;
      final rotationSpeed = rng.nextDouble() * 2 + 1;

      snowflakes.add(
        AnimatedBuilder(
          animation: _weatherAnimationController,
          builder: (context, child) {
            // Calculate snowflake position and rotation with animation
            final progress = (_weatherAnimationController.value + (i / 40)) % 1.0;
            final yOffset = progress * (size.height + 200);
            final xOffset = sin(progress * 2 * pi) * 20;
            final rotation = progress * rotationSpeed * 2 * pi;

            return Positioned(
              left: startX + xOffset,
              top: startY + yOffset,
              child: Transform.rotate(
                angle: rotation,
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/snowflake.png',
                    width: flakeSize,
                    height: flakeSize,
                    // Replace with placeholder for demo
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: flakeSize,
                        height: flakeSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return snowflakes;
  }

  /// Storm elements with clouds and lightning
  List<Widget> _buildStormElements(Size size) {
    List<Widget> stormElements = [];

    // Add dark clouds with explicit typing
    final cloudPositions = [
      {'left': size.width * 0.65, 'top': size.height * 0.12, 'size': size.width * 0.4},
      {'left': size.width * 0.15, 'top': size.height * 0.18, 'size': size.width * 0.35},
      {'left': size.width * 0.4, 'top': size.height * 0.08, 'size': size.width * 0.3},
    ];

    for (int i = 0; i < cloudPositions.length; i++) {
      final pos = cloudPositions[i];
      final double leftPos = pos['left'] as double;
      final double topPos = pos['top'] as double;
      final double cloudSize = pos['size'] as double;

      stormElements.add(
        Positioned(
          left: leftPos,
          top: topPos,
          child: Opacity(
            opacity: 0.9,
            child: Image.asset(
              'assets/images/stormcloud.png',
              width: cloudSize,
              // Replace with placeholder for demo
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: cloudSize,
                  height: cloudSize * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.grey[700]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Add lightning flash with animation
    stormElements.add(
      AnimatedBuilder(
        animation: _weatherAnimationController,
        builder: (context, child) {
          // Every few seconds, show lightning
          final showLightning = _weatherAnimationController.value > 0.8 ||
              (_weatherAnimationController.value > 0.4 && _weatherAnimationController.value < 0.43);

          return Positioned(
            left: size.width * 0.4,
            top: size.height * 0.2,
            child: Opacity(
              opacity: showLightning ? 0.9 : 0.0,
              child: Image.asset(
                'assets/images/lightning.png',
                width: 100,
                height: 150,
                // Replace with placeholder for demo
                errorBuilder: (context, error, stackTrace) {
                  return CustomPaint(
                    size: const Size(100, 150),
                    painter: LightningPainter(),
                  );
                },
              ),
            ),
          );
        },
      ),
    );

    return stormElements;
  }

  /// Get weather icon for the weather display
  Widget _getWeatherIcon(String weatherCondition) {
    const double iconSize = 24;

    switch (weatherCondition) {
      case 'rainy':
        return const Icon(Icons.water_drop, color: Colors.white, size: iconSize);
      case 'cloudy':
        return const Icon(Icons.cloud, color: Colors.white, size: iconSize);
      case 'snowy':
        return const Icon(Icons.ac_unit, color: Colors.white, size: iconSize);
      case 'stormy':
        return const Icon(Icons.flash_on, color: Colors.white, size: iconSize);
      default:
        return const Icon(Icons.wb_sunny, color: Colors.white, size: iconSize);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _weatherAnimationController.dispose();
    _transitionController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}

/// Custom painter for lightning (as fallback if image asset is missing)
class LightningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.shade100
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create a zigzag lightning bolt
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.3, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height);
    path.lineTo(size.width * 0.5, size.height * 0.6);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.5, 0);

    canvas.drawPath(path, paint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = Colors.yellow.shade100.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}