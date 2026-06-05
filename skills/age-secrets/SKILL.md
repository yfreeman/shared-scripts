---
name: age-secrets
description: Manage age-encrypted secrets shared across repos and devices via SSH-key recipient groups (the age-store). Use when adding/rotating a device key, onboarding a repo's secrets, encrypting or decrypting a .age file, or fixing "age: no identity matched any of the recipients". Triggers on age-store, .age-secrets, age-reencrypt, recipients.txt/groups.conf, or "a container/device can't decrypt the .age file".
allowed-tools: Bash, Read, Edit
---

# age-secrets — shared age secret management

Secrets across these repos are `age`-encrypted to **SSH public keys**, grouped
by access level. The source of truth is the **age-store** (in `shared-scripts/age-store/`):
`keys/<name>.pub` (inventory) + `groups.conf` (group → key names). Each repo
declares file→group mapping in a root `.age-secrets` manifest. CLI tools live on
`PATH`: `age-recipients`, `age-encrypt`, `age-decrypt`, `age-reencrypt`.

Full reference: `shared-scripts/age-store/README.md` — read it before non-trivial changes.

## Three rules you must hold in mind

1. **Public keys matter only at encrypt time.** Decryption needs only the
   caller's own private key.
2. **Re-encrypting requires decrypting first** → only a device that is ALREADY a
   recipient can do it (normally the user's laptop, key `~/.ssh/id_ed25519`).
   A new device cannot add itself. NEVER try to re-encrypt from a device that
   can't already decrypt the file — it will fail by design.
3. The recipient list is **per-person**, not per-repo/per-device. Repos hold
   ciphertext + a `.age-secrets` manifest only; no keys.

## Common tasks

**Diagnose "no identity matched any of the recipients":** the file isn't
encrypted to that device's key. Confirm the device's pubkey is in
`age-store/keys/`, that the file's group in `.age-secrets` includes that key
name in `groups.conf`, then re-encrypt (from a current recipient).

**Add a device (from the laptop):**
```bash
cp <device>.pub shared-scripts/age-store/keys/<name>.pub
# edit shared-scripts/age-store/groups.conf — add <name> to the right group(s)
age-reencrypt <repo-dir>          # for each repo whose secrets use that group
```
Commit the store change and the re-encrypted `.age` files; the device then pulls
and decrypts with its own key.

**Encrypt a new secret:** `age-encrypt <file> <group>` → `<file>.age`, then add
`<relpath> <group>` to that repo's `.age-secrets`.

**Decrypt to inspect:** `age-decrypt <file>.age` (uses `~/.ssh/id_ed25519`, or
`AGE_IDENTITY=<key>`). In a container, pass its key: `age -d -i ~/.ssh/<key> file.age`.

**Rotate after editing the store:** `age-reencrypt <repo-dir>` re-encrypts every
secret in that repo's manifest to current group keys (streams decrypt→encrypt,
no plaintext to disk; verifies each round-trips before swapping).

## Guardrails

- Run encrypt/rotate operations from the laptop (a recipient of every group),
  unless you've confirmed the current device's key is a recipient of the
  specific file.
- Don't hand-edit `.age` files or call `age -R <single-key>` directly — that
  silently drops the other recipients. Always go through a group.
- Don't print decrypted secret values into logs/output.
- After changing `groups.conf` or `keys/`, the affected repos are stale until
  `age-reencrypt` runs and the new `.age` files are committed.
