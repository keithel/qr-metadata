import os
import cv2
import numpy as np
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QMarginsF
from PySide6.QtCore import Qt
from PySide6.QtGui import QPainter, QPdfWriter, QPageSize, QTransform, QImage
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

CM_PER_INCH = 2.54
INCH_PER_METER = 1 / (CM_PER_INCH/100)

@QmlElement
class ArUcoHomography(QObject):
    detectionsChanged = Signal()
    templateChanged = Signal(str)
    templateMarkerIdsChanged = Signal()
    transformChanged = Signal()

    def __init__(self):
        super().__init__()
        self._detections = []
        self._current_qtransform = QTransform() # Identity by default

        # Default template is the first one in the TEMPLATES dict
        current_template_name = list(TEMPLATES.keys())[0]

        # Intilize geometry with default template
        self._dpi = 300  # Dots per inch for PDF generation
        self._set_template(current_template_name, emit_signal=False)

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

            # Init the point arrays we're converting from and to
            src_points = []
            dst_points = []

            for i, marker_id in enumerate(flat_ids):
                valid_corners[marker_id] = corners[i][0]

            required_ids = TEMPLATES[found_template]["ids"]

            # Roles order matches TEMPLATES def of TL, TR, BL, BR
            roles = ["TL", "TR", "BL", "BR"]

            for role_idx, marker_id in enumerate(required_ids):
                # Fill in the corner points for each detected marker - a 2d array of 4 points
                # TL, TR, BR, BL (Clockwise)
                c = valid_corners[marker_id]
                src_points.extend(c)

                # Fill in the destination corner points from the template markers - same layout
                # - TL, TR, BR, BL using the top left coordinate + the size of the template image
                # in dots.  Note: TL is the top left point of the ArUco marker.
                tx, ty = self._template_marker_positions[role_idx]
                ts = self._marker_image_dot_size

                marker_dst = [
                    [tx, ty],           # TL
                    [tx + ts, ty],      # TR
                    [tx + ts, ty + ts], # BR
                    [tx, ty + ts]       # BL
                ]
                dst_points.extend(marker_dst)

                # Put it into the property that QML is using.
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

            # Use the source and destination points to calculate the QTransform.
            self._calculate_homography(src_points, dst_points)

        else:
            print("Validation Failed: No matching template found.")
            self._current_template_name = ""
            self.templateChanged.emit("")

            # Reset Transform
            self._current_qtransform = QTransform()
            self.transformChanged.emit()

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

    def _calculate_homography(self, src_list, dst_list):
        if not src_list or len(src_list) < 4:
            return

        src_arr = np.array(src_list, dtype=np.float32)
        dst_arr = np.array(dst_list, dtype=np.float32)

        # Calculate homography: Maps image coordinates to template coordinates
        h_matrix, status = cv2.findHomography(src_arr, dst_arr)

        if h_matrix is not None:
            # Flatten 3x3 matrix
            h = h_matrix.flatten()

            # Create QTransform
            # QTransform(m11, m12, m13, m21, m22, m23, m31, m32, m33)
            # Mapping:
            # m11=h00, m12=h10, m13=h20
            # m21=h01, m22=h11, m23=h21
            # m31=h02, m32=h12, m33=h22

            self._current_qtransform = QTransform(
                h[0], h[3], h[6],
                h[1], h[4], h[7],
                h[2], h[5], h[8]
            )
            print("Homography calculated successfully.")
            print(self._current_qtransform)
            self.transformChanged.emit()
        else:
            print("Homography calculation failed.")

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

    @Slot(str, str, result=bool)
    def save_sketch(self, source_file_url: str, output_path: str) -> bool:
        """
        Uses the calculated homography to warp the source image onto a flat page and saves the
        result.

        :param source_file_url: path to image to warp
        :type source_file_url: str
        :param output_path: path tp save the resultant warped image to.
        :type output_path: str
        :return: True if warped image was saved, false otherwise.
        :rtype: bool
        """
        if self._current_qtransform.isIdentity():
            print("No valid transform available.")
            return False

        source_path = QUrl(source_file_url).toLocalFile()
        if not os.path.exists(source_path):
            print(f"Source file not found: {source_path}")
            return False

        src_img = cv2.imread(source_path)
        if src_img is None:
            print(f"Failed to read source file: {source_path}")
            return False

        # Convert OpenCV (BGR) to QImage (RGB) for QPainter
        src_img = cv2.cvtColor(src_img, cv2.COLOR_BGR2RGB)
        h, w, ch = src_img.shape
        bytes_per_line = ch * w

        q_src_img = QImage(src_img.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)

        # Use the template dimensions
        page_size_pixels = self._page_size.sizePixels(self._dpi)
        dest_img = QImage(page_size_pixels, QImage.Format.Format_ARGB32)
        dpm = round(self._dpi * INCH_PER_METER)
        dest_img.setDotsPerMeterX(dpm)
        dest_img.setDotsPerMeterY(dpm)
        dest_img.fill(Qt.GlobalColor.white) # Paper background

        painter = QPainter(dest_img)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

        # Apply homography transform - mapping source coords to dest coords
        painter.setTransform(self._current_qtransform)

        # Draw the source image at the top left of dest image.
        # The transform projects it onto the page.
        painter.drawImage(0, 0, q_src_img)
        painter.end()

        # Save the transformed image
        save_loc = QUrl(output_path).toLocalFile() if output_path.startswith("file:") else output_path
        save_res = dest_img.save(save_loc)
        if not save_res:
            print(f"Failed to save {save_loc}, QImage.save failed.")
        return save_res

    @Slot(result=bool)
    def transformIsIdentity(self):
        return self._current_qtransform.isIdentity()

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
            self.templateMarkerIdsChanged.emit()

    def _setup_pdf_writer(self, filename: str) -> QPdfWriter:
        pdf_writer = QPdfWriter(filename)
        pdf_writer.setPageSize(self._page_size)
        pdf_writer.setResolution(self._dpi)
        pdf_writer.setPageMargins(QMarginsF(0,0,0,0))
        return pdf_writer

    def _mm_to_dots(self, mm: float) -> int:
        return int(mm * self._dpi / 25.4)

    # Using QVariantList to pass list of dicts to QML
    @Property(list, notify=detectionsChanged)
    def detections(self):
        return self._detections

    @Property(list, constant=True)
    def availableTemplates(self):
        return list(TEMPLATES.keys())

    @Property(str, notify=templateChanged)
    def template(self) -> str:
        return self._current_template_name

    @template.setter
    def template(self, new_template: str):
        self._set_template(new_template)

    @Property(list, notify=templateMarkerIdsChanged)
    def templateMarkerIds(self) -> list[int]:
        template_name = self._current_template_name
        if template_name in TEMPLATES:
            return [int(id) for id in TEMPLATES[template_name]["ids"]]
        return []

    # If we want to draw something on the transformed image.
    @Property(list, notify=transformChanged)
    def homographyMatrix(self):
        """Returns the QTransform values as a flat list [m11, m12, ... m33].
           Useful for QML Matrix4x4 construction or debug."""
        t = self._current_qtransform
        return [
            t.m11(), t.m12(), t.m13(),
            t.m21(), t.m22(), t.m23(),
            t.m31(), t.m32(), t.m33()
        ]