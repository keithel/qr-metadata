import importlib
import importlib.resources
import sys
import os
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from .image_provider import ArUcoImageProvider
from .marker_info import MarkerInfo # type: ignore
from .aruco_homography import ArUcoHomography # type: ignore


def start_app():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    engine.addImageProvider("aruco", ArUcoImageProvider.instance())
    qml_file = importlib.resources.files("aruco_tool") / "main.qml"
    engine.load(os.fspath(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())

if __name__ == "__main__":
    start_app()