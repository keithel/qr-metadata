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

    header: TabBar {
        id: tabBar
        Layout.fillWidth: true
        TabButton { text: "Generator" }
        TabButton { text: "Detector" }
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
