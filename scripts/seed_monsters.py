#!/usr/bin/env python3
"""
seed_monsters.py — Convert yingwu_monsters_100.json to SQL seed.
Python 3 stdlib only: uuid, json, pathlib, sys.
Output: data/seed/0001_monsters.sql
"""
import json
import uuid
import pathlib
import sys

NAMESPACE = uuid.NAMESPACE_DNS

# ── Mappings ──────────────────────────────────────────────────────────────────
THREE_PHASE_MAP = {
    "生機體": "biomorphic",
    "構造體": "tectonic",
    "靈質體": "phantasmal",
}

WUXING_MAP = {
    "金": "metal",
    "木": "wood",
    "水": "water",
    "火": "fire",
    "土": "earth",
}

TRIANGLE_POS_MAP = {
    "執念": "attacker",
    "沉潛": "defender",
    "流變": "support",
}


def esc(s: str) -> str:
    """Escape single quotes for SQL string literals."""
    if s is None:
        return None
    return s.replace("'", "''")


def species_uuid(species_name: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "yingwu.species." + species_name))


def variant_uuid(species_name: str, wuxing_variant: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "yingwu.variant." + species_name + "." + wuxing_variant))


def citiao_uuid(species_name: str, wuxing_variant: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "yingwu.citiao." + species_name + "." + wuxing_variant))


def main():
    repo_root = pathlib.Path(__file__).parent.parent
    json_path = repo_root / "data" / "monsters" / "yingwu_monsters_100.json"
    out_path = repo_root / "data" / "seed" / "0001_monsters.sql"

    out_path.parent.mkdir(parents=True, exist_ok=True)

    with open(json_path, encoding="utf-8") as f:
        records = json.load(f)

    # ── Validate all mappings before generating anything ──────────────────────
    for rec in records:
        for field, mapping in [
            ("three_phase", THREE_PHASE_MAP),
            ("wuxing_variant", WUXING_MAP),
            ("triangle_pos", TRIANGLE_POS_MAP),
        ]:
            val = rec.get(field)
            if val not in mapping:
                print(
                    f"STOP: unknown {field}='{val}' in variant {rec['variant_id']}",
                    file=sys.stderr,
                )
                sys.exit(1)

    # ── Collect unique species (preserve first-seen order) ────────────────────
    species_seen: dict = {}
    for rec in records:
        sn = rec["species_name"]
        if sn not in species_seen:
            species_seen[sn] = rec
    species_list = list(species_seen.values())

    # ── Build SQL ──────────────────────────────────────────────────────────────
    out = []
    out.append("BEGIN;\n")

    # Species
    out.append("-- 25 物種")
    sp_rows = []
    for idx, rec in enumerate(species_list, 1):
        sn = rec["species_name"]
        sid = species_uuid(sn)
        name_en = f"species_{idx:03d}"
        phase = THREE_PHASE_MAP[rec["three_phase"]]
        em = esc(rec["emotion_anchor"])
        sc = esc(rec["scene_anchor"])
        lore = rec.get("shanhaijing_ref")
        lore_sql = f"'{esc(lore)}'" if lore else "NULL"
        sp_rows.append(
            f"  ('{sid}', '{esc(sn)}', '{name_en}', '{phase}', '{em}', '{sc}', {lore_sql})"
        )
    out.append(
        "INSERT INTO monster_species "
        "(id, name_zh, name_en, base_phase, emotion_tag, scene_tag, lore_excerpt) VALUES"
    )
    out.append(",\n".join(sp_rows))
    out.append("ON CONFLICT (name_zh) DO NOTHING;\n")

    # Variants
    out.append("-- 100 變體")
    vr_rows = []
    for rec in records:
        sn = rec["species_name"]
        vid = variant_uuid(sn, rec["wuxing_variant"])
        sid = species_uuid(sn)
        wx = WUXING_MAP[rec["wuxing_variant"]]
        pos = TRIANGLE_POS_MAP[rec["triangle_pos"]]
        art = f"placeholder://{esc(rec['variant_name'])}"
        vr_rows.append(
            f"  ('{vid}', '{sid}', '{wx}', {rec['power_base']}, '{pos}', '{art}')"
        )
    out.append(
        "INSERT INTO monster_variants "
        "(id, species_id, wuxing_attr, power_base, position, art_placeholder) VALUES"
    )
    out.append(",\n".join(vr_rows))
    out.append("ON CONFLICT (species_id, wuxing_attr) DO NOTHING;\n")

    # Ci tiao
    out.append("-- 100 詞條")
    ct_rows = []
    for rec in records:
        sn = rec["species_name"]
        cid = citiao_uuid(sn, rec["wuxing_variant"])
        vid = variant_uuid(sn, rec["wuxing_variant"])
        tiao = esc(rec["ci_tiao_description"])
        verb = esc(rec["ability_verb"])
        ct_rows.append(f"  ('{cid}', '{vid}', '{tiao}', '{verb}')")
    out.append("INSERT INTO ci_tiao_pool (id, variant_id, tiao_text, ability_verb) VALUES")
    out.append(",\n".join(ct_rows))
    out.append(";\n")

    out.append("COMMIT;")

    sql = "\n".join(out) + "\n"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(sql)

    print(f"Written: {out_path}")
    print(f"  species : {len(species_list)}")
    print(f"  variants: {len(records)}")
    print(f"  ci_tiao : {len(records)}")


if __name__ == "__main__":
    main()
