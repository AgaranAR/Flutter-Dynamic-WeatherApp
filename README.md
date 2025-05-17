# ⏰ WeatherClock

A beautiful Flutter digital clock app with real-time animated weather and customizable features.

---

## 🌦️ Features

### 📱 User-Friendly

- Real-time weather animations (rain, clouds, snow, lightning)
- Temperature and weather condition display
- Tap to manually refresh weather
- Automatic updates every 30 minutes

### 🎨 Customizable Settings

- City selection for weather
- 12/24 hour clock toggle
- Show/hide seconds
- Enable/disable animations for performance

### 🖼️ Visual Elements

- Background changes based on time of day
- Sun and moon move across the screen
- Weather affects background theme
- Smooth transitions

### 💾 Persistence

- Settings stored locally with SharedPreferences
- Preferences saved between restarts

---

## 🧑‍💻 Developer Highlights

### ✅ Code Structure

- Clean separation: models, services, UI
- Constants in `AppConstants`
- Easy configuration and extension

### ⚙️ Performance & Error Handling

- Optimized animations
- Graceful fallbacks for errors
- Custom error widgets for images

### 🧪 Testability

- Separated service layer
- Pure functions and dependency injection

---

## 🚀 Getting Started

1. **Install Flutter** (version 3.2.0 or higher)
2. **Clone the repo**:
   ```bash
   git clone https://github.com/AgaranAR/Flutter-Dynamic-WeatherApp.git
Install dependencies:

bash
Copy
Edit
flutter pub get
Add images to assets/images/ folder:

sun.png

moon.png

cloud.png

stormcloud.png

raindrop.png

snowflake.png

lightning.png

Run the app:

bash
Copy
Edit
flutter run
📦 Dependencies
google_fonts

http

shared_preferences

intl

provider (optional for future)

🔧 Weather API
This app uses WeatherAPI.com for real-time weather data.
Replace the API key in AppConstants with your own.

🔮 Future Improvements
State management with Provider or Riverpod

Multiple location support

Additional themes and weather effects

Unit and widget testing

Weather forecast integration

Auto-detect location

📝 License
This project is open source and available under the MIT License.
