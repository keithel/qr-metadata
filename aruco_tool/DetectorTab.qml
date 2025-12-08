import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import io.qt.dev

Item {
    required property ArUcoHomography ht
    property string autoLoadFile: ""

    Component.onCompleted: {
        if (Window.window.currentArgs.length > 0)
            autoLoadFile = Window.window.currentArgs[0]

        if (autoLoadFile.length > 0) {
            console.log("Autoloading:", autoLoadFile)
            fileDialog.detectFromFile(Qt.resolvedUrl(autoLoadFile))
        }
    }

    Keys.onPressed: (event) => { if (event.key == Qt.Key_M) previewImage.showMarkerLabels = false }
    Keys.onReleased: (event) => { if (event.key == Qt.Key_M) previewImage.showMarkerLabels = true }

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
                property bool showSketch: false
                property url inputImgSource: ""
                property url sketchSource: ""
                property real scaleFactor: {
                    previewImage.status === Image.Ready ?
                        Math.min(previewImage.width / previewImage.sourceSize.width,
                                    previewImage.height / previewImage.sourceSize.height)
                        : 0
                }
                property int xOffset: previewImage.x + (previewImage.width - previewImage.sourceSize.width * previewImage.scaleFactor) / 2
                property int yOffset: previewImage.y + (previewImage.height - previewImage.sourceSize.height * previewImage.scaleFactor) / 2

                source: showSketch ? sketchSource : inputImgSource
                anchors.fill: parent
                anchors.margins: 2
                fillMode: Image.PreserveAspectFit
                smooth: false
                autoTransform: true

                Component.onCompleted: console.log("previewImage source:", previewImage.source)
                onSourceChanged: console.log("previewImage source changed:", previewImage.source)

                Repeater {
                    id: markerIdLabelsRepeater
                    model: ht.detections
                    delegate: TextField {
                        visible: !previewImage.showSketch && previewImage.showMarkerLabels
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
                TextField {
                    property real mouseX: (imgMouseArea.mouseX - previewImage.xOffset) / previewImage.scaleFactor
                    property real mouseY: (imgMouseArea.mouseY - previewImage.yOffset) / previewImage.scaleFactor
                    property bool mouseWithinMarker: withinMarker(mouseX, mouseY, ht.detections)
                    color: mouseWithinMarker ? "green" : "red"
                    anchors.left: parent.left
                    anchors.top: parent.top
                    visible: imgMouseArea.containsMouse
                    text: "(" + mouseX.toFixed(1) + ", " + mouseY.toFixed(1) + ")"

                    function crossProduct(x1, y1, x2, y2) {
                        return x1 * y2 - x2 * y1
                    }
                    function insideMarker(x, y, marker) {
                        const corners = [
                            marker.tl, marker.tr,
                            marker.br, marker.bl
                        ]

                        let sign = 0
                        for (let i = 0; i < corners.length; i++) {
                            const pA = corners[i]
                            const pB = corners[(i+1) % corners.length]
                            const edge_vx = pB[0] - pA[0]
                            const edge_vy = pB[1] - pA[1]

                            // test vector from pA to the test point (x,y)
                            const test_vx = x - pA[0]
                            const test_vy = y - pA[1]

                            const cross = crossProduct(edge_vx, edge_vy, test_vx, test_vy)
                            if (cross !== 0) {
                                if (sign === 0) {
                                    sign = cross > 0 ? 1 : -1
                                }
                                else if ((cross > 0 ? 1 : -1) !== sign) {
                                    // If the sign changes, the point is outside the rectangle
                                    return false
                                }
                            }
                        }
                        // Point is inside or on boundary
                        return true
                    }

                    function withinMarker(x, y, detections) {
                        if (!detections)
                            return false

                        for (const marker of detections) {
                            if (insideMarker(x, y, marker)) {
                                return true
                            }
                        }
                        return false
                    }
                }

                MouseArea {
                    id: imgMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onReleased: {
                        if (parent.sketchSource != "")
                            parent.showSketch = !parent.showSketch
                    }
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
                text: ht.detections.length + " markers detected."
                visible: previewImage.status === Image.Ready
            }

            Button {
                enabled: previewImage.inputImgSource != ""
                text: "Extract + Save Sketch"

                onClicked: {
                    var sourceUrl = previewImage.source
                    var destUrl = "./sketch_output.png"
                    var success = ht.save_sketch(sourceUrl, destUrl)
                    if (success) {
                        console.log("Saved to:", destUrl)
                        // Hack to force reload if we overwrite the same file.
                        previewImage.sketchSource = ""
                        previewImage.sketchSource = "file:" + destUrl
                        previewImage.showSketch = true
                    }
                    else {
                        console.log("Failed to save sketch")
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            visible: !previewImage.showSketch
            contentWidth: availableWidth

            ColumnLayout {
                id: detectionResultsLayout
                width: parent.width
                spacing: 5

                Repeater {
                    id: detectionRepeater
                    model: ht.detections
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

        function detectFromFile(fpath) {
            previewImage.inputImgSource = fpath
            console.log("calling ht.detectFromFile(" + fpath + ")")
            ht.detectFromFile(fpath)
        }

        onAccepted: {
            detectFromFile(selectedFile)
        }
    }
}
