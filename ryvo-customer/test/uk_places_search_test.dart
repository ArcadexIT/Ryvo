import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ryvo_customer/core/location/location_service.dart';
import 'package:ryvo_customer/core/location/uk_places_search.dart';

void main() {
  test('unset US pickup is biased to London, a real pin is kept', () {
    final london = UkSearchBias.resolve(
      lat: UkSearchBias.fallbackLat,
      lng: UkSearchBias.fallbackLng,
      locationResolved: false,
    );
    expect(london.lat, UkSearchBias.londonLat);
    expect(london.lng, UkSearchBias.londonLng);

    final manchester = UkSearchBias.resolve(
      lat: 53.4808,
      lng: -2.2426,
      locationResolved: true,
    );
    expect(manchester.lat, 53.4808);
    expect(manchester.lng, -2.2426);
  });

  test('UK suffix is added once', () {
    expect(withUnitedKingdomSuffix('High Street'), 'High Street, United Kingdom');
    expect(withUnitedKingdomSuffix('High Street, UK'), 'High Street, UK');
    expect(
      withUnitedKingdomSuffix('High Street, United Kingdom'),
      'High Street, United Kingdom',
    );
  });

  test('only United Kingdom placemarks pass the country check', () {
    expect(isUnitedKingdomPlacemark(Placemark(isoCountryCode: 'GB')), isTrue);
    expect(isUnitedKingdomPlacemark(Placemark(country: 'United Kingdom')), isTrue);
    expect(isUnitedKingdomPlacemark(Placemark(isoCountryCode: 'US', country: 'United States')), isFalse);
  });

  test('closest UK point to the customer wins', () {
    final near = ResolvedLocation(lat: 51.51, lng: -0.12, address: 'Near');
    final far = ResolvedLocation(lat: 55.95, lng: -3.19, address: 'Far');
    final picked = pickClosestLocation(
      [far, near],
      lat: UkSearchBias.londonLat,
      lng: UkSearchBias.londonLng,
    );
    expect(picked?.address, 'Near');
  });

  test('autocomplete keeps street, town and distance', () {
    final suggestions = parsePlaceAutocomplete({
      'status': 'OK',
      'predictions': [
        {
          'description': '10 High Street, London SW1A 1AA, UK',
          'place_id': 'gb-near',
          'distance_meters': 240,
          'structured_formatting': {
            'main_text': '10 High Street',
            'secondary_text': 'London SW1A 1AA, UK',
          },
        },
        {
          'description': '10 High Street, Manchester, UK',
          'place_id': 'gb-far',
          'distance_meters': 260000,
          'structured_formatting': {
            'main_text': '10 High Street',
            'secondary_text': 'Manchester, UK',
          },
        },
        {'description': 'missing id'},
      ],
    });

    expect(suggestions, hasLength(2));
    expect(suggestions.first.placeId, 'gb-near');
    expect(suggestions.first.primaryText, '10 High Street');
    expect(suggestions.first.secondaryText, 'London SW1A 1AA, UK');
    expect(suggestions.first.distanceMeters, 240);
    expect(formatUkDistance(240), '240 m');
    expect(formatUkDistance(260000), '260 km');
  });

  test('place details keep the street and postcode', () {
    final resolved = parsePlaceDetails({
      'status': 'OK',
      'result': {
        'formatted_address': '10 Downing Street, London SW1A 2AA, UK',
        'name': '10 Downing Street',
        'geometry': {
          'location': {'lat': 51.5034, 'lng': -0.1276},
        },
        'address_components': [
          {'long_name': '10', 'types': ['street_number']},
          {'long_name': 'Downing Street', 'types': ['route']},
          {'long_name': 'London', 'types': ['postal_town']},
          {'long_name': 'SW1A 2AA', 'types': ['postal_code']},
          {'long_name': 'United Kingdom', 'types': ['country']},
        ],
      },
    });

    expect(resolved?.lat, 51.5034);
    expect(resolved?.shortAddress, '10 Downing Street');
    expect(resolved?.region, 'London, SW1A 2AA');
    expect(resolved?.address, '10 Downing Street, London SW1A 2AA, UK');
  });
}
