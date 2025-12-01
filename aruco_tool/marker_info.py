from PySide6.QtCore import QObject, Signal, Property, Slot, QSizeF
from PySide6.QtGui import QPainter, QPdfWriter, QPageSize
from PySide6.QtQml import QmlElement

from .utils import ARUCO_DICT, BORDER_SIZE, get_module_counts
from .image_provider import ArUcoImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1


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
            marker_id, self._marker_size+self._border_size*2)
        on_modules, off_modules = get_module_counts(self._marker_matrix)
        if on_modules != self._on_modules:
            self._on_modules = on_modules
            self.on_modules_changed.emit(self._on_modules)
        if off_modules != self._off_modules:
            self._off_modules = off_modules
            self.off_modules_changed.emit(self._off_modules)

    @Slot(list, str)
    def generate_pdf(self, marker_ids: list[int], filename: str) -> None:
        if len(marker_ids) != 4:
            print(f"Requires 4 markers per page, but you passed in {len(marker_ids)}.")
            return
        provider = ArUcoImageProvider.instance()
        marker_image_size_mm = 14
        dot_size = int(marker_image_size_mm * 300 / 25.4)  # 300 DPI
        images = [ provider.createImage(
            ARUCO_DICT.generateImageMarker(mid, self._marker_size+self._border_size*2),
            dot_size, dot_size) for mid in marker_ids ]
        pdf_writer = QPdfWriter(filename)
        pdf_writer.setPageSize(QPageSize(QPageSize.PageSizeId.Letter))
        pdf_writer.setResolution(300)
        painter = QPainter(pdf_writer)
        # Positon the markers at the corners of the page
        positions = [
            (50, 50),
            (pdf_writer.width() - 50 - dot_size, 50),
            (50, pdf_writer.height() - 50 - dot_size),
            (pdf_writer.width() - 50 - dot_size,
             pdf_writer.height() - 50 - dot_size)
        ]
        for img, pos in zip(images, positions):
            painter.drawImage(pos[0], pos[1], img)
        painter.end()

    marker_id = Property(int, get_marker_id, set_marker_id, notify=marker_id_changed)
    marker_size = Property(int, get_marker_size, notify=marker_size_changed)
    border_size = Property(int, get_border_size, notify=border_size_changed)
    on_modules = Property(int, get_on_modules, notify=on_modules_changed)
    off_modules = Property(int, get_off_modules, notify=off_modules_changed)
