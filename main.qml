import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import io.qt.dev

ApplicationWindow {
    id: window
    visible: true
    width: 1024
    height: 768
    title: qsTr("ArUco Manager")

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
            detectionResultLabel.text = ""
            detectionRepeater.model = []
        }
    }

    MarkerInfo {
        id: markerInfo
        marker_id: window.currentMarkerId
    }

    HomographyTools {
        id: homgraphyTools
    }

    ArUcoDetector {
        id: detector
    }

    header: ToolBar {
    }

    ColumnLayout {
        id: windowContent
        anchors.fill: parent
        //anchors.margins: 10

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: "Generator" }
            TabButton { text: "Detector" }
        }

        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Item {
                id: generatorTab
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
                    }

                    FlexboxLayout {
                        id: metadataLayout
                        Layout.maximumHeight: implicitHeight
                        direction: FlexboxLayout.Row
                        wrap: FlexboxLayout.Wrap
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
                        CheckBox {
                            id: randomizedTransformCheckbox
                            text: "Apply Random Transformation"
                            checked: false
                        }

                        Button {
                            id: generatePdfButton
                            text: "Generate PDF"
                            onClicked: {
                                var markers = [
                                    markerSpinbox.value % 50,
                                    markerSpinbox.value % 50 + 1,
                                    markerSpinbox.value % 50 + 2,
                                    markerSpinbox.value % 50 + 3
                                ]
                                homgraphyTools.generate_pdf(markers, "template.pdf")
                                console.log("Generated PDF for marker ID " + markerSpinbox.value + " to " + (markerSpinbox.value + 3) );
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

            Item {
                id: detectorTab

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 50
                        color: "white"
                        border.color: "#84f"

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            autoTransform: true
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "No Image Loaded"
                            visible: previewImage.status !== Image.Ready
                            color: "gray"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Load Image"
                            onClicked: fileDialog.open()
                        }

                        Label {
                            id: detectionResultLabel
                            text: detector.detections.length + " markers detected."
                            visible: previewImage.status === Image.Ready
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        // Layout.fillHeight: true
                        contentWidth: availableWidth

                        ColumnLayout {
                            id: detectionResultsLayout
                            width: parent.width
                            spacing: 5

                            Repeater {
                                id: detectionRepeater
                                model: detector.detections
                                delegate: RowLayout {
                                    width: parent.width
                                    TextField {
                                        text: modelData.id
                                        readOnly: true
                                        Layout.preferredWidth: 50
                                        horizontalAlignment: Qt.AlignHCenter
                                    }
                                    TextField {
                                        text: modelData.position
                                        readOnly: true
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                FileDialog {
                    id: fileDialog
                    title: "Select an Image"
                    nameFilters: ["Image files (*.png *.jpg *.jpeg *.bmp)"]
                    onAccepted: {
                        previewImage.source = selectedFile
                        detector.detectFromFile(selectedFile)
                    }
                }
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
