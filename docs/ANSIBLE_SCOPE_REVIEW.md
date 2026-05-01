# Ansible スコープ再検討

**質問**: CLI-first NemoClaw に Ansible は本当に必要か？

## 現在の Ansible スコープ

```yaml
ansible/playbooks/wsl-nemoclaw-bootstrap.yml:
  - docker_engine       # Docker Engine インストール + daemon
  - nvidia_docker       # NVIDIA Container Toolkit インストール + daemon config
  - openclaw_secret     # /etc/openclaw/openclaw-core-secret/ ディレクトリ作成
```

### 各 role の詳細

#### 1. `docker_engine`
**目的**: Docker Engine インストール、systemctl で起動

**実装**:
- Docker APT repository 登録
- Docker daemon インストール (`docker-ce`, `docker-ce-cli`)
- systemd サービス有効化・起動
- Socket 検証テスト (`docker ps`)

**手動実行の場合**:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
```

**評価**:
- ✅ Version-controlled
- ✅ 再現性あり
- ⚠️ 3-4行 shell 相当の内容
- ⚠️ WSL2 では systemd デフォルト対応 (22.04+)

---

#### 2. `nvidia_docker`
**目的**: NVIDIA Container Toolkit インストール、Docker daemon 設定

**実装**:
- NVIDIA APT repository 登録
- `nvidia-container-toolkit` インストール
- `/etc/docker/daemon.json` に `nvidia` runtime 登録
- Docker daemon reload

**手動実行の場合**:
```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/ubuntu22.04/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**評価**:
- ✅ GPG keyring 管理（手動では errorprone）
- ✅ APT repository idempotency
- ✅ `/etc/docker/daemon.json` 操作（手動では リスク）
- ⚠️ しかし Ansible では lineinfile/template による state 管理は複雑

---

#### 3. `openclaw_secret`
**目的**: `/etc/openclaw/openclaw-core-secret` ディレクトリ作成（permission 700）

**実装**:
```yaml
- name: Create secret directory
  file:
    path: /etc/openclaw/openclaw-core-secret
    state: directory
    mode: '0700'
    owner: "{{ ansible_user_id }}"
    group: "{{ ansible_user_id }}"
```

**手動実行の場合**:
```bash
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret
```

**評価**:
- ✅ Idempotent（`file` module）
- ❌ `install -d` 1行と同じ
- ❌ 実行時刻に依存しない（初回のみ必要）

---

## 代替案比較

### ❌ Option A: Ansible 廃止、完全手動

**フロー**:
```
1. User opens README
2. Copies and runs 5 shell commands
3. Done
```

**利点**:
- リポジトリ複雑性ゼロ
- Ansible インストール不要
- 依存性なし

**欠点**:
- Version tracking なし（APT repository URL が変わったら？）
- 環境再現性が低い（手動入力誤り）
- 複数マシンへの展開時に非効率

---

### ✅ Option B: Minimal shell script

**フロー**:
```
1. User opens README
2. Runs: bash infra/bootstrap-docker-nvidia.sh
3. Done
```

**実装**: `infra/bootstrap-docker-nvidia.sh`
```bash
#!/bin/bash
set -euo pipefail

# Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
# ... (APT repository setup)
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Secrets directory
sudo install -d -m 700 /etc/openclaw/openclaw-core-secret

echo "✅ Docker + NVIDIA bootstrap complete"
```

**利点**:
- 単純で transparent
- Version tracked
- README 統合容易

**欠点**:
- 複数マシン展開時に Ansible より手間
- Idempotency が弱い（部分実行時に冪等でない可能性）

---

### ⚠️ Option C: 現在の Ansible（最小構成）

**フロー**:
```
1. User installs Ansible: brew install ansible
2. Runs: ansible-playbook playbooks/wsl-nemoclaw-bootstrap.yml
3. Done
```

**利点**:
- Full idempotency
- Version tracked
- Multi-machine へのスケール容易

**欠点**:
- Ansible インストールが前提（brew bundle で対応）
- YAML 習得コスト
- 3 roles で 15+ ファイル

**現状評価**:
- Docker/NVIDIA セットアップは Ansible で自動化する価値あり（idempotency + version tracking）
- ただし roles を 3 個も必要か？ → consolidate 検討

---

## 最小 Ansible 構成案（Option D）

**判断**: Ansible は残すが、1 playbook + 1 reusable role に簡略化

### 新構成

```
ansible/
  playbooks/
    wsl-nemoclaw-bootstrap.yml  # メインエントリ（ここだけ）
  roles/
    bootstrap_docker_nvidia/    # Docker + NVIDIA を一つの role に
      tasks/main.yml
      defaults/main.yml
      handlers/main.yml
```

### 単一 role: `bootstrap_docker_nvidia`

```yaml
---
- name: Install Docker Engine
  # ... Docker APT + install

- name: Install NVIDIA Container Toolkit
  # ... NVIDIA APT + install + daemon config

- name: Create secret directory
  # ... /etc/openclaw/openclaw-core-secret
```

**削除対象**:
- `docker_engine` → `bootstrap_docker_nvidia` に統合
- `nvidia_docker` → `bootstrap_docker_nvidia` に統合
- `openclaw_secret` → `bootstrap_docker_nvidia` に統合

**Playbook 簡略化**:
```yaml
---
- hosts: localhost
  gather_facts: yes
  roles:
    - bootstrap_docker_nvidia
```

**ファイル数**: 15+ → 8 程度

---

## 推奨: Option C（現在のまま維持）

### 理由

1. **Version tracking**: APT repository URLs が変わったときに追跡可能
2. **Idempotency**: 複数回実行しても安全
3. **Simplicity**: 既に実装済み、lint pass 済み
4. **Scalability**: 将来、複数マシンへの展開時にかんたんに対応可能
5. **Brew bundle**: Ansible インストール自動化済み（ユーザー視点での手間なし）

### 最小化は不要な理由

- 現在 3 roles × ファイル数 ≈ 12-15 は許容範囲
- 削減してもファイル数は 8 程度（5 ファイルの削減のみ）
- Consolidate すると YAML 複雑性が増す（1 role = 1責務）
- 将来的に Ollama role 追加時に、再度分割が必要になる可能性

---

## 最終判断マトリックス

| 項目 | 手動 (A) | Shell (B) | Ansible現在 (C) | Ansible最小 (D) |
|------|---------|----------|-----------------|-----------------|
| 自動化 | ❌ | ✅ | ✅ | ✅ |
| 再現性 | ❌ | ✅ | ✅ | ✅ |
| Idempotency | ❌ | ⚠️ | ✅ | ✅ |
| Version tracked | ❌ | ✅ | ✅ | ✅ |
| 複雑性 | 低 | 低 | 低 | 低 |
| スケール性 | ❌ | ⚠️ | ✅ | ✅ |
| 実装済み | ❌ | ❌ | ✅ | ❌ |
| **推奨度** | ❌ | ⚠️ | ✅ | △ |

**結論**: **Option C（現在の Ansible 構成）を維持**

- 既に実装・検証済み
- Brew bundle で自動インストール対応
- CLI-first NemoClaw ユースケースに十分
- 簡潔でわかりやすい責務分離

将来、複数 machine 管理 or 複雑化が見えたら改めて検討。
