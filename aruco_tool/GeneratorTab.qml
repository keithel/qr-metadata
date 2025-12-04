import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.qt.dev

Item {
    id: generatorTab

    required property ArUcoHomography ht

    property int templateIdx: 0
    property int currentMarkerId: ht.templateMarkerIds[templateIdx]

    MarkerInfo {
        id: markerInfo
        marker_id: generatorTab.currentMarkerId
    }

    Component.onCompleted: {
        image.source = Qt.binding(function() { return "image://aruco/" + currentMarkerId; })
    }

    onTemplateIdxChanged: {
        if (ht.templateMarkerIds.length > 0)
            currentMarkerId = ht.templateMarkerIds[templateIdx]
    }

    Connections {
        target: ht
        function onTemplateMarkerIdsChanged() {
            console.log("Template marker IDs changed, resetting templateIdx to 0")
            generatorTab.templateIdx = 0
        }
    }

    ColumnLayout {
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

                property real rotationAngle: 0
                property real xScaleFactor: 1
                property real yScaleFactor: 1
                property bool randomizedTransform: randomizedTransformCheckbox.checked
                onRandomizedTransformChanged: {
                    if (randomizedTransform) {
                        randomizeTransform()
                    } else {
                        rotationAngle = 0
                        xScaleFactor = 1
                        yScaleFactor = 1
                    }
                }
                function randomizeTransform() {
                    rotationAngle = Math.random() * 360
                    xScaleFactor = Math.random() * 2
                    yScaleFactor = Math.random() * 2
                }
                transform: [
                    Rotation {
                        angle: image.rotationAngle
                        origin.x: image.width / 2
                        origin.y: image.height / 2
                    },
                    Scale {
                        xScale: image.xScaleFactor
                        yScale: image.yScaleFactor
                        origin.x: image.width / 2
                        origin.y: image.height / 2
                    }
                ]
                // property int smallest_dimension: Math.min(width, height)
                // property int bounded_smallest_dimension: smallest_dimension <= 1024 ? smallest_dimension : 1024
                // sourceSize.width: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
                // sourceSize.height: Math.floor(bounded_smallest_dimension / qrCodeInfo.size) * qrCodeInfo.size
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                property bool showOverlay: hideOverlayTimer.running
                property int opacityDuration: 400
                onPositionChanged: hideOverlayTimer.restart()
                onExited: hideOverlayTimer.stop()

                Timer {
                    id: hideOverlayTimer
                    interval: 2000
                    running: false
                }

                // Left arrow
                Rectangle {
                    width: 50
                    height: 100
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#80000000"
                    radius: 5

                    opacity: (hover.showOverlay && generatorTab.templateIdx > 0) ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: hover.opacityDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "<"
                        color: "white"
                        font.pixelSize: 40
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (generatorTab.templateIdx > 0) {
                                generatorTab.templateIdx--
                            }
                        }
                    }
                }

                // Right arrow
                Rectangle {
                    width: 50
                    height: 100
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#80000000"
                    radius: 5

                    opacity: (hover.showOverlay && ht.templateMarkerIds.length > 0 && generatorTab.templateIdx < ht.templateMarkerIds.length - 1) ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: hover.opacityDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        color: "white"
                        font.pixelSize: 40
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (generatorTab.templateIdx < ht.templateMarkerIds.length - 1) {
                                generatorTab.templateIdx++
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 80
                    height: 30
                    color: "#80000000"
                    radius: 15
                    opacity: hover.showOverlay ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: hover.opacityDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: "white"
                        text: (generatorTab.templateIdx + 1) + " / " + ht.templateMarkerIds.length
                    }
                }
            }
        }

        FlexboxLayout {
            id: metadataLayout
            Layout.maximumHeight: implicitHeight
            direction: FlexboxLayout.Row
            wrap: FlexboxLayout.Wrap
            property int textFieldPreferredWidth: 50

            RowLayout {
                Label {
                    id: templateLabel
                    text: "Template"
                }
                TextField {
                    id: templateText
                    Layout.preferredWidth: 70
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: templateComboBox.currentText
                }
                Label {
                    id: markerIdLabel
                    text: "ID"
                }
                TextField {
                    id: markerIdText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    horizontalAlignment: Qt.AlignHCenter
                    readOnly: true
                    text: markerInfo.marker_id
                }
                Label {
                    id: markerSizeLabel
                    text: "Marker Size"
                }
                TextField {
                    id: markerSizeText
                    Layout.preferredWidth: metadataLayout.textFieldPreferredWidth
                    width: metadataLayout.textFieldPreferredWidth
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
                    text: markerInfo.off_modules
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
                    text: markerInfo.on_modules
                }
            }
            Item {
                Layout.fillWidth: true
            }
            RowLayout {
                Label {
                    verticalAlignment: Qt.AlignVCenter
                    text: "Template:"
                }
                ComboBox {
                    id: templateComboBox
                    model: ht.availableTemplates
                    Layout.preferredWidth: 150
                    onCurrentIndexChanged: {
                        console.log("template changed: " + model[currentIndex])
                        ht.template = model[currentIndex]
                    }
                }
            }
            CheckBox {
                id: randomizedTransformCheckbox
                text: "Apply Random Transformation"
                checked: false
            }

            Button {
                id: generatePdfButton
                text: "Generate PDF"
                onClicked: {
                    ht.generate_template_pdf(templateComboBox.currentText, "template.pdf")
                    console.log("Generated PDF for template " + templateComboBox.currentText);
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
}
