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

    source_registry = load_json(ROOT / "config/api/fontes_oficiais.json")
    assert source_registry["fontes"]["pncp"]["quantidadeRotas"] == 109
    assert source_registry["fontes"]["pncp"]["quantidadeOperacoes"] == 190

    cnpj_openapi = load_json(ROOT / "docs/cnpj/openapi/api-docs.json")
    assert cnpj_openapi["info"]["version"] == "2.0.2"
    assert set(cnpj_openapi["paths"]) == {
        "/api-cnpj-basica/v2/basica/{CNPJbasica}",
        "/api-cnpj-empresa/v2/empresa/{CNPJempresa}",
        "/api-cnpj-qsa/v2/qsa/{CNPJqsa}",
    }
    cnpj_fields = set(cnpj_openapi["components"]["schemas"]["CNPJempresa"]["properties"])
    required_commercial_fields = {
        "ni",
        "nomeFantasia",
        "situacaoCadastral",
        "naturezaJuridica",
        "dataAbertura",
        "cnaePrincipal",
        "endereco",
        "municipioJurisdicao",
        "telefone",
        "correioEletronico",
        "capitalSocial",
        "porte",
        "situacaoEspecial",
        "dataSituacaoEspecial",
        "socios",
    }
    assert required_commercial_fields <= cnpj_fields
    assert cnpj_openapi["components"]["securitySchemes"]["OAuth2"]["flows"]["clientCredentials"]

    obrasgov_openapi = load_json(ROOT / "docs/obrasgov/openapi/api-docs.json")
    assert obrasgov_openapi["info"]["version"] == "1.0.15"
    assert set(obrasgov_openapi["paths"]) == {
        "/projeto-investimento",
        "/geometria",
        "/execucao-fisica",
        "/execucao-fisica/arquivos-da-intervencao",
        "/execucao-financeira",
        "/execucao-financeira/saldo-contabil",
        "/execucao-financeira/contrato",
    }

    expected_hashes = {
        "docs/pncp_v2.5/manual/manual_integracao_pncp_v2.5.html": "26d5a5cff042faf28c09fd10e9edc32eaeca38f565ea8926699aab932e121449",
        "docs/pncp_v2.5/openapi/api-docs.json": "dfe448f39a3d6602d688465d2159fa75233ac56aa447dee115fbbcd2eb4fe7af",
        "docs/cnpj/openapi/api-docs.json": "e3f913ba260967c5a54e34bd52cdb670045c510fde3be4516fffcb493e258ee5",
        "docs/obrasgov/openapi/api-docs.json": "63ae7fa2e309a3cf58ff22efe2113e28d663443bc9a84654a8428d89dba763f5",
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

    forbidden_directories = [
        ROOT / "data",
        ROOT / "output",
        ROOT / "docs/pncp_v2.5/endpoints",
    ]
    assert not any(path.exists() for path in forbidden_directories)
    assert not (ROOT / "docs/cnpj_api_governo_swagger.json").exists()
    assert not (ROOT / "docs/api-obrasgov-docs.json").exists()
    forbidden_extensions = {".zip", ".xlsx", ".xlsm", ".sqlite", ".db", ".jsonl"}
    assert not any(path.suffix.lower() in forbidden_extensions for path in ROOT.rglob("*") if path.is_file())

    print(
        f"OK: {len(json_paths)} JSONs; 14 eventos; "
        "PNCP 109 rotas/190 operações; CNPJ 3 rotas; "
        "Obrasgov 7 rotas; 3.095 serviços."
    )


if __name__ == "__main__":
    main()
