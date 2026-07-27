#!/usr/bin/env python3
"""One-shot generator for all remaining catalog building blueprints."""
import json, os

BASE = "game/content/core/buildings"

ERA_MATERIAL = {
    "tent": "thatch", "earth": "earth", "clay": "clay",
    "wood": "wood", "stone": "stone", "brick": "brick",
}

# IDs that already have .gdbuilding.json files
EXISTING = {
    "campfire", "cook_campfire", "entrance_sign", "settlement_flag",
    "tent", "warehouse",
    "tent_shelter", "dugout", "earth_cottage", "clay_cottage",
    "timber_house", "stone_house", "brick_house",
}

# (id, name, category, subfolder, size, function, properties, style)
# function = zone function id (without core: prefix), or "" for no area
# kitchen uses "workplace" with profession=cook to avoid fire_source requirement
BUILDINGS = [
    # --- Housing (tent era) ---
    ("straw_tent", "Соломенная палатка", "tent", "housing", 4,
     "housing", {"residents": 4}, "surface"),
    ("tarp_tent", "Брезентовая палатка", "tent", "housing", 4,
     "housing", {"residents": 4}, "surface"),
    # --- Housing (earth) ---
    ("earth_house", "Земляной дом", "earth", "housing", 5,
     "housing", {"residents": 6}, "surface"),
    # --- Housing (clay) ---
    ("clay_house", "Глиняный дом", "clay", "housing", 5,
     "housing", {"residents": 6}, "surface"),
    # --- Housing (wood) ---
    ("house", "Деревянный дом", "wood", "housing", 6,
     "housing", {"residents": 8}, "surface"),
    ("house_lvl2", "Деревянный дом ур. 2", "wood", "housing", 6,
     "housing", {"residents": 10}, "surface"),
    ("house_lvl3", "Деревянный дом ур. 3", "wood", "housing", 6,
     "housing", {"residents": 12}, "surface"),
    # --- Forager camps ---
    ("straw_forager_tent", "Соломенная палатка собирателя", "tent", "forager", 3,
     "forager_camp", {"profession": "forager", "max_workers": 2}, "surface"),
    ("tarp_forager_tent", "Брезентовая палатка собирателя", "tent", "forager", 3,
     "forager_camp", {"profession": "forager", "max_workers": 2}, "surface"),
    # --- Storage ---
    ("straw_warehouse", "Склад с соломенным навесом", "tent", "storage", 5,
     "storage", {"capacity": 200}, "surface"),
    ("tarp_warehouse", "Склад с брезентовым навесом", "tent", "storage", 5,
     "storage", {"capacity": 200}, "surface"),
    ("straw_materials_yard", "Соломенный двор материалов", "tent", "storage", 4,
     "storage", {"capacity": 150}, "surface"),
    ("tarp_materials_yard", "Брезентовый двор материалов", "tent", "storage", 4,
     "storage", {"capacity": 150}, "surface"),
    # --- Workshops ---
    ("straw_craft_tent", "Соломенная ремесленная палатка", "tent", "workshop", 3,
     "workshop", {"profession": "craftsman", "max_workers": 2}, "surface"),
    ("tarp_craft_tent", "Брезентовая ремесленная палатка", "tent", "workshop", 3,
     "workshop", {"profession": "craftsman", "max_workers": 2}, "surface"),
    ("smithy", "Кузница", "earth", "workshop", 4,
     "workshop", {"profession": "craftsman", "max_workers": 3}, "surface"),
    ("hide_worker", "Кожевенная мастерская", "earth", "workshop", 4,
     "workshop", {"profession": "craftsman", "max_workers": 3}, "surface"),
    ("clay_workshop", "Глиняная мастерская", "clay", "workshop", 4,
     "workshop", {"profession": "craftsman", "max_workers": 3}, "surface"),
    ("masonry_workshop", "Каменотёсная мастерская", "stone", "workshop", 5,
     "workshop", {"profession": "craftsman", "max_workers": 4}, "surface"),
    ("sawmill", "Лесопилка", "wood", "workshop", 5,
     "workshop", {"profession": "craftsman", "max_workers": 4}, "surface"),
    ("brick_factory", "Кирпичный завод", "brick", "workshop", 5,
     "workshop", {"profession": "craftsman", "max_workers": 4}, "surface"),
    ("materials_factory", "Фабрика материалов", "brick", "workshop", 5,
     "workshop", {"profession": "craftsman", "max_workers": 4}, "surface"),
    # --- Markets ---
    ("straw_trade_tent", "Соломенный торговый шатёр", "tent", "market", 3,
     "market", {"profession": "seller", "max_workers": 2}, "surface"),
    ("tarp_trade_tent", "Брезентовый торговый шатёр", "tent", "market", 3,
     "market", {"profession": "seller", "max_workers": 2}, "surface"),
    ("earth_market", "Земляной рынок", "earth", "market", 4,
     "market", {"profession": "seller", "max_workers": 3}, "surface"),
    ("clay_market", "Глиняный рынок", "clay", "market", 4,
     "market", {"profession": "seller", "max_workers": 3}, "surface"),
    ("stone_market", "Каменный рынок", "stone", "market", 5,
     "market", {"profession": "seller", "max_workers": 4}, "surface"),
    ("wood_market", "Деревянный рынок", "wood", "market", 5,
     "market", {"profession": "seller", "max_workers": 4}, "surface"),
    ("brick_market", "Кирпичный рынок", "brick", "market", 5,
     "market", {"profession": "seller", "max_workers": 4}, "surface"),
    # --- Kitchen (using workplace to avoid fire_source requirement) ---
    ("cook_campfire_lvl2", "Костёр для готовки ур. 2", "tent", "kitchen", 3,
     "workplace", {"profession": "cook", "max_workers": 2}, "surface"),
    ("cook_campfire_lvl3", "Костёр для готовки ур. 3", "tent", "kitchen", 3,
     "workplace", {"profession": "cook", "max_workers": 3}, "surface"),
    ("dugout_kitchen", "Земляная кухня", "earth", "kitchen", 4,
     "workplace", {"profession": "cook", "max_workers": 3}, "surface"),
    ("canteen", "Столовая", "wood", "kitchen", 5,
     "workplace", {"profession": "cook", "max_workers": 4}, "surface"),
    ("clay_bakery", "Глиняная пекарня", "clay", "kitchen", 4,
     "workplace", {"profession": "cook", "max_workers": 3}, "surface"),
    ("brick_restaurant", "Кирпичный ресторан", "brick", "kitchen", 5,
     "workplace", {"profession": "cook", "max_workers": 4}, "surface"),
    # --- Civic ---
    ("campfire_lvl2", "Главный костёр ур. 2", "tent", "civic", 3,
     "civic", {"profession": "official", "max_workers": 2}, "surface"),
    ("campfire_lvl3", "Главный костёр ур. 3", "tent", "civic", 3,
     "civic", {"profession": "official", "max_workers": 3}, "surface"),
    ("earth_assembly", "Земляное собрание", "earth", "civic", 5,
     "civic", {"profession": "official", "max_workers": 3}, "surface"),
    ("clay_lodge", "Глиняная управа", "clay", "civic", 5,
     "civic", {"profession": "official", "max_workers": 3}, "surface"),
    ("stone_prefecture", "Каменная префектура", "stone", "civic", 6,
     "civic", {"profession": "official", "max_workers": 4}, "surface"),
    ("wood_town_hall", "Деревянная ратуша", "wood", "civic", 5,
     "civic", {"profession": "official", "max_workers": 4}, "surface"),
    ("brick_city_hall", "Кирпичная ратуша", "brick", "civic", 7,
     "civic", {"profession": "official", "max_workers": 5}, "surface"),
    ("builders_guild", "Гильдия строителей", "stone", "civic", 5,
     "civic", {"profession": "official", "max_workers": 3}, "surface"),
    ("construction_company", "Строительная фирма", "brick", "civic", 5,
     "civic", {"profession": "official", "max_workers": 4}, "surface"),
    ("employment_office", "Служба занятости", "brick", "civic", 5,
     "civic", {"profession": "official", "max_workers": 3}, "surface"),
    # --- School ---
    ("school", "Школа", "clay", "school", 4,
     "school", {"profession": "teacher", "max_workers": 2}, "surface"),
    # --- Leisure ---
    ("gathering_place", "Бадминтонная площадка", "tent", "leisure", 4,
     "leisure", {"flavour": "sports_field", "visitors": 4}, "surface"),
    ("park", "Парк", "wood", "leisure", 5,
     "leisure", {"flavour": "park", "visitors": 8}, "surface"),
    ("stone_tavern", "Каменный трактир", "stone", "leisure", 5,
     "leisure", {"flavour": "plaza", "visitors": 8}, "surface"),
    # --- Farm ---
    ("farm", "Ферма", "wood", "workshop", 5,
     "workplace", {"profession": "craftsman", "max_workers": 4}, "surface"),
    # --- Utility (dew collectors, boundary posts, toilets) ---
    ("dew_collector", "Сборщик росы", "tent", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("advanced_dew_collector", "Улучшенный сборщик росы", "tent", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("boundary_post", "Столб границы", "tent", "utility", 1,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    # Toilets
    ("toilet_tent", "Соломенный общественный туалет", "tent", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("tarp_toilet", "Брезентовый общественный туалет", "tent", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_earth", "Земляной туалет ур. 1", "earth", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_earth_lvl2", "Земляной туалет ур. 2", "earth", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_earth_lvl3", "Земляной туалет ур. 3", "earth", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_clay", "Глиняный туалет ур. 1", "clay", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_clay_lvl2", "Глиняный туалет ур. 2", "clay", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_clay_lvl3", "Глиняный туалет ур. 3", "clay", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_wood", "Деревянный туалет ур. 1", "wood", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_wood_lvl2", "Деревянный туалет ур. 2", "wood", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_wood_lvl3", "Деревянный туалет ур. 3", "wood", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_stone", "Каменный туалет ур. 1", "stone", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_stone_lvl2", "Каменный туалет ур. 2", "stone", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_stone_lvl3", "Каменный туалет ур. 3", "stone", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_brick", "Кирпичный туалет ур. 1", "brick", "utility", 2,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_brick_lvl2", "Кирпичный туалет ур. 2", "brick", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
    ("toilet_brick_lvl3", "Кирпичный туалет ур. 3", "brick", "utility", 3,
     "workplace", {"profession": "craftsman", "max_workers": 1}, "surface"),
]


def make_blueprint(bid, name, category, subfolder, size, func, props, style):
    material = ERA_MATERIAL[category]
    blocks = []
    for x in range(size):
        for z in range(size):
            blocks.append({
                "pos": [x, 0, z],
                "block_id": "slab",
                "material_id": material,
                "rot": 0,
                "variant": "0.25",
            })

    door_x = size / 2.0
    areas = []
    if func:
        areas.append({
            "id": "main",
            "name": "Помещение",
            "role": "room",
            "function": f"core:{func}",
            "properties": props,
            "rects": [[0, 0, size, size]],
            "y": [0, 2],
        })

    data = {
        "version": 6,
        "id": bid,
        "role": bid,
        "name": name,
        "construction_style": style,
        "category": category,
        "fallback_building_id": bid,
        "grid_bounds": {"x": size, "y": 1, "z": size},
        "footprint": [size, size],
        "blocks": blocks,
        "objects": [],
        "fixtures": [],
        "areas": areas,
        "anchors": [
            {
                "id": "front_door",
                "role": "door",
                "pos": [door_x, 0, 0],
                "facing": 180,
                "allow": ["visitor", "staff", "owner", "builder"],
            }
        ],
        "routes": [],
    }
    return data


def main():
    created = 0
    skipped = 0
    for bid, name, cat, sub, size, func, props, style in BUILDINGS:
        if bid in EXISTING:
            skipped += 1
            continue
        out_dir = os.path.join(BASE, sub)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, f"{bid}.gdbuilding.json")
        if os.path.exists(path):
            skipped += 1
            continue
        data = make_blueprint(bid, name, cat, sub, size, func, props, style)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent="\t", ensure_ascii=False)
        created += 1
        print(f"Created {path} ({size}x{size})")
    print(f"\nTotal: {created} created, {skipped} skipped")


if __name__ == "__main__":
    main()
