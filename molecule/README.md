<!--
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

## Installation

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

### `default`

Tests a standard Headplane installation.

## Running

Ubuntu 26.04:

```bash
molecule test --scenario-name default
```

Other distributions:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
