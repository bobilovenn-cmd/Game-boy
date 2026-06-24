# ANT 蚂蚁操控模式归档

本目录保存从 RGB30 正式 UI 中暂时移除的“蚂蚁操控”模式代码与验证材料。

## 当前策略

- `godot_terminal/` 当前版本不再暴露蚂蚁模式入口，也不再打包蚂蚁模式脚本和车辆图片资产。
- 蚂蚁模式代码保存在本目录，后续需要重新接入 RGB30 时，从这里恢复并重新做协议、自动化和实体机验证。
- 当前归档不代表 ESP32 双轮控制协议已经完成；实际控制命令仍需后续固件协议明确后再接入。

## 文件内容

- `godot_module/scripts/screens/ant_control_screen.gd`：蚂蚁操控底层绘制。
- `godot_module/scripts/screens/ant_control_overlay.gd`：RGB30 实体渲染用文字覆盖层。
- `godot_module/scripts/models/ant_control_state.gd`：左右轮、摇杆、手刹和急停状态模型。
- `godot_module/scripts/controllers/ant_runtime_controller.gd`：蚂蚁模式 UDP/心跳/电机状态运行调度。
- `godot_module/tests/`：蚂蚁状态、覆盖层和轨迹方向测试。
- `godot_module/assets/ant_vehicle_top.png`：蚂蚁小车俯视图资源。
- `evidence/`：此前 RGB30 实体截图验证材料。

## 重新接入前必须确认

1. ESP32 双轮命令协议已定义：左轮 Node 1、右轮 Node 2、目标速度单位、原子性与部分失败策略。
2. 小车命令不得伪造遥测；所有速度、电流、转矩、状态必须来自事实数据及新鲜度标记。
3. 恢复到 RGB30 后必须运行 Godot 自动测试、Linux ARM64 导出和 RGB30 实体截图验证。
4. 不得未经验证直接推送 Azure `stage`。
