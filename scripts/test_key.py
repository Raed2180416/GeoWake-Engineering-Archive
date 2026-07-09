import requests

key = "REDACTED_ARCHIVE_CREDENTIAL"
address = "Shaheed Sthal (New Bus Adda) Metro Station Ghaziabad"
url = f"https://maps.googleapis.com/maps/api/geocode/json?address={address}&key={key}"

print(f"Testing URL: {url}")

headers = {
    "Referer": "https://www.yometro.com/"
}

try:
    response = requests.get(url, headers=headers)
    print(f"Status: {response.status_code}")
    print(response.text)
except Exception as e:
    print(f"Error: {e}")
