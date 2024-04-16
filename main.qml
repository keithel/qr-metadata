import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.qt.dev

ApplicationWindow {
    id: window
    visible: true
    width: 1024
    height: 768

    onClosing: function (close) {
    }

    Component.onCompleted: {
        image.source = Qt.binding(function() { return "image://wifi_qr/" + ssid + "/" + pw; } )
    }

    Component.onDestruction: {
        image.sourceSize.width = 1
        image.sourceSize.height = 1
    }

    title: qsTr("WiFi QR Code Generator")

    property real buttonFontPixelSize: (window.width <= 640) ? 18 : 27
    property real textFontPixelSize: (window.width <= 640) ? 18 : 27
    property alias ssid: ssidField.text
    property alias pw: pwField.text
    property string imagePathPrefix: ""

    QRCodeInfo {
        id: qrCodeInfo
        ssid: window.ssid
        ssid_pw: window.pw
        onSizeChanged: console.log("qrCodeInfo.size: " + size)
    }

    header: ToolBar {
    }

    Item {
        id: windowContent
        anchors.fill: parent
        anchors.margins: 10

        Image {
            id: image
            property int smallest_dimension: Math.min(width, height)
            property int bounded_smallest_dimension: smallest_dimension <= 1024 ? smallest_dimension : 1024
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
            sourceSize.height: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
            onSourceSizeChanged: console.log("sourceSize: " + sourceSize)
            onBounded_smallest_dimensionChanged: console.log("bounded_smallest_dimension: " + bounded_smallest_dimension)
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: descriptionAndButsLayout.top
                margins: 10
            }
            focus: true
        }

        ColumnLayout {
            id: descriptionAndButsLayout
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }

            RowLayout {
                Label {
                    // font.pixelSize: textFontPixelSize
                    text: "SSID"
                }
                TextField {
                    id: ssidField
                    // font.pixelSize: textFontPixelSize
                    text: "MyAP"
                }
                Label {
                    // font.pixelSize: textFontPixelSize
                    text: "Password"
                }
                TextField {
                    id: pwField
                    // font.pixelSize: textFontPixelSize
                    text: "MyPassword"
                }
            }

            Button {
                id: quitButton
                KeyNavigation.tab: image
                text: "Quit"
                // font.pixelSize: buttonFontPixelSize
                onClicked: quitAnim.start()
            }
        }
    }

    SequentialAnimation {
        id: quitAnim

        NumberAnimation {
            to: 0
            duration: 300
            target: windowContent
            property: "scale"
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: Qt.quit();
        }
    }
}
