extends RefCounted

# Core protocol and configuration
const AppSettings = preload("res://scripts/settings.gd")
const Protocol = preload("res://scripts/protocol.gd")
const UiText = preload("res://scripts/ui_text.gd")
const UiConfig = preload("res://scripts/app/ui_config.gd")
const AppBootstrap = preload("res://scripts/app/app_bootstrap.gd")

# Protocol services
const UdpClient = preload("res://scripts/protocol/udp_client.gd")
const CanLogFormatter = preload("res://scripts/protocol/can_log_formatter.gd")
const MessageDispatcher = preload("res://scripts/protocol/message_dispatcher.gd")

# Controllers
const MotorController = preload("res://scripts/controllers/motor_controller.gd")
const UploadModeController = preload("res://scripts/controllers/upload_mode_controller.gd")
const NodeSelectorController = preload("res://scripts/controllers/node_selector_controller.gd")
const NumericInputController = preload("res://scripts/controllers/numeric_input_controller.gd")
const CanFilterController = preload("res://scripts/controllers/can_filter_controller.gd")
const NavigationController = preload("res://scripts/controllers/navigation_controller.gd")
const OtaTransferController = preload("res://scripts/controllers/ota_transfer_controller.gd")
const SessionController = preload("res://scripts/controllers/session_controller.gd")
const PageCommandController = preload("res://scripts/controllers/page_command_controller.gd")
const FirmwareController = preload("res://scripts/controllers/firmware_controller.gd")
const InteractionController = preload("res://scripts/controllers/interaction_controller.gd")
const RuntimeController = preload("res://scripts/controllers/runtime_controller.gd")

# Models
const MotorData = preload("res://scripts/motor_data.gd")
const CanLogState = preload("res://scripts/models/can_log_state.gd")
const ConnectionState = preload("res://scripts/models/connection_state.gd")
const OtaState = preload("res://scripts/models/ota_state.gd")
const StatusState = preload("res://scripts/models/status_state.gd")

# Input
const InputRouter = preload("res://scripts/input/input_router.gd")
const RawInputReader = preload("res://scripts/input/raw_input_reader.gd")

# Screens
const LanguageScreen = preload("res://scripts/screens/language_screen.gd")
const NodeSelectScreen = preload("res://scripts/screens/node_select_screen.gd")
const UploadModeScreen = preload("res://scripts/screens/upload_mode_screen.gd")
const AppChrome = preload("res://scripts/screens/app_chrome.gd")
const MonitorScreen = preload("res://scripts/screens/monitor_screen.gd")
const ConfigScreen = preload("res://scripts/screens/config_screen.gd")
const OtaScreen = preload("res://scripts/screens/ota_screen.gd")
const CanScreen = preload("res://scripts/screens/can_screen.gd")
const NumericInputScreen = preload("res://scripts/screens/numeric_input_screen.gd")
const FilterInputScreen = preload("res://scripts/screens/filter_input_screen.gd")
