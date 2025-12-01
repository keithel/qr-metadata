from PySide6.QtCore import QObject, Slot, QMarginsF
from PySide6.QtGui import QPainter, QPdfWriter, QPageSize
from PySide6.QtQml import QmlElement

from .utils import ARUCO_DICT, BORDER_SIZE
from .image_provider import ArUcoImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
class HomographyTools(QObject):
    def __init__(self):
        super().__init__()
        marker_image_mm_size = 14  # Size of marker in mm when printed
        self._dpi = 300  # Dots per inch for PDF generation
        self._marker_image_dot_size = self._mm_to_dots(marker_image_mm_size)

        self._page_size = QPageSize(QPageSize.PageSizeId.Letter)
        ps = self._page_size.sizePixels(self._dpi)
        # Positon the markers at the corners of the page
        marker_margin = 42 # Place markers right at the edge of the standard Letter page margin
        self._template_marker_positions = [
            (marker_margin, marker_margin),
            (ps.width() - marker_margin - self._marker_image_dot_size, marker_margin),
            (marker_margin, ps.height() - marker_margin - self._marker_image_dot_size),
            (ps.width() - marker_margin - self._marker_image_dot_size,
             ps.height() - marker_margin - self._marker_image_dot_size)
        ]

    def _setup_pdf_writer(self, filename: str) -> QPdfWriter:
        pdf_writer = QPdfWriter(filename)
        pdf_writer.setPageSize(self._page_size)
        pdf_writer.setResolution(self._dpi)
        pdf_writer.setPageMargins(QMarginsF(0,0,0,0))
        return pdf_writer

    @Slot(list, str)
    def generate_pdf(self, marker_ids: list[int], filename: str) -> None:
        if len(marker_ids) != 4:
            print(f"Requires 4 markers per page, but you passed in {len(marker_ids)}.")
            return
        provider = ArUcoImageProvider.instance()
        images = [ provider.createImage(
            ARUCO_DICT.generateImageMarker(mid, ARUCO_DICT.markerSize+BORDER_SIZE*2),
            self._marker_image_dot_size, self._marker_image_dot_size) for mid in marker_ids ]
        pdf_writer = self._setup_pdf_writer(filename)
        painter = QPainter(pdf_writer)
        for img, pos in zip(images, self._template_marker_positions):
            painter.drawImage(pos[0], pos[1], img)
        painter.end()

    def _mm_to_dots(self, mm: float) -> int:
        return int(mm * self._dpi / 25.4)