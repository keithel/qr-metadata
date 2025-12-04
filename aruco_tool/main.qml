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

    ArUcoHomography {
        id: homographyTools
    }

    onClosing: function (close) {
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
            markerIdLabelsRepeater.model = []
        }
    }

    header: ToolBar {
    }

    ColumnLayout {
        id: windowContent
        anchors.fill: parent

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

                property int templateIdx: 0
                property int currentMarkerId: homographyTools.templateMarkerIds[templateIdx]

                MarkerInfo {
                    id: markerInfo
                    marker_id: generatorTab.currentMarkerId
                }

                Component.onCompleted: {
                    image.source = Qt.binding(function() { return "image://aruco/" + currentMarkerId; })
                }

                onTemplateIdxChanged: {
                    if (homographyTools.templateMarkerIds.length > 0)
                        currentMarkerId = homographyTools.templateMarkerIds[templateIdx]
                }

                Connections {
                    target: homographyTools
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

                                opacity: (hover.showOverlay && homographyTools.templateMarkerIds.length > 0 && generatorTab.templateIdx < homographyTools.templateMarkerIds.length - 1) ? 1.0 : 0.0
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
                                        if (generatorTab.templateIdx < homographyTools.templateMarkerIds.length - 1) {
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
                                    text: (generatorTab.templateIdx + 1) + " / " + homographyTools.templateMarkerIds.length
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
                                model: homographyTools.availableTemplates
                                Layout.preferredWidth: 150
                                onCurrentIndexChanged: {
                                    console.log("template changed: " + model[currentIndex])
                                    homographyTools.template = model[currentIndex]
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
                                homographyTools.generate_template_pdf(templateComboBox.currentText, "template.pdf")
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

                        Image {
                            id: previewImage
                            property bool showMarkerLabels: true
                            property real scaleFactor: {
                                previewImage.status === Image.Ready ?
                                    Math.min(previewImage.width / previewImage.sourceSize.width,
                                             previewImage.height / previewImage.sourceSize.height)
                                    : 0
                            }
                            property int xOffset: previewImage.x + (previewImage.width - previewImage.sourceSize.width * previewImage.scaleFactor) / 2
                            property int yOffset: previewImage.y + (previewImage.height - previewImage.sourceSize.height * previewImage.scaleFactor) / 2

                            source: ""
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            autoTransform: true

                            Repeater {
                                id: markerIdLabelsRepeater
                                model: homographyTools.detections
                                delegate: TextField {
                                    visible: previewImage.showMarkerLabels
                                    text: modelData.role == "N/A" ? modelData.id : modelData.role
                                    color: modelData.role == "N/A" ? "red" : "green"
                                    width: 30
                                    x: previewImage.xOffset + Math.min(modelData.tl[0], modelData.tr[0], modelData.br[0], modelData.bl[0]) * previewImage.scaleFactor + 4
                                    y: previewImage.yOffset + Math.min(modelData.tl[1], modelData.tr[1], modelData.br[1], modelData.bl[1]) * previewImage.scaleFactor - 20
                                    readOnly: true
                                    Layout.preferredWidth: 50
                                    horizontalAlignment: Qt.AlignHCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onPressed: parent.showMarkerLabels = false
                                onReleased: parent.showMarkerLabels = true
                            }
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
                            text: homographyTools.detections.length + " markers detected."
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
                                model: homographyTools.detections
                                delegate: RowLayout {
                                    width: parent.width
                                    TextField {
                                        text: modelData.id
                                        readOnly: true
                                        Layout.preferredWidth: 50
                                        horizontalAlignment: Qt.AlignHCenter
                                    }
                                    TextField {
                                        text: ("TL: " + modelData.tl +
                                              " BR: " + modelData.br)
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
                        homographyTools.detectFromFile(selectedFile)
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
