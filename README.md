# 一加 Ace 3 / astonc 内核编译验证

适用源码基线：AlphaDroid 4.7（2026-09-01）、Android 16、Linux 5.15.197。

这里有两条独立流程，旧版基线编译成功不表示已经完成新版升级：

| 流程 | KSU-Next / SUSFS | 构建记录 |
| --- | --- | --- |
| 原版本基线复编 | v3.2.0 / v2.1.0 | [已成功的基线构建](https://github.com/ceigt/astonc-kernel-build/actions/runs/40044327230) |
| 实验升级编译 | v3.4.2+（33405）/ v2.3.0 | [当前升级构建及实际结果](https://github.com/ceigt/astonc-kernel-build/actions/runs/40071191919) |

云端编译不会自动修改手机。手机未刷写时仍运行原来的内核版本。

## 新版流程

在 Actions 中选择 **astonc experimental upgrade**。构建定义位于 `.github/workflows/upgrade.yml`、`upgrade/`；准确源码提交见 `upgrade/sources.lock.json`。

- 内核基线：AlphaDroid `a62400d531bc7c26747001eb3f7c9d505a94dbdf`。
- KSU-Next：维护者 pershoot 的 SUSFS 适配提交 `d21e0a66c887ae4bc75b7c9f83e41761819ec09a`，包含正式 v3.4.2 及后续上游和适配更新；并非未修改的 v3.4.2 正式源码。
- SUSFS：官方 android13-5.15 分支提交 `9359a9ce823f98ed7fec21c2e8b9f46d9740fbaa`，版本 v2.3.0；移植到原 5.15.197 源码。
- 编译器：官方 AOSP Clang r563880c / build 14054515 / 21.0.0，固定提交并核验全部文件内容树。
- 保留 Full LTO、CFI、MODVERSIONS、模块签名保护及原有 SUSFS 功能；配置验证失败即停止。
- 补丁仅允许修改已审阅的 SUSFS 文件，禁止混入无关 UAPI 头文件改动。

升级产物名为 `astonc-upgrade-validation-<run number>`。日志、配置、源码版本、补丁范围、版本核验及 SHA-256 记录均会保存；失败任务也会保存诊断文件，因此请检查 `build-result.json` 中的 `compile_succeeded`，不能把 artifact 上传成功当成内核编译成功。

## 产物范围

成功任务生成的 `Image.experimental` 是原始 ARM64 实验内核，**不是 boot.img，也不是可刷入包**。实验版本带有 `-ksun342-susfs230-exp` 标记，与现有厂商模块的版本字符串不同，不应直接替换手机内核。

尚未完成手机启动、全部外部厂商模块 ABI、原 ROM 签名及完整构建清单的一致性验证。没有刷写、重启、切换槽位或修改手机配置。

仓库保存公开源码引用、构建定义和经用户授权公开的完整内核配置。原始 boot 分区备份、手机序列号及手机提取的厂商模块均不上传，原始备份保留在本机。

## 旧版基线流程

`.github/workflows/baseline.yml`、`scripts/`、根目录 `sources.lock.json` 和 `configs/astonc-baseline.config` 保留原版本复编流程。其成功结果为 v3.2.0 / v2.1.0，用于比较编译环境、配置和导出符号，不包含新版升级。
