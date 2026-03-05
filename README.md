# Title

This is an example file with default selections.

## Install

```sh

```

## Usage

```sh

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
