# RGB30 UI Azure CI/CD

本文件说明公司 Azure `MotorBoy-UI` 仓库的 RGB30 UI 流水线配置。

## 当前范围

当前只启用 CI，不做自动部署：

1. 检查 UI 仓库没有提交 `.DS_Store`、`__pycache__`、`.pyc` 和 `build/` 产物。
2. 检查已归档的蚂蚁操控模式没有重新残留在正式 RGB30 UI 中。
3. 运行 `tests/run_all.sh`。
4. 导出 Godot `RGB30 Linux ARM64`。
5. 保存 `build/rgb30_diag_terminal_arm64` 和对应 SHA256 到 Azure Pipeline Artifact。

不会自动 SSH 到 RGB30，也不会自动推送 Azure `stage` 之外的发布结果。

## Azure Pipeline 文件

流水线入口为仓库根目录：

```text
azure-pipelines.yml
```

在本完整 GameBoy 工作区中，该文件位于：

```text
/Users/guoweifeng/GameBoy/godot_terminal/azure-pipelines.yml
```

因为 Azure `MotorBoy-UI` 仓库只对应 `godot_terminal/`，推送到 Azure 后它会位于
Azure UI 仓库根目录。

## Agent 要求

默认使用 Azure 自托管 Mac Agent Pool：`Default`。

Agent 必须具备：

- macOS；
- Godot 4.6.3；
- Linux ARM64 export template；
- Python 3；
- `rg`；
- `file`；
- `shasum`。

默认 Godot 路径：

```text
/Applications/Godot.app/Contents/MacOS/Godot
```

如果公司 Agent 的 Godot 安装路径不同，在 Azure Pipeline 变量中覆盖：

```text
GODOT_BIN=/path/to/Godot
```

如果 Agent Pool 不叫 `Default`，运行流水线时修改参数：

```text
agentPool=<公司实际 Mac Agent Pool 名称>
```

## 本地等价验证

在 Mac 本地执行：

```sh
cd /Users/guoweifeng/GameBoy/godot_terminal
./ci/run_rgb30_ui_ci.sh
```

单独导出：

```sh
./ci/export_rgb30_arm64.sh
```

产物：

```text
build/rgb30_diag_terminal_arm64
build/rgb30_diag_terminal_arm64.sha256
```

## 为什么暂不自动部署 RGB30

RGB30 是实体设备，位于本地网络，Azure 云端或公司 Agent 不一定能稳定访问。
自动部署还涉及 SSH 凭证、服务重启、实机截图和人工确认。当前更安全的策略是：

- Azure CI 自动测试和构建；
- 产物作为 Pipeline Artifact 保存；
- 需要上机时人工下载或由本地受控脚本部署；
- 等测试机、凭证和回退流程标准化后，再增加手动批准的 CD 阶段。
