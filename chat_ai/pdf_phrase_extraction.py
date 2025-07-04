import pdfplumber
import re
import json

pdf_path = "files/00_satzung_der_dpsg_-_stamm_mai_2024.pdf"

def extract_phrases(pdf_path):
    phrases = []
    main_phrase_pattern = re.compile(r'^\d+\.\s')  # Muster zur Erkennung nummerierter Hauptphrasen
    sub_phrase_pattern = re.compile(r'^\d+\.\d+\s|\d+[a-z]*\.\s')  # Muster zur Erkennung nummerierter Unterphrasen und Aufzählungen

    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, start=1):
            if page_num < 3:  # Überspringe die ersten zwei Seiten (Inhaltsverzeichnis)
                continue
            text = page.extract_text()
            if text:
                lines = text.split("\n")
                current_phrase = ""
                for line in lines:
                    if main_phrase_pattern.match(line.strip()):  # Wenn eine nummerierte Hauptphrase erkannt wird
                        if current_phrase:
                            phrases.append(current_phrase.strip())
                        current_phrase = line.strip()
                    elif sub_phrase_pattern.match(line.strip()):  # Wenn eine nummerierte Unterphrase oder Aufzählung erkannt wird
                        current_phrase += " " + line.strip()
                    else:
                        current_phrase += " " + line.strip()
                if current_phrase:
                    phrases.append(current_phrase.strip())

    return phrases

def save_phrases_to_json(phrases, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(phrases, f, ensure_ascii=False, indent=4)

phrases = extract_phrases(pdf_path)
save_phrases_to_json(phrases, 'output/phrases.json')

for phrase in phrases:
    print(f"Phrase: {phrase}")