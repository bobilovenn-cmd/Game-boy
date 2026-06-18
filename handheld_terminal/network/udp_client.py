"""udp_client.py — UDP 通信客户端，支持异步收发"""

import socket
import threading
import logging
from typing import Optional, Callable

from config import DONGLE_IP, DONGLE_UDP_PORT, LOCAL_UDP_PORT

logger = logging.getLogger(__name__)


class UDPClient:
    """与 CAN Dongle 的 UDP 通信客户端

    使用回调函数将收到的数据传递给调用方。
    """

    def __init__(self):
        self._sock: Optional[socket.socket] = None
        self._running = False
        self._recv_thread: Optional[threading.Thread] = None
        self._connected = False
        self._recv_callback: Optional[Callable[[str], None]] = None
        self._conn_callback: Optional[Callable[[bool], None]] = None

    def set_callbacks(self, on_data: Callable[[str], None],
                      on_connection: Callable[[bool], None]):
        self._recv_callback = on_data
        self._conn_callback = on_connection

    def start(self) -> bool:
        try:
            self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self._sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self._sock.settimeout(0.5)
            self._sock.bind(("0.0.0.0", LOCAL_UDP_PORT))

            self._running = True
            self._recv_thread = threading.Thread(
                target=self._recv_loop, daemon=True
            )
            self._recv_thread.start()
            logger.info(f"UDP 客户端启动，监听端口 {LOCAL_UDP_PORT}")
            return True
        except Exception as e:
            logger.error(f"UDP 客户端启动失败: {e}")
            return False

    def stop(self):
        self._running = False
        if self._sock:
            self._sock.close()
            self._sock = None

    def send(self, data: str):
        if not self._sock:
            return False
        try:
            self._sock.sendto(
                data.encode("utf-8"),
                (DONGLE_IP, DONGLE_UDP_PORT)
            )
            return True
        except Exception as e:
            logger.error(f"发送失败: {e}")
            return False

    def is_connected(self) -> bool:
        return self._connected

    def _recv_loop(self):
        while self._running:
            try:
                data, addr = self._sock.recvfrom(2048)
                if data:
                    msg = data.decode("utf-8")
                    if self._recv_callback:
                        self._recv_callback(msg)
                    if not self._connected:
                        self._connected = True
                        if self._conn_callback:
                            self._conn_callback(True)
            except socket.timeout:
                continue
            except OSError:
                if self._running:
                    logger.error("Socket 异常关闭")
                break
        self._connected = False
        if self._conn_callback:
            self._conn_callback(False)
