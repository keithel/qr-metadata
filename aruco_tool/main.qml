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

    readonly property var args: Qt.application.arguments
    property var currentArgs: args.slice(1)

    Component.onCompleted: {
        print("currentArgs:", currentArgs)
        if (currentArgs.length > 0) {
            if (currentArgs[0] == "-g") {
                generatorButton.click()
                currentArgs.shift()
            }
            else if (currentArgs[0] == "-d") {
                detectorButton.click()
                currentArgs.shift()
            }
        }
        print("currentArgs:", currentArgs)
    }

    ArUcoHomography {
        id: homographyTools
    }

    onClosing: function (close) {
    }

    header: TabBar {
        id: tabBar
        Layout.fillWidth: true
        TabButton { id: generatorButton; text: "Generator" }
        TabButton { id: detectorButton; text: "Detector" }
    }

    StackLayout {
        id: windowContent
        anchors.fill: parent
        currentIndex: tabBar.currentIndex

        GeneratorTab {
            ht: homographyTools
        }

        DetectorTab {
            ht: homographyTools
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
