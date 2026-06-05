# age-store — shared secret recipients

Single source of truth for **which keys can decrypt which secrets**, across
every repo and device. Secrets are [`age`](https://age-encryption.org)-encrypted
to **SSH public keys** (the ones you already have — no separate age keypairs).
This directory defines the keys and the access groups; the `age-*` helpers in
`../bin` (on `PATH` via the repo's `.rc`) encrypt, decrypt, and rotate.

## The three facts that explain the whole design

1. **Recipients (public keys) are only needed to _encrypt_.** Decryption needs
   only _your own_ private key — never the list.
2. **Re-encrypting requires decrypting first**, so it can only run on a device
   whose key is _already_ a recipient. A new device is added by an existing
   recipient (your laptop); it can't bootstrap itself.
3. So the recipient list is **per-person**, not per-device and not per-repo.
   Devices _contribute_ a pubkey to it; repos _declare_ which group each of
   their secrets belongs to. Neither owns a separate copy of the keys.

## Layout

```
age-store/
├── keys/                 # inventory: one SSH pubkey per device, named
│   ├── laptop-dotdashmdp.pub
│   ├── box-root.pub
│   └── globe-dev-pinc.pub
├── groups.conf           # group  =  key-name  key-name  ...   (membership by name)
└── README.md             # this file

../shell/age-{recipients,encrypt,decrypt,reencrypt}.sh   # implementations
../bin/age-{recipients,encrypt,decrypt,reencrypt}        # PATH wrappers
```

A key string is written **once** (in `keys/<name>.pub`). Groups reference it by
name, so rotating a key touches one file and adding a device touches one line.

## Groups (current)

| Group | Members | Holds |
|---|---|---|
| `corp` | laptop, box-root, globe-dev-pinc | work secrets — VPN/Okta creds, Vault env, ivy `pass` store |
| `personal` | laptop | personal secrets — **never** the corp container |

Least privilege: the corp container is in `corp` but not `personal`, so it can
never decrypt personal key material.

## Per-repo manifest: `.age-secrets`

Each repo that has secrets declares which file maps to which group, in a
`.age-secrets` file in its root:

```
# <relative-path>            <group>
server/secrets/env.age       corp
secrets-bundle.tar.age       corp
ivy-config.toml.age          corp
```

`age-reencrypt` reads this to rotate every secret in the repo to its group's
current keys. The manifest lists _intent_ (file → group); it contains no keys.

## Commands

| Command | Does |
|---|---|
| `age-recipients <group>` | print the group's pubkeys (one per line) |
| `age-encrypt <file> <group>` | encrypt `<file>` to `<group>` → `<file>.age` |
| `age-decrypt <file.age> [identity]` | decrypt with your key (default `~/.ssh/id_ed25519`) |
| `age-reencrypt [repo-dir]` | re-encrypt every secret in the repo's `.age-secrets` to current keys |

Override the store location with `AGE_STORE=/path`; the decrypt identity with
`AGE_IDENTITY=/path/to/key` (or pass it to `age-decrypt`).

## Flows

**Add a device** (run on the laptop — an existing recipient):
```sh
cp newdevice.pub  age-store/keys/phone.pub        # 1. add its pubkey to the inventory
$EDITOR age-store/groups.conf                      # 2. add "phone" to the right group(s)
git -C shared-scripts commit -am "age-store: add phone to personal" && git push
age-reencrypt ~/Projects/some-repo                 # 3. re-encrypt each repo using that group
git -C ~/Projects/some-repo commit -am "rotate recipients" && git push
#   4. the new device pulls and can now decrypt with its own key.
```

**Add / rotate a secret in a repo:**
```sh
age-encrypt config.toml corp        # → config.toml.age
echo "config.toml.age corp" >> .age-secrets
```

**Onboard a new repo:** write its `.age-secrets`, `age-encrypt` each secret to
its group, commit the `.age` files. Done — no keys live in the repo.

**Rotate a key:** replace `keys/<name>.pub`, then `age-reencrypt` every repo
that uses a group containing that name.

## Constraints & notes

- **You can only add a key from a device that's already a recipient** (fact #2).
  If every recipient device is lost, the secrets are unrecoverable — keep the
  laptop key backed up.
- Decryption is keyless-of-the-store: any holder of a member private key can
  `age -d -i <key> file.age` without this repo present.
- Works for **binary** payloads (e.g. `secrets-bundle.tar.age`) — raw `age`,
  not value-level. That's why we use age directly rather than SOPS.
- `age-reencrypt` streams decrypt→encrypt; **plaintext never hits disk**.
