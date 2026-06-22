# AGV 电机诊断终端 - UDP API 接口文档

## 概述

本终端通过 UDP 协议与 ESP32 CAN 网关通信，实现电机控制和状态监控。

- **本地端口**: 5001
- **目标端口**: 5000
- **目标地址**: 192.168.31.126（当前同路由器 STA 模式）
- **数据格式**: JSON UTF-8
- **心跳间隔**: 150ms
- **当前默认节点**: 2（UI 支持选择 1–127）

> 当前 ESP32 固件保持兼容运行。未来重做固件时，以
> `docs/ESP32_UI_CONTRACT.md` 为新增协议要求。旧 `motor_status` 没有逐字段
> 新鲜度，因此 UI 不能独立证明六个字段在同一采集周期内全部更新。

---

## 通用消息格式

### 请求格式
```json
{
  "cmd": "命令名",
  "seq": 123,
  "ts": 1718000000,
  "payload": {
	// 命令特定参数
  }
}
```

### 响应格式
```json
{
  "cmd": "ack",
  "seq": 123,
  "ts": 1718000001,
  "payload": {
	"status": "ok",
	"msg": "操作成功"
  }
}
```

---

## 命令列表

### 1. 心跳 (heartbeat)

保持连接活跃，网关会周期性响应。

**请求**:
```json
{
  "cmd": "heartbeat",
  "seq": 1,
  "ts": 1718000000
}
```

**响应**: 无直接响应，网关通过 `motor_status` 上报状态

---

### 2. 电机使能 (enable)

使能指定节点的电机驱动器。

