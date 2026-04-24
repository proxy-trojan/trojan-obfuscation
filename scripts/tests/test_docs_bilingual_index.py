import pathlib

DOCS = pathlib.Path("docs")
README = DOCS / "README.md"

REQUIRED_DOCS = [
    DOCS / "zh-CN" / "quickstart.md",
    DOCS / "en" / "quickstart.md",
    DOCS / "zh-CN" / "install-kernel.md",
    DOCS / "en" / "install-kernel.md",
    DOCS / "zh-CN" / "config-generation.md",
    DOCS / "en" / "config-generation.md",
    DOCS / "ops" / "branch-cleanup.md",
]

REQUIRED_TOPICS = [
    "install command",
    "acme",
    "dns",
    "80",
    "443",
    "config generation",
    "client import",
    "rule update",
]


def test_bilingual_entrypoints_and_ops_runbook_exist() -> None:
    for path in REQUIRED_DOCS:
        assert path.exists(), f"missing doc: {path}"


def test_docs_readme_has_bilingual_entrypoints_and_script_index() -> None:
    text = README.read_text(encoding="utf-8")

    assert "zh-CN/quickstart.md" in text
    assert "en/quickstart.md" in text
    assert "zh-CN/install-kernel.md" in text
    assert "en/install-kernel.md" in text
    assert "zh-CN/config-generation.md" in text
    assert "en/config-generation.md" in text
    assert "ops/branch-cleanup.md" in text
    assert "scripts/install/install-kernel.sh" in text
    assert "scripts/config/generate-client-bundle.py" in text


def test_required_topics_appear_in_quickstart_and_config_docs() -> None:
    corpus = "\n".join(
        path.read_text(encoding="utf-8").lower()
        for path in [
            DOCS / "zh-CN" / "quickstart.md",
            DOCS / "en" / "quickstart.md",
            DOCS / "zh-CN" / "config-generation.md",
            DOCS / "en" / "config-generation.md",
            DOCS / "zh-CN" / "install-kernel.md",
            DOCS / "en" / "install-kernel.md",
        ]
    )

    for topic in REQUIRED_TOPICS:
        assert topic in corpus, f"missing topic marker: {topic}"
