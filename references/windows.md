# Windows setup and key extraction

Read this file only for Windows installation, a missing/invalid key, or re-extraction after WeChat changes.

## Install

From PowerShell in the skill checkout:

```powershell
powershell -File setup.ps1
```

Setup creates `.venv`, installs dependencies, safely creates a junction at `$HOME\.agents\skills\wechat-decrypt`, and registers the `wechat` stdio MCP server with Codex. It does not replace an existing user-skill path.

```powershell
$Python = ".\.venv\Scripts\python.exe"
& $Python scripts\common\doctor.py --json
```

## Extract and decrypt

This flow requires an interactive desktop session. Before running extraction, tell the user it will close WeChat and that they must restart WeChat manually from the desktop when prompted.

```powershell
& $Python scripts\windows\extract_raw_key.py
```

The extractor race-attaches to the desktop-launched `Weixin.exe`, verifies the captured account-wide raw key, and writes `key_windows.txt` with private permissions. It never echoes the key. Do not launch WeChat through SSH, a scheduled task, or a background service; those processes may not open the databases.

After extraction:

```powershell
& $Python scripts\windows\decrypt_all.py
& $Python scripts\common\doctor.py --json
```

`decrypt_all.py` reads `key_windows.txt` by default and builds a plaintext mirror at `decrypted\<account>\db_storage\`. Files are written atomically with private permissions where the platform supports them. Never upload or expose this directory.

## Troubleshooting

- `message_0.db not found`: sign in to WeChat and confirm `Documents\xwechat_files\...\db_storage\message\message_0.db` exists.
- No raw key before timeout: confirm WeChat was manually restarted from the visible desktop after the extractor prompt.
- Decryption yields zero databases: the key is wrong for this device, WeChat changed its format, or the selected account directory is not the active one.
- After a WeChat update: rerun `doctor.py`; repeat extraction only if the current key no longer works.

The extractor locates the SHA-512 implementation dynamically and captures the PBKDF2 HMAC ipad key material at startup. The raw key remains device-specific even for the same WeChat account.
