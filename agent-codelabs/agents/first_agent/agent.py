"""Track 1 — your first ADK agent (goo.gle/4ftubfR).

A single agent with one custom function tool. The pattern to notice: the
tool's docstring is the contract — ADK parses it so the model knows when and
how to call the function.
"""

import os

import requests
from google.adk.agents import Agent

MODEL = os.environ.get("ADK_MODEL", "gemini-2.5-flash")


def get_current_weather(city: str) -> dict:
    """Get the current weather for a city, anywhere in the world.

    Args:
        city: City name, e.g. "Sydney" or "San Francisco".

    Returns:
        dict with the resolved location, temperature in Celsius, wind speed
        in km/h, or an "error" key if the city could not be found.
    """
    try:
        geo = requests.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": city, "count": 1},
            timeout=10,
        ).json()
        if not geo.get("results"):
            return {"error": f"city not found: {city}"}
        place = geo["results"][0]
        wx = requests.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                "latitude": place["latitude"],
                "longitude": place["longitude"],
                "current_weather": True,
            },
            timeout=10,
        ).json()["current_weather"]
        return {
            "location": f"{place['name']}, {place.get('country', '')}".strip(", "),
            "temperature_c": wx["temperature"],
            "windspeed_kmh": wx["windspeed"],
        }
    except Exception as exc:
        return {"error": str(exc)}


root_agent = Agent(
    name="weather_assistant",
    model=MODEL,
    description="Answers questions about current weather.",
    instruction=(
        "You are a friendly weather assistant. Use the get_current_weather "
        "tool for any weather question. Report temperatures in both Celsius "
        "and Fahrenheit. If the user asks anything non-weather, answer "
        "briefly without tools."
    ),
    tools=[get_current_weather],
)
