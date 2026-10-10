---
name: Publish Process
description: Workflow for publishing view_model packages (annotation, generator, view_model) in the correct order.
---

# Publish Process

## CI 本地依赖与正式发布

- CI 可以在临时 runner 中生成 `pubspec_overrides.yaml`，让测试使用当前
  checkout 的 `view_model_annotation`；不得把发布包 `pubspec.yaml` 中的版本
  依赖改成 path。当前 CI 在发现已有 overrides 文件时会失败并保留原文件；
  以后引入其他 overrides 时，需要同步调整 CI 的合并策略，不能整文件覆盖。
- 本地/CI 的 overrides 文件不提交。生成器 example 的
  `publish_to: none`，可以保留其 `pubspec.yaml` 中现有的 path override。
- 正式发布使用待发布提交的干净检出，不复用 CI 的生成文件或解析结果。确认
  `view_model_annotation`、`view_model_generator`、`view_model` 三个发布包根目录
  均不存在 `pubspec_overrides.yaml`，且它们的 `pubspec.yaml` 使用正式版本依赖、
  不带本地 path override。不要为发布直接删除开发目录里用户已有的 overrides。
- 先发布 annotation 并等待目标版本可从 pub.dev 解析，再为 generator 和主包
  分别重新运行 `pub get`、对应测试以及 `pub publish --dry-run`。确认使用托管
  版本，并检查 dry-run 的文件清单没有本地覆盖文件后，才发布对应包。
  本机命令使用 `zsh -ic 'fd ...'` / `zsh -ic 'ff ...'`。
- CI 的本地依赖测试通过，只表示仓库内包协同通过，不能代替上述发布前验证。

参考：[pubspec_overrides.yaml](https://dart.dev/tools/pub/dependencies#pubspec_overridesyaml)、
[发布 dry-run](https://dart.dev/tools/pub/publishing#test-publishing-your-package)。

## 一次性配置 pub.dev

三个已存在的发布包分别在 pub.dev 的 Admin → Automated publishing 中启用
GitHub Actions 发布：

- Repository：`lwj1994/flutter_view_model`
- Tag pattern：`v{{version}}`
- 当前 workflow 不使用 GitHub Environment，不勾选要求 Environment。

本仓库三个包统一版本，共用一个 release tag。workflow 使用
`dart-lang/setup-dart@v1` 配置 GitHub OIDC 临时凭据，无需保存长期发布 token。
缺少上述 pub.dev 配置时，workflow 的上传步骤会失败；仅添加 YAML 不会自动
修改 pub.dev 的授权设置。

参考：[Dart 官方自动发布说明](https://dart.dev/tools/pub/automated-publishing)。

## 发布步骤：推送 release tag

1. 更新三个包的 `version: X.Y.Z`，同时将 generator 和主包的
   `view_model_annotation` 依赖更新为相同的精确版本。其他依赖版本不变；
   `stack_trace:` 和 `meta:` 继续保持空版本约束。
2. 编写英文 changelog，每个包只写一个正式版本条目，不拆分 `-dev.N`。
3. 提交并 push 发布代码，确认所有模块的 CI 通过。发布 tag 必须指向包含
   `.github/workflows/publish.yaml` 的待发布提交。
4. 创建 `vX.Y.Z` tag 并推送：`git tag vX.Y.Z`、`git push origin vX.Y.Z`。
   **推送 tag 即开始正式发布**，不再等发布完成后才打 tag。
5. 查看 `Publish to pub.dev` workflow：
   - 校验 tag、三个包的版本和 annotation 依赖一致，发布包没有 overrides
     或 path/git 依赖。
   - 复用完整 CI 验证所有模块；该 job 内可以使用临时本地 overrides。
   - 在独立、干净的 job 中验证并发布 annotation。
   - 等待 5 分钟后，解析 pub.dev 上的 annotation；若解析失败，最多重试
     10 次、间隔 30 秒。确认来源为 hosted 且版本与 tag 相同后，测试并
     dry-run，再发布 generator。
   - 在另一个干净 job 中解析正式依赖、确认 annotation 来源和版本，运行
     主包串行测试、dry-run，最后发布 view_model。
6. 三个发布 job 全部成功后，在 pub.dev 核对对应版本。DevTools 扩展与
   benchmark 不发布。

发布 job 的 `pub get --no-example` 只解析发布包本身；示例和生成代码一致性
由前置完整 CI 验证。发布 job 不复用测试 job 的 workspace、overrides 或
解析结果，且不使用 `--skip-validation`。

generator 和主包的 dry-run 使用 `--ignore-warnings`：精确锁定 annotation
会产生版本约束警告，主包刻意保留空约束的 `meta` / `stack_trace` 也会产生
警告。该选项保留警告输出，并仍让校验错误导致失败；不要改用
`--skip-validation`，也不要通过 `|| true` 忽略任意失败。发布前仍须审阅
dry-run 输出中的新增警告。

如果 annotation 或 generator 已发布而后续 job 失败，修复外部配置后使用
GitHub Actions 的 **Re-run failed jobs**，保留已成功的发布 job。不要对同一
版本重复上传或移动 release tag。若必须修改代码，创建新版本和新 tag。

需要手动排障时，在干净检出中遵循相同发布顺序与验证规则，本机使用
`zsh -ic 'fd ...'` / `zsh -ic 'ff ...'`；手动发布不是默认流程。
若失败只涉及 workflow 的预期警告处理，可从原 release tag 的干净检出
完成上述验证并补发尚未发布的包；单独提交 workflow 修复，不修改 tag，
不重复上传已发布的包，也不将修复后的其他包内容混入当前版本。
