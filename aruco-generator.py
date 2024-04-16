import sys
import os
from pathlib import Path
from functools import reduce

import cv2
import numpy as np
from PySide6.QtCore import QObject, QSize, Qt, QRect, Signal, Property
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QPen, QBrush
from PySide6.QtQml import QQmlApplicationEngine, QQmlImageProviderBase, QmlElement
from PySide6.QtQuick import QQuickImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1

# Use a 4x4 dictionary (simple, distinct markers)
ARUCO_DICT = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
BORDER_SIZE = 1

def get_module_counts(marker_matrix) -> tuple[int, int]:
    on_modules = reduce(lambda x,y: x + sum(y/255), marker_matrix, 0)
    off_modules = reduce(lambda x,y: x + len(y), marker_matrix, 0) - on_modules
    return (on_modules, off_modules)
    
def get_row_module_counts(marker_matrix) -> list[tuple[int,int]]:
    ret = []
    for row in marker_matrix:
        on_modules = reduce(lambda x,y: x+y, row, 0)
        off_modules = len(row)-on_modules
        ret.append((on_modules, off_modules))
    return ret

class ArUcoImageProvider(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQmlImageProviderBase.ImageType.Image)

    def createImage(self, marker_matrix: np.ndarray, width: int, height: int) -> QImage:
        rows, cols = marker_matrix.shape
        square_size = min(width, height) // rows

        offset_x = (width - cols * square_size) // 2
        offset_y = (height - rows * square_size) // 2

        img = QImage(width, height, QImage.Format.Format_Mono)
        img.setColorCount(2)
        img.setColor(0, 0xFF000000)
        img.setColor(1, 0xFFFFFFFF)
        if img.isNull():
            return img

        img.fill(img.color(1))
        painter = QPainter(img)

        # Just fill - no pen
        painter.setPen(Qt.PenStyle.NoPen)

        for y in range(rows):
            for x in range(cols):
                is_black = (marker_matrix[y, x] == 0)

                if is_black:
                    squareX = offset_x + x * square_size
                    squareY = offset_y + y * square_size

                    brush = QBrush(img.color(0))
                    painter.setBrush(brush)
                    painter.drawRect(QRect(squareX, squareY, *([square_size]*2)))
        painter.end()
        return img

    def requestImage(self, id, size, requestedSize):
        side_bits = ARUCO_DICT.markerSize + BORDER_SIZE*2
        width = height = side_bits

        # The size must be set to the original size of the image.
        if size is not None:
            size.setWidth(width)
            size.setHeight(height)

        if requestedSize.isValid():
            width = requestedSize.width()
            height = requestedSize.height()

        try:
            marker_id = int(id)
        except ValueError:
            marker_id = 0

        print(f"requestImage({id}, {size}, {requestedSize})")
        marker_matrix = ARUCO_DICT.generateImageMarker(marker_id, side_bits)
        image = self.createImage(marker_matrix, width, height)
        return image


@QmlElement
class MarkerInfo(QObject):
    marker_id_changed = Signal(int)
    marker_size_changed = Signal(int)
    border_size_changed = Signal(int)
    on_modules_changed = Signal(int)
    off_modules_changed = Signal(int)

    def __init__(self):
        super().__init__()
        self._marker_id: int = 0
        self._marker_size: int = ARUCO_DICT.markerSize
        self._border_size: int = BORDER_SIZE
        self._on_modules = 0
        self._off_modules = 0

    def get_marker_id(self) -> int:
        return self._marker_id

    def get_marker_size(self) -> int:
        return self._marker_size

    def get_border_size(self) -> int:
        return self._border_size

    def get_on_modules(self) -> int:
        return self._on_modules

    def get_off_modules(self) -> int:
        return self._off_modules

    def set_marker_id(self, marker_id: int) -> None:
        self._marker_id = marker_id
        self.marker_id_changed.emit(self._marker_id)
        self._marker_matrix = ARUCO_DICT.generateImageMarker(
            marker_id, self._marker_size+self.border_size*2)
        on_modules, off_modules = get_module_counts(self._marker_matrix)
        if on_modules != self._on_modules:
            self._on_modules = on_modules
            self.on_modules_changed.emit(self._on_modules)
        if off_modules != self._off_modules:
            self._off_modules = off_modules
            self.off_modules_changed.emit(self._off_modules)

    marker_id = Property(int, get_marker_id, set_marker_id, notify=marker_id_changed)
    marker_size = Property(int, get_marker_size, notify=marker_size_changed)
    border_size = Property(int, get_border_size, notify=border_size_changed)
    on_modules = Property(int, get_on_modules, notify=on_modules_changed)
    off_modules = Property(int, get_off_modules, notify=off_modules_changed)


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImageProvider("aruco", ArUcoImageProvider())
    engine.load(os.fspath(Path(__file__).resolve().parent / "main.qml"))

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
