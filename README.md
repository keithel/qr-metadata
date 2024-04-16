# qr-metadata PySide6 tool that shows a QR Code plus some metadata about it

A simple PySide6 QML app that shows a QR Code (WiFi QR Code right now) plus some
metadata about the QR code, such as:

* The data encoded in the QR code (WiFi SSID and PW, as source info right now)
* The total number of modules (squares)
* The number of black modules
* The number of white modules

## Running
pip install -r requirements.txt
python qr-metadata.py
