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
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Jackett

This is an [Ansible](https://www.ansible.com/) role which installs [Jackett](https://github.com/Jackett/Jackett) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Jackett is an API for your favorite Torrent trackers. It translates queries from apps ([Sonarr](https://github.com/Sonarr/Sonarr), [Radarr](https://github.com/Radarr/Radarr), etc.) into tracker-site-specific HTTP queries, parses the HTML or JSON response, and then sends results back to the requesting software.

See the project's [documentation](https://github.com/Jackett/Jackett/blob/master/README.md) to learn what Jackett does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Jackett with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# jackett                                                              #
#                                                                      #
########################################################################

jackett_enabled: true

########################################################################
#                                                                      #
# /jackett                                                             #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Jackett you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
jackett_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

>[!NOTE]
> The `jackett_path_prefix` variable can be adjusted to host under a subpath (e.g. `jackett_path_prefix: /jackett`), but this hasn't been tested yet.

### Mounting additional data directories (optional)

To mount additional data directories, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jackett_container_additional_volumes_custom:
  - type: bind
    src: /path/to/blackhole
    dst: /downloads
```

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `jackett_environment_variables_additional_variables` variable

#### Command-line arguments

Additional command line arguments can be passed to Jackett by use of the `RUN_OPTS` environment variable. To specify this, add the following to your `vars.yml` file:

```yaml
jackett_environment_variables_additional_variables: |
  RUN_OPTS="--IgnoreSslErrors true --ProxyConnection 192.168.10.3:9999"
```

The full list of available arguments is as follows:

```sh
Jackett v0.22.1377
  -i, --Install            Install Jackett windows service (Must be admin)

  -r, --ReserveUrls        (Re)Register windows port reservations (Required for
                           listening on all interfaces).

  -u, --Uninstall          Uninstall Jackett windows service (Must be admin).

  -l, --Logging            Log all requests/responses to Jackett

  -t, --Tracing            Enable tracing

  -c, --UseClient          Override web client selection.
                           [automatic(Default)/httpclient/httpclient2]

  -s, --Start              Start the Jacket Windows service (Must be admin)

  -k, --Stop               Stop the Jacket Windows service (Must be admin)

  -x, --ListenPublic       Listen publicly

  -z, --ListenPrivate      Only allow local access

  -p, --Port               Web server port

  -n, --IgnoreSslErrors    [true/false] Ignores invalid SSL certificates

  -d, --DataFolder         Specify the location of the data folder (Must be
                           admin on Windows) eg. --DataFolder="D:\Your
                           Data\Jackett\". Don't use this on Unix (mono)
                           systems. On Unix just adjust the HOME directory of
                           the user to the datadir or set the XDG_CONFIG_HOME
                           environment variable.

  --NoRestart              Don't restart after update

  --PIDFile                Specify the location of PID file

  --NoUpdates              Disable automatic updates

  --help                   Display this help screen.

  --version                Display version information.
```

### Notes on configuration

- `jackett_container_http_port` describes the container image rather than configuring it. Jackett reads its listening port from the `ServerConfig.json` file it maintains on its own data path, and the container's readiness check is hardcoded to port 9117, so a container listening anywhere else would never come up.
- Jackett mints an API key on first start and keeps it, in plain text, in `ServerConfig.json` under the role's data path (`/jackett/data/Jackett/ServerConfig.json` by default). Jackett writes that file with mode `0644`; what keeps it private is the `0750` directory the role creates around it, owned by `jackett_uid`:`jackett_gid`. Anything you give that uid or gid to on the host can read the key, and the key is enough to drive the whole Jackett API.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Jackett becomes available at the specified hostname like `https://example.com`.

### Adding an Indexer

Once you've installed Jackett and setup an admin password you can start configuring it. One of the first things you're likely to want to do is configure some indexers. An indexer is basically a tracker, which can be either public, semi-private, or private.

To add an indexer, click the `+ Add indexer` button and select your tracker from the list.

![Jackett Add Indexer](./assets/jackett-add-indexer.webp)

If its a semi-private or private tracker you will have to add some specific configuration, like a username and password. If its public you can just add it as-is.

Once its added you can test it using the `Test ✓` button, if it returns successfully you're good to go!

### Integration with Sonarr/Radarr

To add Jackett to your [Sonarr](https://sonarr.tv/) or [Radarr](https://radarr.video/) instance navigate to the form at `Settings > Indexers > Add > Torznab > Custom`:

![Sonarr Add Indexer](./assets/sonarr-add-indexer.webp)

Next copy Jackett's `API Key` from in the top right of the Jackett dashboard:

![Jackett API Key](./assets/jackett-api-key.webp)

Paste this into the Sonarr/Radarr form, under `API Key`.

Next, click `Copy Torznab Feed` of the indexer (tracker) you added to Jackett. Paste this into the Sonarr/Radarr form too, under `URL`.

Fill in the rest of the form with your preferences, and you're done!

>[!NOTE]
> If you are looking for an Ansible role for Sonarr and Radarr, you can check out [ansible-role-sonarr](https://github.com/spatterIight/ansible-role-sonarr) and [ansible-role-radarr](https://github.com/spatterIight/ansible-role-radarr), both of which are maintained by me.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu jackett` (or how you/your playbook named the service, e.g. `mash-jackett`).