**请求**:
```json
{
  "cmd": "enable",
  "seq": 2,
  "ts": 1718000000,
  "payload": {
	"node": 1
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| node | int | CANopen 节点 ID；当前 UI 默认 2，可选 1–127 |

**响应**: `ack` 消息

---

### 3. 电机失能 (disable)

失能指定节点的电机驱动器。

**请求**:
```json
{
  "cmd": "disable",
  "seq": 3,
  "ts": 1718000000,
  "payload": {
	"node": 1
  }
}
```

**参数**: 同 `enable`

---

### 4. 急停 (estop)

发送紧急停止命令，立即停止所有电机。

**请求**:
```json
{
  "cmd": "estop",
  "seq": 4,
  "ts": 1718000000
}
```

**参数**: 无

---

### 5. 点动开始 (jog_start)

启动电机点动运行。

**请求**:
```json
{
  "cmd": "jog_start",
  "seq": 5,
  "ts": 1718000000,
  "payload": {
	"node": 1,
	"direction": "cw",
	"speed": 500
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| node | int | CANopen 节点 ID |
| direction | string | 方向: "cw" 顺时针, "ccw" 逆时针 |
| speed | int | 原始速度值（当前界面单位 `pulse/s`） |

---

### 6. 点动停止 (jog_stop)

停止电机点动运行。

**请求**:
```json
{
  "cmd": "jog_stop",
  "seq": 6,
  "ts": 1718000000,
  "payload": {
	"node": 1
  }
}
```

---

### 7. SDO 读取 (sdo_read)

读取电机驱动器的对象字典条目。

**请求**:
```json
{
  "cmd": "sdo_read",
  "seq": 7,
  "ts": 1718000000,
  "payload": {
	"node": 1,
	"index": 24672,
	"sub": 0
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| node | int | CANopen 节点 ID |
| index | int | 对象字典索引 (十进制) |
| sub | int | 子索引，默认 0 |

**常用索引**:
| 索引 | 名称 | 说明 |
|------|------|------|
| 0x6060 | 模式 | 驱动模式 |
| 0x6040 | 控制字 | CiA 402 控制字 |
| 0x60FF | 目标速度 | 当前系统原始速度值 / pulse/s |
| 0x6071 | 目标转矩 | 千分比 |
| 0x2010 | PID Kp | 比例系数 |
| 0x2011 | PID Ki | 积分系数 |
| 0x2012 | PID Kd | 微分系数 |
| 0x2013 | 电流限制 | 安培 |

**响应**:
```json
{
  "cmd": "sdo_read_result",
  "payload": {
	"index": 24672,
	"data": "0x08"
  }
}
```

---

### 8. SDO 写入 (sdo_write)

写入电机驱动器的对象字典条目。

**请求**:
```json
{
  "cmd": "sdo_write",
  "seq": 8,
  "ts": 1718000000,
  "payload": {
	"node": 1,
	"index": 24672,
	"sub": 0,
	"data": 8
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| node | int | CANopen 节点 ID |
| index | int | 对象字典索引 |
| sub | int | 子索引 |
| data | int | 写入值 (十六进制或十进制) |

**特殊写入**:
- 保存 EEPROM: index=0x1010, sub=1, data=0x65766173 ("save" 的 ASCII)

---

### 9. OTA 开始 (ota_start)

开始固件 OTA 升级传输。

> **实验功能**：当前 UDP 分块没有逐块 ACK、重传或断点续传，不应作为可靠生产
> 升级链路。UI 在刷写前要求二次确认。

**请求**:
```json
{
  "cmd": "ota_start",
  "seq": 9,
  "ts": 1718000000,
  "payload": {
	"size": 64821760,
	"md5": "d41d8cd98f00b204e9800998ecf8427e"
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| size | int | 固件文件大小 (字节) |
| md5 | string | 固件 MD5 校验值 |

---

### 10. OTA 数据块 (ota_chunk)

发送固件数据块。

**请求**:
```json
{
  "cmd": "ota_chunk",
  "seq": 10,
  "ts": 1718000000,
  "payload": {
	"offset": 0,
	"data": "SGVsbG8gV29ybGQ=..."
  }
}
```

**参数**:
| 字段 | 类型 | 说明 |
|------|------|------|
| offset | int | 数据偏移量 (字节) |
| data | string | Base64 编码的固件数据块 |

**配置**:
- 数据块大小: 512 字节
- 发送间隔: 10ms

---

### 11. OTA 校验 (ota_verify)

请求网关校验已传输的固件 MD5。

**请求**:
```json
{
  "cmd": "ota_verify",
  "seq": 11,
  "ts": 1718000000
}
```

---

### 12. OTA 刷写 (ota_flash)

命令网关将固件刷写到电机驱动器。

**请求**:
```json
{
  "cmd": "ota_flash",
  "seq": 12,
  "ts": 1718000000,
  "payload": {
	"node": 1
  }
}
```

---

## 网关上报消息

### 电机状态 (motor_status)

网关周期性上报电机实时状态。

```json
{
  "cmd": "motor_status",
  "payload": {
	"current": 1.25,
	"voltage": 24.5,
	"speed": 1500,
	"position": 180.5,
	"torque": 0.75,
	"status_word": 39,
	"fault": 0,
	"mode": 8,
	"alive": true,
	"wdg_ms": 150
  }
}
```

**字段说明**:
| 字段 | 类型 | 单位 | 说明 |
|------|------|------|------|
| current | float | A | 相电流 |
| voltage | float | V | 母线电压 |
| speed | int | pulse/s | 当前系统原始速度 |
| position | float | deg | 位置角度 |
| torque | float | Nm | 输出转矩 |
| status_word | int | - | CiA 402 状态字 |
| fault | int | - | 故障码 (0=正常) |
| mode | int | - | 运行模式 |
| alive | bool | - | 驱动器在线状态 |
| wdg_ms | int | ms | 看门狗剩余时间 |

**CiA 402 状态字解析**:
| 状态字 | 含义 |
|--------|------|
| 0x0000 | Not Ready |
| 0x0040 | Switch Off |
| 0x0021 | Ready |
| 0x0023 | Switched On |
| 0x0027 | Enabled |
| 0x0008 | FAULT |

---

### OTA 状态 (ota_status)

OTA 升级过程中的状态上报。

```json
{
  "cmd": "ota_status",
  "payload": {
	"state": "done"
  }
}
```

**state 值**:
| 值 | 说明 |
|----|------|
| done | 刷写完成 |
| error | 刷写失败 |

---

## 错误处理

所有命令都可能返回 `ack` 消息，包含状态和错误信息。

```json
{
  "cmd": "ack",
  "payload": {
	"status": "error",
	"msg": "SDO timeout"
  }
}
```

**常见错误**:
- `SDO timeout`: SDO 通信超时
- `Invalid index`: 对象字典索引无效
- `Flash failed`: 固件刷写失败
- `MD5 mismatch`: 固件校验失败

---

## 通信流程示例

### 启动流程
```
终端 → 网关: heartbeat (每150ms)
网关 → 终端: motor_status (周期上报)
```

### 电机控制流程
```
终端 → 网关: enable {"node": 1}
网关 → 终端: ack {"status": "ok"}
终端 → 网关: jog_start {"node": 1, "direction": "cw", "speed": 500}
网关 → 终端: ack {"status": "ok"}
终端 → 网关: jog_stop {"node": 1}
网关 → 终端: ack {"status": "ok"}
```

### OTA 升级流程
```
终端 → 网关: ota_start {"size": 64821760, "md5": "..."}
终端 → 网关: ota_chunk {"offset": 0, "data": "base64..."}
终端 → 网关: ota_chunk {"offset": 512, "data": "base64..."}
...
终端 → 网关: ota_verify
终端 → 网关: ota_flash {"node": 1}
网关 → 终端: ota_status {"state": "done"}
```
