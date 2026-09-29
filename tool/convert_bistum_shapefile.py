#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import re
import unicodedata
from pathlib import Path
from typing import Iterable, Sequence

import shapefile
from pyproj import Transformer


TITLE_PREFIX_PATTERN = re.compile(
    r"^(Bistum|Erzbistum|Erzdiözese|Dioezese|Diözese|Offizialatsbezirk)\s+",
    re.IGNORECASE,
)

CANONICAL_NAME_OVERRIDES = {
    "offizialatsbezirk oldenburg": "Münster",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Konvertiert ein Bistums-Shapefile nach GeoJSON, reprojiziert nach "
            "EPSG:4326 und reduziert den Attributsatz fuer die App-Laufzeit."
        )
    )
    parser.add_argument(
        "--input",
        default="assets/territorialgrenzen_bistumsatlas/shapefiles/bistum_simp_500m.shp",
        help="Pfad zur SHP-Datei.",
    )
    parser.add_argument(
        "--output",
        default="assets/maps/dioeceses.geojson",
        help="Pfad zur erzeugten GeoJSON-Datei.",
    )
    parser.add_argument(
        "--simplify-percent",
        type=float,
        default=80.0,
        help=(
            "Konfigurierbare Vereinfachungsstaerke von 0 bis 100. 80 ist ein "
            "guter Startwert fuer erste App-Tests."
        ),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    reader = shapefile.Reader(str(input_path))
    fields = [field[0] for field in reader.fields[1:]]
    transformer = Transformer.from_crs("EPSG:25832", "EPSG:4326", always_xy=True)
    simplify_percent = max(0.0, min(100.0, args.simplify_percent))

    aggregated_features: dict[str, dict[str, object]] = {}
    raw_feature_count = 0
    for shape_record in reader.iterShapeRecords():
        record = {
            field: value for field, value in zip(fields, shape_record.record, strict=False)
        }
        polygons = extract_polygons(shape_record.shape, transformer, simplify_percent)
        if not polygons:
            continue
        raw_feature_count += 1

        source_name = first_non_empty(
            record.get("bistum_name"),
            record.get("name"),
            record.get("label"),
            "Unbekannt",
        )
        feature_name = canonicalize_name(source_name)
        feature_id = canonicalize_id(feature_name)

        aggregated_feature = aggregated_features.get(feature_id)
        if aggregated_feature is None:
            aggregated_features[feature_id] = {
                "id": feature_id,
                "name": feature_name,
                "sourceDataset": input_path.stem,
                "sourceNames": {source_name},
                "polygons": polygons,
            }
            continue

        aggregated_feature["sourceNames"].add(source_name)
        aggregated_feature["polygons"].extend(polygons)

    features = []
    for feature_id in sorted(aggregated_features):
        aggregated_feature = aggregated_features[feature_id]
        polygons = aggregated_feature["polygons"]
        properties = {
            "id": aggregated_feature["id"],
            "name": aggregated_feature["name"],
            "sourceDataset": aggregated_feature["sourceDataset"],
        }
        source_names = sorted(aggregated_feature["sourceNames"])
        if source_names != [aggregated_feature["name"]]:
            properties["sourceNames"] = source_names

        geometry_type = "Polygon" if len(polygons) == 1 else "MultiPolygon"
        coordinates = polygons[0] if len(polygons) == 1 else polygons

        features.append(
            {
                "type": "Feature",
                "id": aggregated_feature["id"],
                "properties": properties,
                "geometry": {
                    "type": geometry_type,
                    "coordinates": coordinates,
                },
            }
        )

    feature_collection = {
        "type": "FeatureCollection",
        "features": features,
    }
    output_path.write_text(
        json.dumps(feature_collection, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(
        "GeoJSON geschrieben: "
        f"{output_path} ({len(features)} Features aus {raw_feature_count} Rohobjekten)"
    )


def canonicalize_name(source_name: str) -> str:
    normalized_source_name = normalize_lookup_value(source_name)
    canonical_base_name = CANONICAL_NAME_OVERRIDES.get(normalized_source_name)
    if canonical_base_name is None:
        canonical_base_name = TITLE_PREFIX_PATTERN.sub("", source_name).strip()
    return f"Diözesanverband {canonical_base_name}"


def canonicalize_id(canonical_name: str) -> str:
    transliterated = (
        canonical_name.replace("Ä", "Ae")
        .replace("Ö", "Oe")
        .replace("Ü", "Ue")
        .replace("ä", "ae")
        .replace("ö", "oe")
        .replace("ü", "ue")
        .replace("ß", "ss")
    )
    normalized = unicodedata.normalize("NFKD", transliterated)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_only.lower()).strip("-")
    return slug or "dioezesanverband-unbekannt"


def normalize_lookup_value(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_only.lower()).strip()


def extract_polygons(
    shape: shapefile.Shape,
    transformer: Transformer,
    simplify_percent: float,
) -> list[list[list[list[float]]]]:
    parts = list(shape.parts) + [len(shape.points)]
    rings: list[list[list[float]]] = []
    for start, end in zip(parts, parts[1:], strict=False):
        raw_ring = shape.points[start:end]
        if len(raw_ring) < 4:
            continue
        transformed_ring = [transform_point(point, transformer) for point in raw_ring]
        simplified_ring = simplify_ring(transformed_ring, simplify_percent)
        if len(simplified_ring) < 4:
            continue
        rings.append(simplified_ring)

    polygons: list[list[list[list[float]]]] = []
    current_polygon: list[list[list[float]]] | None = None
    for ring in rings:
        if is_outer_ring(ring) or current_polygon is None:
            current_polygon = [ring]
            polygons.append(current_polygon)
        else:
            current_polygon.append(ring)
    return polygons


def transform_point(point: Sequence[float], transformer: Transformer) -> list[float]:
    lon, lat = transformer.transform(point[0], point[1])
    return [round(lon, 6), round(lat, 6)]


def simplify_ring(ring: list[list[float]], simplify_percent: float) -> list[list[float]]:
    if len(ring) < 5 or simplify_percent <= 0:
        return ensure_closed(ring)

    closed_ring = ensure_closed(ring)
    open_ring = closed_ring[:-1]
    min_lon = min(point[0] for point in open_ring)
    max_lon = max(point[0] for point in open_ring)
    min_lat = min(point[1] for point in open_ring)
    max_lat = max(point[1] for point in open_ring)
    diagonal = math.hypot(max_lon - min_lon, max_lat - min_lat)
    tolerance = diagonal * (simplify_percent / 100.0) * 0.003

    simplified = douglas_peucker(open_ring, tolerance)
    if len(simplified) < 4:
        simplified = open_ring[:]
    return ensure_closed(simplified)


def douglas_peucker(points: list[list[float]], tolerance: float) -> list[list[float]]:
    if len(points) <= 2 or tolerance <= 0:
        return points[:]

    first = points[0]
    last = points[-1]
    max_distance = -1.0
    index = -1
    for current_index in range(1, len(points) - 1):
        distance = perpendicular_distance(points[current_index], first, last)
        if distance > max_distance:
            max_distance = distance
            index = current_index

    if max_distance <= tolerance or index < 0:
        return [first, last]

    left = douglas_peucker(points[: index + 1], tolerance)
    right = douglas_peucker(points[index:], tolerance)
    return left[:-1] + right


def perpendicular_distance(
    point: Sequence[float], start: Sequence[float], end: Sequence[float]
) -> float:
    if start == end:
        return math.hypot(point[0] - start[0], point[1] - start[1])

    numerator = abs(
        (end[1] - start[1]) * point[0]
        - (end[0] - start[0]) * point[1]
        + end[0] * start[1]
        - end[1] * start[0]
    )
    denominator = math.hypot(end[1] - start[1], end[0] - start[0])
    return numerator / denominator


def ensure_closed(points: list[list[float]]) -> list[list[float]]:
    if not points:
        return []
    if points[0] == points[-1]:
        return points[:]
    return points[:] + [points[0]]


def ring_area(ring: Iterable[Sequence[float]]) -> float:
    area = 0.0
    ring_list = list(ring)
    for current, nxt in zip(ring_list, ring_list[1:], strict=False):
        area += current[0] * nxt[1] - nxt[0] * current[1]
    return area / 2.0


def is_outer_ring(ring: list[list[float]]) -> bool:
    return ring_area(ring) < 0


def first_non_empty(*values: object) -> str:
    for value in values:
        text = str(value).strip()
        if text and text.lower() != "none":
            return text
    return ""


if __name__ == "__main__":
    main()