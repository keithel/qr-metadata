import os
import cv2
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QMarginsF
from PySide6.QtGui import QPainter, QPdfWriter, QPageSize
from PySide6.QtQml import QmlElement

from .utils import ARUCO_DICT, BORDER_SIZE
from .image_provider import ArUcoImageProvider

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1

# Predefined templates for marker placement
# Each template defines the page size, marker IDs to use, and margin in mm
# The markerIDs are in the order: Top-Left, Top-Right, Bottom-Left, Bottom-Right
# Note: This is *not* how OpenCV orders points in detected ArUco markers.
TEMPLATES = {
    "Letter": {
        "ids": [0, 1, 2, 3],
        "pageSizeId": QPageSize.PageSizeId.Letter,
        "margin_mm": 10,
        "marker_image_mm_size": 14
    },
    "Postcard": {
        "ids": [4, 5, 6, 7],
        "pageSizeId": QPageSize.PageSizeId.Postcard,
        "margin_mm": 5,
        "marker_image_mm_size": 10
    }
}

@QmlElement
class ArUcoHomography(QObject):
    detectionsChanged = Signal()
    templateChanged = Signal(str)

    def __init__(self):
        super().__init__()
        self._detections = []
        # Default template is the first one in the TEMPLATES dict
        current_template_name = TEMPLATES.keys().__iter__().__next__()

        # Intilize geometry with default template
        self._dpi = 300  # Dots per inch for PDF generation
        self._set_template(current_template_name, emit_signal=False)

    @Slot(str, result=int)
    def getPreviewMarkerId(self, template_name: str) -> int:
        if template_name in TEMPLATES:
            return TEMPLATES[template_name]["ids"][0]
        return 0

    @Slot(str)
    def detectFromFile(self, file_url_str: str):
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

        if ids is None:
            if len(self._detections) > 0:
                self._detections = []
                self.detectionsChanged.emit()
            return

        flat_ids = ids.flatten()

        found_template = None
        valid_corners = {} # Map ID -> Corner Data

        for name, conf in TEMPLATES.items():
            required_ids = conf["ids"]
            if set(required_ids).issubset(set(flat_ids)):
                found_template = name
                break

        new_detections = []

        if found_template:
            print(f"Found template: {found_template}")
            self._set_template(found_template)

            for i, marker_id in enumerate(flat_ids):
                valid_corners[marker_id] = corners[i][0]

            required_ids = TEMPLATES[found_template]["ids"]

            for role_idx, marker_id in enumerate(required_ids):
                c = valid_corners[marker_id]
                roles = ["TL", "TR", "BL", "BR"]
                role_name = roles[role_idx]

                new_detections.append({
                    "id": int(marker_id),
                    "role": role_name,
                    "tl": c[0].tolist(),
                    "tr": c[1].tolist(),
                    "br": c[2].tolist(),
                    "bl": c[3].tolist(),
                    "positionStr": f"{role_name}: ({int(c[0][0])},{int(c[0][1])})"
                })
        else:
            print("Validation Failed: No matching template found.")
            self._current_template_name = ""
            self.templateChanged.emit("")

            # Fallback: report all detected markers without roles
            for i, marker_id in enumerate(flat_ids):
                c = corners[i][0]
                new_detections.append({
                    "id": int(marker_id),
                    "role": "N/A",
                    "tl": c[0].tolist(),
                    "tr": c[1].tolist(),
                    "br": c[2].tolist(),
                    "bl": c[3].tolist(),
                    "positionStr": f"({int(c[0][0])},{int(c[0][1])})"
                })

        if new_detections != self._detections:
            self._detections = new_detections
            self.detectionsChanged.emit()

    @Slot(str, str)
    def generate_template_pdf(self, template_name: str, filename: str) -> None:
        if template_name not in TEMPLATES:
            print(f"Unknown template: {template_name}")
            return
        self._set_template(template_name)
        self.generate_pdf(TEMPLATES[template_name]["ids"], filename)

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

    def _set_template(self, template_name: str, emit_signal: bool = True) -> None:
        if template_name not in TEMPLATES:
            print(f"Unknown template: {template_name}")
            return

        if hasattr(self, "_current_template_name") and template_name == self._current_template_name:
            print(f"Template {template_name} is already set.")
            return

        self._current_template_name = template_name

        conf = TEMPLATES[template_name]
        self._page_size = QPageSize(conf["pageSizeId"])
        ps_pixels = self._page_size.sizePixels(self._dpi)
        margin_pixels = self._mm_to_dots(conf["margin_mm"])

        self._marker_image_dot_size = self._mm_to_dots(conf["marker_image_mm_size"])

        w = ps_pixels.width()
        h = ps_pixels.height()
        marker_dotsize = self._marker_image_dot_size
        m = margin_pixels

        self._template_marker_positions = [
            (m, m),
            (w - m - marker_dotsize, m),
            (m, h - m - marker_dotsize),
            (w - m - marker_dotsize, h - m - marker_dotsize)
        ]

        if emit_signal:
            self.templateChanged.emit(template_name)

    def _setup_pdf_writer(self, filename: str) -> QPdfWriter:
        pdf_writer = QPdfWriter(filename)
        pdf_writer.setPageSize(self._page_size)
        pdf_writer.setResolution(self._dpi)
        pdf_writer.setPageMargins(QMarginsF(0,0,0,0))
        return pdf_writer

    def _mm_to_dots(self, mm: float) -> int:
        return int(mm * self._dpi / 25.4)

    # Using QVariantList to pass list of dicts to QML
    @Property('QVariantList', notify=detectionsChanged)
    def detections(self):
        return self._detections

    @Property(list, constant=True)
    def availableTemplates(self):
        return list(TEMPLATES.keys())

    @Property(str, notify=templateChanged)
    def template(self) -> str:
        return self._current_template_name
