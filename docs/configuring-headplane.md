<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2025 spatterlight
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Headplane

This is an [Ansible](https://www.ansible.com/) role which installs [Headplane](https://headplane.net/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Headplane is an open-source, self-hosted implementation of the [Tailscale Web UI](https://tailscale.com/) for [Headscale](https://headscale.net/).

See the project's [documentation](https://headplane.net/introduction) to learn what Headplane does and why it might be useful to you.

## Prerequisites

To run a Headplane instance it is necessary to prepare a Headscale instance.

If you are looking for an Ansible role for Headscale, you can check out [ansible-role-headscale](https://github.com/mother-of-all-self-hosting/ansible-role-headscale) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

>[!NOTE]
> Headplane and Headscale have version-specific compatibility requirements. See the [Headplane release notes](https://github.com/tale/headplane/releases) and [Headplane agent documentation](https://headplane.net/features/agent) for the relevant upstream information.

## Adjusting the playbook configuration

To enable Headplane with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# headplane                                                            #
#                                                                      #
########################################################################

headplane_enabled: true

########################################################################
#                                                                      #
# /headplane                                                           #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Headplane you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
headplane_hostname: "example.com"
```

### Set a random string for cookie secret

You also need to set a random **32 character** string for the secret string used to encode and decode web sessions. To do so, add the following configuration to your `vars.yml` file. The value can be generated with `openssl rand -hex 16` or in another way.

```yaml
headplane_cookie_secret: YOUR_SECRET_KEY_HERE
```

### Enabling the Headplane agent (optional)

The [Headplane agent](https://headplane.net/features/agent) periodically synchronizes information about the nodes in your Tailnet.

To enable the agent, add the following configuration to your `vars.yml` file:

```yaml
headplane_config_integration_agent_enabled: true

headplane_config_headscale_api_key: YOUR_HEADSCALE_API_KEY_HERE
```

The agent requires a Headscale API key. If Headplane already uses one, you can reuse the key. Otherwise, you can create one by running the command from [Headscale's API documentation](https://headscale.net/stable/ref/api/) with the [Headscale convenience script](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/services/headscale.md#convenience-script-to-call-the-binary) (adapt the path to the binary as necessary):

```sh
/mash/headscale/bin/headscale apikeys create
```

>[!NOTE]
>
> - Please note that Headscale API keys expire and are only displayed when they are created. Treat the key as a secret, and replace it before it expires.
> - Since the API key enables to access to the Headscale system, it is recommended to use [Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault.html) and store the key as `vault_headplane_headscale_api_key` in it.

If Headplane and Headscale shares the same container network as the MASH playbook does, add the the following configuration as well:

```yaml
headplane_config_integration_agent_tailscale_netns: false
```

#### Upgrading custom agent configuration from Headplane 0.6

In Headplane 0.7, `integration.agent.cache_ttl` controls the interval between sync attempts in milliseconds. The default is `180000` (three minutes). Headplane 0.6.3 did not use this setting, despite including it in the example configuration.

If you set `cache_ttl` through `headplane_configuration_extension_yaml`, check its value before upgrading. An old example value of `60` now means 60 milliseconds. To request one-minute intervals, merge the following setting into your existing configuration extension, preserving its other settings:

```yaml
headplane_configuration_extension_yaml: |
  integration:
    agent:
      cache_ttl: 60000
```

The `integration.agent.cache_path` setting is deprecated and has no effect in Headplane 0.7. Remove it from your configuration extension. The agent's persistent working directory is still controlled by `integration.agent.work_dir`; its default, `/var/lib/headplane/agent`, is inside the data directory mounted by the role.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `headplane_environment_variables_additional_variables` variable
- The [Headplane example configuration](https://github.com/tale/headplane/blob/main/config.example.yaml) for all the possible configuration options (like OIDC).

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Headplane becomes available at the specified hostname like `https://example.com`.

The application being hosted at `/admin` is [not easily configurable](https://github.com/tale/headplane/blob/main/docs/install/native-mode.md#custom-path-prefix). The default configuration is to automatically redirect `/` requests to `/admin`.

> [!NOTE]
> The `headplane_path_prefix` variable can be adjusted to host under a subpath (e.g. `headplane_path_prefix: /headplane`), but this hasn't been tested yet.

### Logging in

To [log in to Headplane](https://headplane.net/install/docker#accessing-headplane), run a command to create using the Headscale convenience script as below (adapt the path to the binary as necessary):

```sh
/mash/headscale/bin/headscale apikeys create
```

You can then log in to `https://example.com/admin` by entering the generated API key.

### Modifying DNS

To modify the Headscale DNS settings in Headplane, some variables should be adjusted as follows:

```yaml
# Change the name of the variable as necessary; this case ansible-role-headscale is used to install Headscale
headscale_extra_records_path_enabled: true

headplane_headscale_config_path_mount_options: readwrite
```

Be careful when you make changes outside of the `DNS Records` section, since many of other configuration options will directly modify the Headscale configuration file managed by Ansible -- this is likely to lead to conflicts. The `DNS Records` section does not have this issue since it uses a separate file (`extra_records.json`).

### Modifying Access Control Lists

To modify Headscale ACL's you'll need to adjust the Headscale configuration:

```yaml
headscale_config_policy_mode: database
```

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu headplane` (or how you/your playbook named the service, e.g. `mash-headplane`).
