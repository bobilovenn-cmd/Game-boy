cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(can_dongle)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/wifi_secrets.h")
  target_compile_definitions(app PRIVATE DONGLE_USE_LOCAL_WIFI_SECRETS=1)
endif()

target_sources(app PRIVATE
  src/main.c
  src/command_handler.c
  src/command_policy.c
  src/motor_status_policy.c
  src/telemetry.c
  src/telemetry_policy.c
  src/sdo_transport.c
  src/udp_comm.c
  src/can_raw.c
  src/canopen_basic.c
  src/json_protocol.c
  src/watchdog.c
)
