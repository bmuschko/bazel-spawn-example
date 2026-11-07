# Bazel docker spawn strategy example

A minimal Bazel 9 project that shows how the `docker` spawn strategy runs each action inside a Docker container.

The build has two `genrule` actions, `//:default_image` and `//:custom_image`.
Each one writes the kernel and operating system it ran on to a text file, so the output shows where the action executed.

## How the docker spawn strategy works

A spawn strategy decides how Bazel executes an action.
By default, actions run on the host in a sandbox such as `darwin-sandbox` or `linux-sandbox`.
With the `docker` strategy, Bazel starts a container for every action, mounts the execution root into it, and runs the command there.

| Flag | Purpose |
|------|---------|
| `--experimental_enable_docker_sandbox` | Makes the `docker` strategy available |
| `--spawn_strategy=docker` | Executes every action with the `docker` strategy |
| `--experimental_docker_image=ubuntu:24.04` | Image used for actions that do not specify their own |

The flags are grouped under `--config=docker` in `.bazelrc`.
A target can pick its own image through the `container-image` execution property, which `//:custom_image` uses to run on `debian:bookworm-slim`.

```starlark
exec_properties = {"container-image": "docker://debian:bookworm-slim"},
```

## Prerequisites

Install [Bazelisk](https://github.com/bazelbuild/bazelisk).
It reads `.bazelversion` and downloads the pinned Bazel version on first use.
The commands below call `bazelisk`. If Bazelisk is installed as `bazel`, use that name instead.

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine and make sure the daemon is running.

```shell
docker info
```

Watch the `INFO: N processes: ...` line near the end of each build's output.
On Linux the host strategy is `linux-sandbox` or `processwrapper-sandbox` instead of `darwin-sandbox`.

## Step 1: Build with the host sandbox

```shell
bazelisk clean
bazelisk build //:all
```

Both actions execute directly on the host.

```
INFO: 3 processes: 1 internal, 2 darwin-sandbox.
```

The outputs report the host operating system for both targets, because `container-image` is only read by the `docker` strategy.

```shell
cat bazel-bin/default_image.txt bazel-bin/custom_image.txt
```

```
kernel: Darwin
os: macOS
kernel: Darwin
os: macOS
```

## Step 2: Build with the docker spawn strategy

```shell
bazelisk clean
bazelisk build --config=docker //:all
```

Bazel pulls the images on first use and runs both actions in containers.

```
INFO: 3 processes: 1 internal, 2 docker.
```

`//:default_image` ran in the image set by `--experimental_docker_image` and `//:custom_image` ran in the image set by its `container-image` property.

```shell
cat bazel-bin/default_image.txt bazel-bin/custom_image.txt
```

```
kernel: Linux
os: Ubuntu 24.04.5 LTS
kernel: Linux
os: Debian GNU/Linux 12 (bookworm)
```

The outputs are written to the host's output base, just like in step 1.

## Step 3: Switch back to the host sandbox without a clean

```shell
bazelisk build //:all
```

The spawn strategy is not part of the action key, so Bazel considers the outputs from step 2 up to date and executes nothing.

```
INFO: 1 process: 1 internal.
```

The outputs still report Linux.

```shell
cat bazel-bin/default_image.txt bazel-bin/custom_image.txt
```

```
kernel: Linux
os: Ubuntu 24.04.5 LTS
kernel: Linux
os: Debian GNU/Linux 12 (bookworm)
```

Run `bazelisk clean` to execute the actions on the host again.
The same applies to remote and disk caches, which can serve results produced with a different strategy.

## GitHub Actions

The workflow in `.github/workflows/docker-spawn-demo.yml` runs every step above as a separate workflow step on `ubuntu-latest`.
It checks for a running Docker daemon first and installs Docker with `docker/setup-docker-action` if none is found.
After each build, `scripts/verify-build.sh` fails the step if the number of executed actions or their strategy does not match.
