import time
from geopy.geocoders import Nominatim
from geopy.distance import geodesic

# Lista miast
cities = [
    "Opole",
    "Brzeg",
    "Nysa",
    "Prudnik",
    "Strzelce Opolskie",
    "Kędzierzyn-Koźle",
    "Racibórz"
]

def get_coordinates(city_name, geolocator):
    location = geolocator.geocode(city_name)
    if not location:
        raise ValueError(f"Nie znaleziono współrzędnych dla miasta: {city_name}")
    return (location.latitude, location.longitude)

def main():
    geolocator = Nominatim(user_agent="distance_script")
    coords = {}

    print("Pobieranie współrzędnych miast...")
    for city in cities:
        coords[city] = get_coordinates(city, geolocator)
        time.sleep(1)

    print("\nMacierz odległości (w km):\n")

    print(" " * 15, end="")
    for c in cities:
        print(f"{c:20s}", end="")
    print()

    for city1 in cities:
        print(f"{city1:15s}", end="")
        for city2 in cities:
            dist_km = geodesic(coords[city1], coords[city2]).kilometers
            print(f"{dist_km:20.1f}", end="")
        print()

if __name__ == "__main__":
    main()
