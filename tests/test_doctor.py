import importlib.util
import os
from pathlib import Path


DOCTOR_PATH = Path(__file__).parents[1] / "scripts" / "common" / "doctor.py"
SPEC = importlib.util.spec_from_file_location("wechat_doctor", DOCTOR_PATH)
doctor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(doctor)


def test_read_key_never_returns_secret(tmp_path):
    path = tmp_path / "key.txt"
    secret = "ab" * 32
    path.write_text(secret, encoding="ascii")
    ok, detail = doctor._read_key(str(path))
    assert ok is True
    assert detail == "present (64 hex chars)"
    assert secret not in detail


def test_key_check_warns_on_broad_posix_permissions(tmp_path):
    if os.name == "nt":
        return
    path = tmp_path / "key.txt"
    path.write_text("ab" * 32, encoding="ascii")
    path.chmod(0o644)
    check = doctor._key_check(str(path), "reference.md", check_permissions=True)
    assert check.status == "warn"
    assert "0644" in check.detail
    assert "ab" * 32 not in check.detail

    path.chmod(0o600)
    check = doctor._key_check(str(path), "reference.md", check_permissions=True)
    assert check.status == "ok"


def test_unsupported_platform_stops_platform_checks(monkeypatch, tmp_path):
    monkeypatch.setattr(doctor, "_codex_mcp_check", lambda _path: doctor.Check("mcp", "warn", "none"))
    monkeypatch.setattr(doctor, "_skill_discovery_check", lambda _path: doctor.Check("skill", "warn", "none"))
    checks = doctor.collect_checks(system="Linux", skill_dir=str(tmp_path))
    assert [item.name for item in checks] == ["platform", "python", "skill", "mcp"]
    assert checks[0].status == "fail"
