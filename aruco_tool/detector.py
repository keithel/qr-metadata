import os
import cv2
from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl
from PySide6.QtQml import QmlElement

from .utils import ARUCO_DICT

QML_IMPORT_NAME = "io.qt.dev"
QML_IMPORT_MAJOR_VERSION = 1

@QmlElement
class ArUcoDetector(QObject):
    detectionsChanged = Signal()

    def __init__(self):
        super().__init__()
        self._detections = []

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
                pos_str = f"TL({int(c[0][0])},{int(c[0][1])}) TR({int(c[1][0])},{int(c[1][1])})"

                new_detections.append({
                    "id": int(marker_id),
                    "position": pos_str
                })

        self._detections = new_detections
        self.detectionsChanged.emit()
