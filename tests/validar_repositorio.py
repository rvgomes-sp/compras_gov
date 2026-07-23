from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path):
    with path.open("r", encoding="utf-8-sig") as stream:
        return json.load(stream)


def main() -> None:
    json_paths = sorted(ROOT.rglob("*.json"))
    for path in json_paths:
        load_json(path)

    event_map = load_json(ROOT / "config/governanca/event_data_map.json")
    assert list(event_map["events"]) == [f"EVT-{number:03d}" for number in range(1, 15)]

    openapi = load_json(ROOT / "docs/pncp_v2.5/openapi/api-docs.json")
    assert len(openapi["paths"]) == 109
    methods = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}
    operations = sum(
        1
        for path_item in openapi["paths"].values()
        for method in path_item
        if method.lower() in methods
    )
    assert operations == 190

    expected_hashes = {
        "docs/pncp_v2.5/manual/manual_integracao_pncp_v2.5.html": "26d5a5cff042faf28c09fd10e9edc32eaeca38f565ea8926699aab932e121449",
        "docs/pncp_v2.5/openapi/api-docs.json": "dfe448f39a3d6602d688465d2159fa75233ac56aa447dee115fbbcd2eb4fe7af",
        "docs/catalogo_compras_gov/fontes/catser_20260718.csv": "f3cd884220115be97fd7782a25e799d8c64390786794d27c3fef53806e67f264",
    }
    for relative, expected in expected_hashes.items():
        assert sha256(ROOT / relative) == expected, relative

    with (ROOT / "docs/catalogo_compras_gov/fontes/catser_20260718.csv").open(
        "r", encoding="utf-8-sig", newline=""
    ) as stream:
        rows = list(csv.DictReader(stream, delimiter=";"))
    assert len(rows) == 3095
    assert sum(row["statusServico"] == "True" for row in rows) == 3013

    runtime = load_json(ROOT / "config/comercial/catalogo_servicos.json")
    assert len(runtime) == 164
    by_code = {row["catalogoCodigoItem"]: row for row in runtime}
    for code in ("8729", "14397", "5380"):
        assert by_code[code]["status"] == "APROVADO"
        assert by_code[code]["statusServico"] is True

    forbidden_directories = [ROOT / "data", ROOT / "output"]
    assert not any(path.exists() for path in forbidden_directories)
    forbidden_extensions = {".zip", ".xlsx", ".xlsm", ".sqlite", ".db", ".jsonl"}
    assert not any(path.suffix.lower() in forbidden_extensions for path in ROOT.rglob("*") if path.is_file())

    print(f"OK: {len(json_paths)} JSONs; 14 eventos; 109 rotas; 190 operações; 3.095 serviços.")


if __name__ == "__main__":
    main()
