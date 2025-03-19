import json
import requests
from dotenv import load_dotenv

# Lade die Umgebungsvariablen aus der .env-Datei
load_dotenv()

API_KEY = ""
API_URL = "https://api.openai.com/v1/embeddings"
INPUT_FILE = "../assets/ai_kontext/satzung_stamm_2024.json"
OUTPUT_FILE = "../assets/ai_kontext/satzung_stamm_2024_embeddings.json"

def get_embedding(text):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }
    data = {
        "model": "text-embedding-ada-002",
        "input": text,
    }
    response = requests.post(API_URL, headers=headers, json=data)
    response_data = response.json()
    print (response_data)
    return response_data["data"][0]["embedding"]

def main():
    print ("Start")
    print (API_KEY)
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        phrases = json.load(f)

    embeddings = []
    for phrase in phrases:
        embedding = get_embedding(phrase)
        embeddings.append({"text": phrase, "vector": embedding})

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(embeddings, f, ensure_ascii=False, indent=4)


main()