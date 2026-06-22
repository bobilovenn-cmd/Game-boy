# ESP32 重做时的 RGB30 UI 协议契约

本文只定义未来 ESP32 固件需要提供的接口，不授权修改当前正常运行的固件。

## 兼容要求

- 保留 UDP `192.168.31.126:5000` 和 UI 本地端口 `5001`，或提供可配置迁移方案。
- 保留统一消息外层 `{cmd, seq, ts, payload}`。
- ACK 必须回显请求 `seq`，重复请求应可去重。
- 所有节点相关响应必须带实际 `node`，不能依靠 UI 当前选择值推断。

## 事实遥测

`motor_status.payload` 应至少包含：

- `node`
- 六个遥测字段
- `valid_mask`
- `fresh_mask`
- 每字段采集时间或统一 `sample_id` 与 `sample_ts_ms`
- `drive_status_word`
- `drive_fault`
- `estop_latched`
- `display_status`

如果六字段不是同一采集周期，必须提供每字段时间戳。读取失败时清除对应
`fresh_mask` 位，禁止继续把旧值声明为实时值。

## 命令可靠性

- ACK 回显 `seq`、`node`、`status` 和稳定错误码。
- 对 enable/disable/jog/SDO/OTA 定义明确超时和幂等行为。
- heartbeat 不得修改活动节点。
- E-STOP 必须采用明确节点策略，并保持最高安全优先级。

## OTA

生产 OTA 必须具备：

- 分块序号和偏移校验
- 每块 ACK 或滑动窗口确认
- 超时重传
- 重复块幂等处理
- 总长度和强哈希校验
- 断点恢复或明确从零重传
- 校验成功后才能接受 flash
- 可报告失败阶段和错误码

在这些能力完成前，RGB30 UI 中 OTA 保持“实验功能”标记。

## 验收

- 六字段事实新鲜度连续运行测试
- UDP 丢包、乱序、重复包测试
- 节点 1 默认值不得覆盖活动 node 2
- RGB30 断联安全停止
- 电机离线时无无限 SDO 阻塞
- OTA 人工注入丢包后仍能恢复或明确失败
