/// Where a person mostly eats. Context for naming dishes in a photo scan,
/// never a filter. The keys match the backend's `services/regions.py` (a test
/// pins them); an unknown key is ignored by the server.
class FoodRegion {
  const FoodRegion(this.key, this.label);

  final String key;
  final String label;
}

const foodRegions = [
  FoodRegion('north_america', 'North America'),
  FoodRegion('latin_america', 'Latin America and the Caribbean'),
  FoodRegion('europe', 'Europe'),
  FoodRegion('west_africa', 'West Africa'),
  FoodRegion('east_africa', 'East Africa'),
  FoodRegion('southern_africa', 'Southern Africa'),
  FoodRegion('north_africa_middle_east', 'North Africa and the Middle East'),
  FoodRegion('south_asia', 'South Asia'),
  FoodRegion('east_asia', 'East Asia'),
  FoodRegion('southeast_asia', 'Southeast Asia'),
  FoodRegion('oceania', 'Australia and the Pacific'),
  FoodRegion('other', 'Other'),
];

/// The label for a stored key, or null for none or a key this app doesn't know.
String? foodRegionLabel(String? key) {
  for (final r in foodRegions) {
    if (r.key == key) return r.label;
  }
  return null;
}
