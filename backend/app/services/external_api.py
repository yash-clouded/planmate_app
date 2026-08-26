"""
External API service — real integrations for hotels, movies, restaurants, payments, etc.
"""

import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class ExternalApiService:
    """Service for calling external APIs."""

    async def search_restaurants(self, params: dict) -> dict:
        """
        Search restaurants using Google Places API.
        Requires GOOGLE_PLACES_API_KEY in env vars.
        """
        location = params.get("location", "")
        cuisine = params.get("cuisine", "")
        budget = params.get("budget", "mid")
        headcount = params.get("headcount", 4)

        api_key = getattr(settings, "google_places_api_key", None)
        if not api_key:
            return self._mock_restaurants(location, cuisine, budget)

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # First, geocode the location
                geo_resp = await client.get(
                    "https://maps.googleapis.com/maps/api/geocode/json",
                    params={"address": location, "key": api_key},
                )
                geo_data = geo_resp.json()
                if geo_data.get("results"):
                    lat = geo_data["results"][0]["geometry"]["location"]["lat"]
                    lng = geo_data["results"][0]["geometry"]["location"]["lng"]

                    # Search for restaurants
                    places_resp = await client.get(
                        "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
                        params={
                            "location": f"{lat},{lng}",
                            "radius": 2000,
                            "type": "restaurant",
                            "keyword": cuisine if cuisine else "restaurant",
                            "key": api_key,
                        },
                    )
                    places_data = places_resp.json()

                    results = []
                    for place in places_data.get("results", [])[:5]:
                        price_level = place.get("price_level", 2)
                        price_map = {0: "budget", 1: "budget", 2: "mid", 3: "premium", 4: "premium"}
                        results.append({
                            "name": place.get("name", "Unknown"),
                            "cuisine": cuisine or "Multi-cuisine",
                            "price_level": price_map.get(price_level, "mid"),
                            "price_for_two": (price_level + 1) * 500,
                            "rating": place.get("rating", 4.0),
                            "details": place.get("vicinity", location),
                            "image_url": place.get("photos", [{}])[0].get("photo_reference", ""),
                        })

                    return {"results": results, "location": location}
        except Exception as e:
            logger.error(f"Google Places API failed: {e}")

        return self._mock_restaurants(location, cuisine, budget)

    def _mock_restaurants(self, location: str, cuisine: str, budget: str) -> dict:
        """Fallback mock restaurants when API key is not set."""
        return {
            "results": [
                {
                    "name": f"The {location} Kitchen",
                    "cuisine": cuisine or "Multi-cuisine",
                    "price_for_two": 800 if budget == "budget" else 1200,
                    "rating": 4.3,
                    "details": "Indoor seating, family-friendly",
                    "image_url": "",
                },
                {
                    "name": f"{location} Spice House",
                    "cuisine": cuisine or "North Indian",
                    "price_for_two": 1000 if budget == "budget" else 1500,
                    "rating": 4.6,
                    "details": "Rooftop dining, live music",
                    "image_url": "",
                },
            ],
            "location": location,
        }

    async def search_hotels(self, params: dict) -> dict:
        """
        Search hotels using Google Places API or mock data.
        Requires GOOGLE_PLACES_API_KEY in env vars.
        """
        location = params.get("location", "Unknown")
        budget = params.get("budget_per_night", 3000)

        api_key = getattr(settings, "google_places_api_key", None)
        if not api_key:
            return self._mock_hotels(location, budget)

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                geo_resp = await client.get(
                    "https://maps.googleapis.com/maps/api/geocode/json",
                    params={"address": location, "key": api_key},
                )
                geo_data = geo_resp.json()
                if geo_data.get("results"):
                    lat = geo_data["results"][0]["geometry"]["location"]["lat"]
                    lng = geo_data["results"][0]["geometry"]["location"]["lng"]

                    places_resp = await client.get(
                        "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
                        params={
                            "location": f"{lat},{lng}",
                            "radius": 5000,
                            "type": "lodging",
                            "key": api_key,
                        },
                    )
                    places_data = places_resp.json()

                    results = []
                    for place in places_data.get("results", [])[:5]:
                        price_level = place.get("price_level", 2)
                        price = (price_level + 1) * 1000
                        results.append({
                            "name": place.get("name", "Hotel"),
                            "price": min(price, budget),
                            "image_url": place.get("photos", [{}])[0].get("photo_reference", ""),
                            "details": place.get("vicinity", location),
                            "rating": place.get("rating", 4.0),
                        })

                    return {"results": results, "location": location}
        except Exception as e:
            logger.error(f"Hotel search failed: {e}")

        return self._mock_hotels(location, budget)

    def _mock_hotels(self, location: str, budget: int) -> dict:
        """Fallback mock hotels."""
        return {
            "results": [
                {
                    "name": f"Hotel {location} View",
                    "price": budget,
                    "image_url": "",
                    "details": f"2 nights, AC, WiFi",
                    "rating": 4.2,
                },
                {
                    "name": f"{location} Grand Resort",
                    "price": int(budget * 1.3),
                    "image_url": "",
                    "details": "2 nights, breakfast included",
                    "rating": 4.5,
                },
            ],
            "location": location,
        }

    async def search_movies(self, params: dict) -> dict:
        """
        Search movies using TMDB API.
        Requires TMDB_API_KEY in env vars.
        """
        city = params.get("city", "")
        date = params.get("date", "")

        api_key = getattr(settings, "tmdb_api_key", None)
        if not api_key:
            return self._mock_movies(city, date)

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Search for popular movies
                resp = await client.get(
                    "https://api.themoviedb.org/3/movie/now_playing",
                    params={"api_key": api_key, "language": "en-US", "page": 1},
                )
                data = resp.json()

                results = []
                for movie in data.get("results", [])[:10]:
                    results.append({
                        "title": movie.get("title", "Unknown"),
                        "overview": movie.get("overview", "")[:100],
                        "rating": movie.get("vote_average", 0.0),
                        "poster_path": movie.get("poster_path", ""),
                        "release_date": movie.get("release_date", ""),
                    })

                return {
                    "results": results,
                    "city": city,
                    "date": date,
                }
        except Exception as e:
            logger.error(f"TMDB API failed: {e}")

        return self._mock_movies(city, date)

    def _mock_movies(self, city: str, date: str) -> dict:
        """Fallback mock movies."""
        return {
            "results": [
                {
                    "title": f"Blockbuster Movie in {city}",
                    "overview": "An exciting adventure...",
                    "rating": 4.5,
                    "poster_path": "",
                    "release_date": date or "2025-01-01",
                },
                {
                    "title": "Comedy Night Special",
                    "overview": "Laugh out loud...",
                    "rating": 4.2,
                    "poster_path": "",
                    "release_date": date or "2025-01-01",
                },
            ],
            "city": city,
            "date": date,
        }

    async def generate_razorpay_payment_link(self, params: dict) -> dict:
        """
        Generate Razorpay payment link.
        Requires RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in env vars.
        """
        amount = params.get("amount", 0)
        description = params.get("description", "PlanMate Booking")
        split_count = params.get("split_count", 1)

        razorpay_key_id = getattr(settings, "razorpay_key_id", None)
        razorpay_key_secret = getattr(settings, "razorpay_key_secret", None)

        if not razorpay_key_id or not razorpay_key_secret:
            # Fallback to UPI link
            per_person = amount // split_count if split_count > 0 else amount
            return {
                "payment_url": f"upi://pay?pa=planmate@upi&pn=PlanMate&am={per_person}&tn={description}",
                "amount": amount,
                "per_person": per_person,
                "split_count": split_count,
                "description": description,
                "status": "upi_link",
            }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    "https://api.razorpay.com/v1/payment_links",
                    auth=(razorpay_key_id, razorpay_key_secret),
                    json={
                        "amount": amount * 100,  # Razorpay uses paise
                        "currency": "INR",
                        "description": description,
                        "reminder_enable": True,
                    },
                )
                data = resp.json()
                return {
                    "payment_url": data.get("short_url", ""),
                    "amount": amount,
                    "per_person": amount // split_count if split_count > 0 else amount,
                    "split_count": split_count,
                    "description": description,
                    "status": "razorpay_link",
                }
        except Exception as e:
            logger.error(f"Razorpay API failed: {e}")
            per_person = amount // split_count if split_count > 0 else amount
            return {
                "payment_url": f"upi://pay?pa=planmate@upi&pn=PlanMate&am={per_person}&tn={description}",
                "amount": amount,
                "per_person": per_person,
                "split_count": split_count,
                "description": description,
                "status": "upi_link_fallback",
            }


# Global instance
external_api = ExternalApiService()
