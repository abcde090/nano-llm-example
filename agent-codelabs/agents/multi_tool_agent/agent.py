"""Track 3 — connecting agents to external tools and APIs (goo.gle/3RxsHIp).

One agent, several real external APIs (all key-free): geocoding, weather
forecasts, currency conversion, plus a pure-Python time tool. Demonstrates
how the model composes tools — e.g. "what's the weather where the Eiffel
Tower is" triggers geocode -> forecast.
"""

import os
from datetime import datetime
from zoneinfo import ZoneInfo

import requests
from google.adk.agents import Agent

MODEL = os.environ.get("ADK_MODEL", "gemini-2.5-flash")


def geocode_place(name: str) -> dict:
    """Resolve a place name to coordinates.

    Args:
        name: Place name, e.g. "Melbourne" or "Yosemite Valley".

    Returns:
        dict with name, country, latitude, longitude, timezone — or an
        "error" key if the place could not be found.
    """
    try:
        geo = requests.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": name, "count": 1},
            timeout=10,
        ).json()
        if not geo.get("results"):
            return {"error": f"place not found: {name}"}
        p = geo["results"][0]
        return {
            "name": p["name"],
            "country": p.get("country", ""),
            "latitude": p["latitude"],
            "longitude": p["longitude"],
            "timezone": p.get("timezone", "UTC"),
        }
    except Exception as exc:
        return {"error": str(exc)}


def get_forecast(latitude: float, longitude: float, days: int) -> dict:
    """Get a daily min/max temperature forecast for coordinates.

    Args:
        latitude: Latitude in decimal degrees.
        longitude: Longitude in decimal degrees.
        days: Number of days to forecast, 1 to 7.

    Returns:
        dict with lists of dates, min and max temperatures in Celsius.
    """
    try:
        days = max(1, min(int(days), 7))
        data = requests.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                "latitude": latitude,
                "longitude": longitude,
                "daily": "temperature_2m_min,temperature_2m_max",
                "forecast_days": days,
                "timezone": "auto",
            },
            timeout=10,
        ).json()["daily"]
        return {
            "dates": data["time"],
            "min_c": data["temperature_2m_min"],
            "max_c": data["temperature_2m_max"],
        }
    except Exception as exc:
        return {"error": str(exc)}


def convert_currency(amount: float, from_code: str, to_code: str) -> dict:
    """Convert an amount between currencies at the latest exchange rate.

    Args:
        amount: The amount to convert.
        from_code: ISO 4217 code, e.g. "USD".
        to_code: ISO 4217 code, e.g. "AUD".

    Returns:
        dict with the converted amount and the rate date, or an "error" key.
    """
    try:
        data = requests.get(
            f"https://api.frankfurter.app/latest",
            params={"amount": amount, "from": from_code.upper(), "to": to_code.upper()},
            timeout=10,
        ).json()
        if "rates" not in data:
            return {"error": str(data)}
        return {"converted": data["rates"], "as_of": data["date"]}
    except Exception as exc:
        return {"error": str(exc)}


def get_current_time(timezone: str) -> dict:
    """Get the current date and time in a timezone.

    Args:
        timezone: IANA timezone name, e.g. "Australia/Sydney".

    Returns:
        dict with the ISO timestamp and weekday, or an "error" key.
    """
    try:
        now = datetime.now(ZoneInfo(timezone))
        return {"iso": now.isoformat(timespec="seconds"), "weekday": now.strftime("%A")}
    except Exception as exc:
        return {"error": f"unknown timezone '{timezone}': {exc}"}


root_agent = Agent(
    name="travel_desk",
    model=MODEL,
    description="Travel helper: places, forecasts, currencies, local time.",
    instruction=(
        "You are a travel desk assistant. Compose your tools:\n"
        "- resolve places with geocode_place before asking for a forecast\n"
        "- use get_forecast for weather over multiple days\n"
        "- use convert_currency for money questions\n"
        "- use get_current_time for local-time questions\n"
        "Summarise tool output in friendly prose; never dump raw JSON."
    ),
    tools=[geocode_place, get_forecast, convert_currency, get_current_time],
)
