## 应用全局配置 - settings.gd
## 作用: 集中管理所有常量配置，包括网络参数、UI尺寸、输入映射等
## 被其他所有脚本引用，是项目的配置中心

extends RefCounted
class_name AppSettings

const DONGLE_IP = "192.168.4.1"
const DONGLE_UDP_PORT = 5000
const LOCAL_UDP_PORT = 5001
const HEARTBEAT_INTERVAL_MS = 150

const DEFAULT_NODE_ID = 1
const CAN_BAUDRATE = 500000

const OTA_CHUNK_SIZE = 512
const OTA_SEND_INTERVAL_MS = 10

const SCREEN_WIDTH = 720
const SCREEN_HEIGHT = 720
const FPS = 30
const WAVEFORM_HISTORY = 200

# Use "rgb30_raw" for the verified /dev/input/js0 IDs.
# Use "godot_standard" if Godot reports SDL-normalized joypad buttons.
const INPUT_PROFILE = "rgb30_raw"

const FIRMWARE_PATHS = [
	"/storage/firmware.bin",
	"/storage/update.bin",
	"/storage/motor_firmware.bin",
]

