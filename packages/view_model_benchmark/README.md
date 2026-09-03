# view_model benchmark

这个目录不做“谁的 `notifyListeners()` 更快”式排名，而是测量 `view_model`
各项真实能力的成本，并在计时之外验证行为正确性。

当前覆盖：

- 冷启动：spec 解析、创建、绑定与自动释放
- 热路径：`read(spec)` / `watch(spec)` 缓存命中
- 通知传播：1 / 10 / 100 个 binding
- selector：相关字段变化与无关字段变化（100 个订阅）
- 依赖传播：深度 1 / 4 / 8 / 16
- diamond graph：同一次传播必须去重
- 生命周期树：创建与自动释放的对称性
- pause / resume：暂停期间不刷新，恢复时只补一次

Widget/frame 基准另外覆盖 100 个消费者的五种场景：空帧、broad watch
相关/无关字段更新、selector 相关/无关字段更新。它记录真实 consumer rebuild
次数、端到端 pump 延迟，以及 Flutter engine 报告的 build/raster frame timing。

## 在 iPhone 7 上运行

```shell
cd packages/view_model_benchmark
zsh -ic 'ff pub get'
zsh -ic 'ff drive --profile --no-dds \
  -d a31facd61bb5b2705b21fb8f170eaabbdd973e24 \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/runtime_benchmark_test.dart'
```

终端会输出摘要，完整环境、参数与原始样本会写到
`results/iphone7_latest.json`。

Widget/frame 基准单独运行：

```shell
zsh -ic 'ff drive --profile --no-dds \
  -d a31facd61bb5b2705b21fb8f170eaabbdd973e24 \
  --driver=test_driver/frame_perf_driver.dart \
  --target=integration_test/widget_frame_benchmark_test.dart'
```

结果写入 `results/iphone7_frame_latest.json`。

runtime 数据的单位是 `ns/op`，包含 4 轮预热和 15 轮采样。Widget/frame
数据的单位是毫秒，每个场景包含 10 帧预热和 120 帧采样，并记录实际 rebuild
次数。这里只应比较同一设备、同一 Flutter 构建模式、同一套代码前后的变化；
不同能力的数字不能直接拿来排名。
