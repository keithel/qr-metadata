import sys
import os
from pathlib import Path
from functools import reduce

import qrcode
from PySide6.QtCore import QObject, QSize, Qt, QRect, Signal, Property
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QPen, QBrush
from PySide6.QtQml import QQmlApplicationEngine, QQmlImageProviderBase, QmlElement
from PySide6.QtQuick import QQuickImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1

QR_DATA_FORMAT_STR = "WIFI:T:WPA;S:{};P:{};;"

def get_module_counts(qr: qrcode.QRCode) -> tuple[int, int]:
    qr.get_matrix()
    on_modules = reduce(lambda x,y: x + sum(y), qr.modules, 0)
    off_modules = reduce(lambda x,y: x + len(y), qr.modules, 0) - on_modules
    return (on_modules, off_modules)

def get_row_module_counts(qr: qrcode.QRCode) -> list[tuple[int,int]]:
    qr.get_matrix()
    ret = []
    for row in qr.modules:
        on_modules = reduce(lambda x,y: x+y, row, 0)
        off_modules = len(row)-on_modules
        ret.append((on_modules, off_modules))
    return ret

class WiFiQRCodeImageProvider(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQmlImageProviderBase.ImageType.Image)

    def createImage(self, qr: qrcode.QRCode, width: int, height: int) -> QImage:
        h = height
        w = width
        data_size = len(qr.modules)
        square_size = min(w,h) // data_size
        offsetX = (w-data_size * square_size) // 2
        offsetY = (h-data_size * square_size) // 2

        img = QImage(w,h, QImage.Format.Format_Mono)
        if img.isNull():
            return img

        img.fill(Qt.GlobalColor.black)
        painter = QPainter(img)

        for y, row in enumerate(qr.modules):
            for x, col in enumerate(row):
                squareX = offsetX + x * square_size
                squareY = offsetY + y * square_size
                pen = QPen(Qt.GlobalColor.black if col else Qt.GlobalColor.white, 1)
                painter.setPen(pen)
                brush = QBrush(Qt.GlobalColor.black if col else Qt.GlobalColor.white)
                painter.setBrush(brush)
                painter.drawRect(QRect(squareX, squareY, square_size, square_size))
        # img.save("testimg.png")
        return img


    def requestImage(self, id, size, requestedSize):
        width = 29
        height = 29

        # The size must be set to the original size of the image.
        if size is not None:
            size = QSize(width, height)

        if requestedSize.isValid():
            width = requestedSize.width()
            height = requestedSize.height()

        ssid_pw = id.split("/", maxsplit=1)
        qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_L)
        qr.add_data(QR_DATA_FORMAT_STR.format(*ssid_pw))
        qr.get_matrix()
        image = self.createImage(qr, width, height)
        return image


@QmlElement
class QRCodeInfo(QObject):
    ssid_changed = Signal(str)
    ssid_pw_changed = Signal(str)
    size_changed = Signal(int)
    on_modules_changed = Signal(int)
    off_modules_changed = Signal(int)

    def __init__(self):
        super().__init__()
        self._ssid: str = ""
        self._ssid_pw: str = ""
        self._size: int = 0
        self._on_modules = 0
        self._off_modules = 0

    def updateQR(self) -> None:
        qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_L)
        qr.add_data(QR_DATA_FORMAT_STR.format(self._ssid, self._ssid_pw))
        qr.get_matrix()
        self._size = len(qr.modules)
        on_modules, off_modules = get_module_counts(qr)
        self.size_changed.emit(self._size)
        self.on_modules_changed.emit(self._on_modules)
        if on_modules != self._on_modules:
            self._on_modules = on_modules
            self.on_modules_changed.emit(self._on_modules)
        if off_modules != self._off_modules:
            self._off_modules = off_modules
            self.off_modules_changed.emit(self._off_modules)

    def get_ssid(self) -> str:
        return self._ssid

    def get_ssid_pw(self) -> str:
        return self._ssid_pw

    def get_size(self) -> int:
        return self._size

    def get_on_modules(self) -> int:
        return self._on_modules

    def get_off_modules(self) -> int:
        return self._off_modules

    def set_ssid(self, ssid: str) -> None:
        self._ssid = ssid
        self.updateQR()
        self.ssid_changed.emit(self._ssid)

    def set_ssid_pw(self, pw: str) -> None:
        self._ssid_pw = pw
        self.updateQR()
        self.ssid_pw_changed.emit(self._ssid_pw)

    ssid = Property(str, get_ssid, set_ssid, notify=ssid_changed)
    ssid_pw = Property(str, get_ssid_pw, set_ssid_pw, notify=ssid_pw_changed)
    size = Property(int, get_size, notify=size_changed)
    on_modules = Property(int, get_on_modules, notify=on_modules_changed)
    off_modules = Property(int, get_off_modules, notify=off_modules_changed)


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImageProvider("wifi_qr", WiFiQRCodeImageProvider())
    engine.load(os.fspath(Path(__file__).resolve().parent / "main.qml"))

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
