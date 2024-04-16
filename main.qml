import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.qt.dev

ApplicationWindow {
    id: window
    visible: true
    width: 1024
    height: 768
    title: qsTr("ArUco Marker Generator")

    property int currentMarkerId: markerSpinbox.value

    onClosing: function (close) {
    }

    Component.onCompleted: {
        image.source = Qt.binding(function() { return "image://aruco/" + currentMarkerId; })
    }

    Connections {
        target: Qt.application

        function onAboutToQuit() {
            image.sourceSize.width = 1;
            image.sourceSize.height = 1;
            markerSizeText.text = ""
            borderSizeText.text = ""
            onPipsText.text = ""
            offPipsText.text = ""
        }
    }

    MarkerInfo {
        id: markerInfo
        marker_id: window.currentMarkerId
    }

    header: ToolBar {
    }

    ColumnLayout {
        id: windowContent
        anchors.fill: parent
        anchors.margins: 20

        Image {
            id: image
            Layout.fillWidth: true
            Layout.fillHeight: true
            fillMode: Image.PreserveAspectFit
            smooth: false

            // property int smallest_dimension: Math.min(width, height)
            // property int bounded_smallest_dimension: smallest_dimension <= 1024 ? smallest_dimension : 1024
            // sourceSize.width: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
            // sourceSize.height: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                text: "Marker ID (0-49):"
            }
            SpinBox {
                id: markerSpinbox
                from: 0
                to: 49
                value: 10
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Label {
                text: "Marker Size"
            }
            TextField {
                id: markerSizeText
                readOnly: true
                text: markerInfo.marker_size
            }
            Label {
                text: "Border Size"
            }
            TextField {
                id: borderSizeText
                readOnly: true
                text: markerInfo.border_size
            }
            Label {
                text: "Black Pips"
            }
            TextField {
                id: onPipsText
                readOnly: true
                text: markerInfo.on_modules
            }
            Label {
                text: "White Pips"
            }
            TextField {
                id: offPipsText
                readOnly: true
                text: markerInfo.off_modules
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                id: quitButton
                KeyNavigation.tab: image
                text: "Quit"
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
