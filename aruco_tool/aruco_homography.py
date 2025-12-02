import os
import cv2
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QMarginsF
from PySide6.QtGui import QPainter, QPdfWriter, QPageSize
from PySide6.QtQml import QmlElement

from .utils import ARUCO_DICT, BORDER_SIZE
from .image_provider import ArUcoImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1

@QmlElement
class ArUcoHomography(QObject):
    detectionsChanged = Signal()

    def __init__(self):
        super().__init__()
        self._detections = []

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

    # Using QVariantList to pass list of dicts to QML
    @Property('QVariantList', notify=detectionsChanged)
    def detections(self):
        return self._detections

    @Slot(str)
    def detectFromFile(self, file_url_str):
        # Handle QML file URL (file:///...)
        file_path = QUrl(file_url_str).toLocalFile()

        if not os.path.exists(file_path):
            print(f"File not found: {file_path}")
            return

        img = cv2.imread(file_path)
        if img is None:
            print("Failed to load image")
            return

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        parameters = cv2.aruco.DetectorParameters()
        detector = cv2.aruco.ArucoDetector(ARUCO_DICT, parameters)

        corners, ids, rejected = detector.detectMarkers(gray)

        new_detections = []

        if ids is not None:
            ids = ids.flatten()
            for i, marker_id in enumerate(ids):
                # corners[i] shape is (1, 4, 2)
                c = corners[i][0]

                # Format simple string for display: TL(x,y)
                pos_str = f"TL({int(c[0][0])},{int(c[0][1])}) BR({int(c[2][0])},{int(c[2][1])})"

                new_detections.append({
                    "id": int(marker_id),
                    "tl": c[0].tolist(),
                    "tr": c[1].tolist(),
                    "br": c[2].tolist(),
                    "bl": c[3].tolist(),
                    "positionStr": pos_str
                })

        self._detections = new_detections
        self.detectionsChanged.emit()

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

    def _setup_pdf_writer(self, filename: str) -> QPdfWriter:
        pdf_writer = QPdfWriter(filename)
        pdf_writer.setPageSize(self._page_size)
        pdf_writer.setResolution(self._dpi)
        pdf_writer.setPageMargins(QMarginsF(0,0,0,0))
        return pdf_writer

    def _mm_to_dots(self, mm: float) -> int:
        return int(mm * self._dpi / 25.4)