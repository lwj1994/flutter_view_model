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

## 发布步骤

1. 先运行每个模块的 test， 保证 pass all.
1. 先更新版本号。只改动 version: xxx 。其他的依赖版本不要改
2. view_model_generator 和 view_model 需要更新 view_model_annotation 的版本
2. 始终保持 "stack_trace: " 版本为空， “meta” 版本为空
2. 编写 changelog 时只写 1 个正式版本条目（例如 `15.0.0`），不区分 `-dev.0`、`-dev.1`、`-dev.2`
3. 按顺序发布 
	a. view_model_annotation
	b. view_model_generator
	c. view_model
4. 发布代码： fd pub publish  然后执行后等待一会 输入 y
4. 发布 view_model_annotation 后等待 5分钟，然后发布 view_model_generator 和 view_model
5. 发布结束后，执行 git add . && git commit -m "publish version:x.x.x"
6. 将提交 push 到远程分支（用于远程分发）
7. 打 tag：`vX.X.X`（例如 `v15.0.0`），并 push 该 tag 到远程
