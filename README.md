# Scoop 一键部署工具

![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![License](https://img.shields.io/badge/license-Unlicense-green)

面向公司内网环境的 Scoop 全生命周期管理工具：**一键安装、代理加速、备份还原、彻底卸载**。

针对大陆网络环境深度优化——自动测速多个 GitHub 代理并选择最快线路，内置失败重试、直连降级、快照回滚等多重容错，网络抖动也不会把系统置于残缺状态。

## 特性

- **一键安装** — Scoop 本体、gsudo/7-Zip/Git 依赖、Bucket 仓库、公司软件清单，四步流程自动串联，一次执行全部就绪
- **智能代理测速** — 秒级小文件探针（不受大流量限速影响），自动在多个 gh-proxy 线路中选出最快的一条；全部不可达时回退默认线路，安装不中断
- **稳健 Bucket 管理** — 串行执行避开网络隔离问题；git 仓库原地换源（不重克隆）；非 git 目录先快照再替换，任何失败原样恢复；添加失败自动重试并降级 GitHub 直连
- **完整备份** — 一键生成可读可编辑的还原脚本（.ps1/.bat）+ scoop 官方导出（export.json），双通道恢复，重装系统后直接回放
- **彻底卸载** — 预览模式先行；gsudo 留到最后才卸避免自毁提权；junction 安全删除；注册表 PATH/环境变量清理；scoop CLI 损坏时按文件系统兜底枚举，不留残余

## 快速开始

### 安装

```powershell
# 在线安装
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.giteeusercontent.com/sdhsparke/online-installer/raw/master/Online-ScoopInstaller.ps1 | iex;exit
```
```
# 线下安装
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
.\scoop-install.ps1
```

### 备份

```powershell
# 双击 backup\scoop-backup.cmd，或：
.\backup\scoop-backup.ps1 -Compress
```

生成还原脚本（`backup-yyMMdd.ps1` / `.bat`）、设置文件副本与官方导出，默认输出到 `backup\backups\`。在新机器上完成安装后，运行还原脚本即可恢复全部软件。

### 卸载

```powershell
# 先预览（不改动系统），再执行：
.\uninstall\scoop-uninstall.ps1 -DryRun
.\uninstall\scoop-uninstall.ps1
```

交互确认后按「全局软件 → 用户软件 → Bucket → 目录 → 环境变量」顺序清理，卸载前自动生成还原脚本到 `uninstall\restores\` 以防误删。

## 设计亮点

**代理测速探针**：不用 git clone（几十 MB 被限速）也不用 ls-remote（GitHub ref 广告同为 MB 级），而是计时下载几 KB 的小文件——与安装实际使用的 HTTPS 路径一致，且小到不会被免费代理限速，探针本身永不超时。

**失败自愈的 Bucket 更新**：已是 git 仓库的 bucket 通过 `git remote set-url` 原地换源；需要重建的目录先移出 `buckets\` 做快照（避免被 scoop 误识别），失败时原样移回。机器永远不会处于「旧 bucket 已删、新 bucket 没装上」的残缺状态。

**卸载顺序安全**：gsudo 本身也是 scoop 软件，却被后续步骤依赖——卸载器将全局软件、目录删除、机器级注册表清理全部排在 gsudo 卸载之前，最后才移除 gsudo 自身。

## 项目结构

```
scoop-shgr-main\
├── scoop-install.cmd / .ps1   # 安装入口
├── installation\              # 安装链：本体 → 依赖 → Bucket → 软件
├── backup\                    # 备份：还原脚本 + 官方导出
└── uninstall\                 # 卸载：预览 / 确认 / 彻底清理
```

## 系统要求

- Windows 10 / 11
- PowerShell 5.1+

## 致谢

- [Scoop](https://scoop.sh) 与 [ScoopInstaller/Install](https://github.com/ScoopInstaller/Install) — 安装器基于官方脚本改造
- [gerardog/gsudo](https://github.com/gerardog/gsudo) — 提权方案
- [duzyn/scoop-cn](https://github.com/duzyn/scoop-cn) — 中文软件源

## License

[Unlicense](http://unlicense.org/) — 随 Scoop 官方安装器同为公共领域授权。
