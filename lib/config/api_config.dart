class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://calorie-backend.onrender.com',
   );
}
