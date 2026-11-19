"""Builds assets/data/bd_medicines.tsv, the on-device medicine list used by Scan.

Source: "Medicinal Products in Bangladesh - A Dataset of Generic and Brand Names,
Dosage Strengths, and Manufacturers" (Rahman & Khan, University of Dhaka, 2024),
Mendeley Data, DOI 10.17632/zhtvkny53n.1, licence CC BY 4.0.
Download the CSV from https://data.mendeley.com/datasets/zhtvkny53n/1
(sha256 293036d5c24268c6526df4ae9ba59e3d80f40380b79bdf40859c83419b52a8fd), then run:

    python tools/build_medicine_list.py path/to/dataset.csv

Output: one line per brand+generic: brand<TAB>generic<TAB>forms, where forms is
"T:500 mg;250 mg|S:120 mg/5 ml". Form codes match MedicineForm in the app:
T tablet, C capsule, S syrup / oral liquid, I injection, D drops, X other (cream, inhaler...).
A line "#M word word ..." lists the words in company names ("square", "pharmaceuticals"), so
packet scanning does not read the maker's name as a medicine.
"""
import csv
import re
import sys
from collections import OrderedDict
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "data" / "bd_medicines.tsv"
ORAL_LIQUIDS = ("syrup", "oral suspension", "powder for suspension", "oral solution",
                "liquid", "oral emulsion")


def form_code(dosage_type: str) -> str:
    t = dosage_type.lower()
    if "injection" in t or "infusion" in t:
        return "I"
    if "drop" in t or (t.startswith("ophthalmic") and "ointment" not in t):
        return "D"
    if "capsule" in t and "inhalation" not in t and "eye" not in t:
        return "C"
    if "tablet" in t and "vaginal" not in t:
        return "T"
    if t in ORAL_LIQUIDS:
        return "S"
    return "X"


def clean(s: str) -> str:
    return " ".join(s.replace("\t", " ").split())


def main(src: str) -> None:
    groups: "OrderedDict[tuple, OrderedDict]" = OrderedDict()
    company_words = set()
    with open(src, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            brand, generic = clean(row["brandName"]), clean(row["genericName"])
            for w in re.split(r"[^A-Za-z]+", row["manufacturer"]):
                if len(w) >= 3:
                    company_words.add(w.lower())
            if not brand:
                continue
            forms = groups.setdefault((brand, generic), OrderedDict())
            strengths = forms.setdefault(form_code(row["dosageType"]), [])
            s = clean(row["strength"])
            if s and s not in strengths:
                strengths.append(s)
    lines = ["# Source: Medicinal Products in Bangladesh (Rahman & Khan 2024), "
             "Mendeley Data DOI 10.17632/zhtvkny53n.1, CC BY 4.0. Built by tools/build_medicine_list.py",
             "#M " + " ".join(sorted(company_words))]
    for (brand, generic), forms in sorted(groups.items(), key=lambda kv: kv[0][0].lower()):
        packed = "|".join(f"{code}:{';'.join(st)}" for code, st in forms.items())
        lines.append(f"{brand}\t{generic}\t{packed}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(lines) - 1} entries to {OUT}")


if __name__ == "__main__":
    main(sys.argv[1])
