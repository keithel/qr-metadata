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
        anchors.margins: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: image.sourceSize.height
            Layout.minimumWidth: image.sourceSize.width
            onWidthChanged: console.log("imagerect WxH: " + width + "x" + height)
            onHeightChanged: console.log("imagerect WxH: " + width + "x" + height)
            color: "white"
            Image {
                id: image
                anchors.fill: parent
                anchors.margins: 10
                fillMode: Image.PreserveAspectFit
                smooth: false

                // property int smallest_dimension: Math.min(width, height)
                // property int bounded_smallest_dimension: smallest_dimension <= 1024 ? smallest_dimension : 1024
                // sourceSize.width: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
                // sourceSize.height: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
            }
        }

        FlexboxLayout {
            id: metadataLayout
            Layout.maximumHeight: implicitHeight
            direction: FlexboxLayout.Row
            wrap: FlexboxLayout.Wrap
            justifyContent: FlexboxLayout.JustifyStart
            property int textFieldPreferredWidth: 50

            RowLayout {
                Label {
                    id: markerSizeLabel
                    text: "Marker Size"
                }
                TextField {
                    id: markerSizeText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    width: parent.textFieldPreferredWidth
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: markerInfo.marker_size
                }
            }
            RowLayout {
                Label {
                    verticalAlignment: Qt.AlignVCenter
                    text: "Border Size"
                }
                TextField {
                    id: borderSizeText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: markerInfo.border_size
                }
            }
            RowLayout {
                Label {
                    verticalAlignment: Qt.AlignVCenter
                    text: "Black Pips"
                }
                TextField {
                    id: onPipsText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: markerInfo.on_modules
                }
            }
            RowLayout {
                Label {
                    verticalAlignment: Qt.AlignVCenter
                    text: "White Pips"
                }
                TextField {
                    id: offPipsText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: markerInfo.off_modules
                }
            }
            Item {
                Layout.fillWidth: true
            }
            RowLayout {
                Label {
                    verticalAlignment: Qt.AlignVCenter
                    text: "Marker ID (0-49):"
                }
                SpinBox {
                    id: markerSpinbox
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    from: 0
                    to: 49
                    value: 10
                }
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
