import cv2
import numpy as np
from PySide6.QtCore import Qt, QRect
from PySide6.QtGui import QImage, QPainter, QBrush
from PySide6.QtQml import QQmlImageProviderBase
from PySide6.QtQuick import QQuickImageProvider
from .utils import ARUCO_DICT, BORDER_SIZE

class ArUcoImageProvider(QQuickImageProvider):
    _instance = None

    def __init__(self):
        super().__init__(QQmlImageProviderBase.ImageType.Image)

    @classmethod
    def instance(cls):
        if ArUcoImageProvider._instance is None:
            ArUcoImageProvider._instance = ArUcoImageProvider()
        return ArUcoImageProvider._instance

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

