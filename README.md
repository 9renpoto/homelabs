# homelabs

macOS 上で OpenClaw の実行環境をテストするための Docker 構成を管理するリポジトリです。
将来的には Linux 環境上でのホストを予定しており、Docker 環境を基盤として動作確認ができることを目指しています。

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [XQuartz](https://www.xquartz.org/) (macOS で GUI を表示する場合)
- OpenClaw のゲームデータ (`CLAW.REZ`) — オリジナルの Captain Claw から入手してください

## Install

```sh
git clone https://github.com/9renpoto/homelabs.git
cd homelabs
```

## Usage

### ゲームデータの配置

`data/` ディレクトリを作成し、`CLAW.REZ` を配置してください。

```sh
mkdir -p data
cp /path/to/CLAW.REZ data/
```

### macOS で GUI を使って起動する

XQuartz を起動し、X11 のネットワーク接続を許可します。

```sh
open -a XQuartz
xhost +localhost
```

Docker コンテナをビルドして起動します。

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
