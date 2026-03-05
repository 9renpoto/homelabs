# homelabs

Docker configuration for running OpenClaw (a Captain Claw reimplementation) on macOS, with a path toward Linux hosting.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [XQuartz](https://www.xquartz.org/) (for displaying the GUI on macOS)
- OpenClaw game data (`CLAW.REZ`) — obtain from the original Captain Claw disc or digital release

## Install

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

## Usage

### Place game data

Create a `data/` directory and copy `CLAW.REZ` into it:

```sh
mkdir -p data
cp /path/to/CLAW.REZ data/
```

### Start on macOS (XQuartz)

Start XQuartz and allow local X11 connections:

```sh
open -a XQuartz
xhost +localhost
```

Build and run the container:

```sh
docker compose up --build
```

## Dotfiles

This project uses a devcontainer. To manage your dotfiles from your host machine into the container, you can use `chezmoi` with Docker.

First, on your host machine, initialize `chezmoi` with your dotfiles repository. For example:
```sh
chezmoi init git@github.com:9renpoto/dotfiles.git
```

Then, with the devcontainer running, execute the following command on your host to apply the dotfiles inside the container:
```sh
chezmoi docker apply
```

## Contributing

PRs accepted.

## License

MIT © TBD
