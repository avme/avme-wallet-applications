import QtQuick 2.9
import QtQuick.Controls 2.2

import "../comps"

Item {
  id: test2Screen
  Rectangle {
    anchors.fill: parent
    anchors.margins: 10
    radius: 10
    color: "#004400"
    Rectangle {
      anchors.centerIn: parent
      radius: 5
      width: parent.width * 0.5
      height: parent.height * 0.2
      color: "#008800"
      Image {
        anchors {
          verticalCenter: parent.verticalCenter
          right: parent.right
          rightMargin: 30
        }
        antialiasing: true
        smooth: true
        height: 64
        fillMode: Image.PreserveAspectFit
        source: "../images/no.png"
      }
      Text {
        anchors.centerIn: parent
        color: "black"
        font.pixelSize: 14.0
        font.bold: true
        text: "This is another test screen!"
      }
    }
    CustomButton {
      text: "Go to the first screen"
      onClicked: changeScreen("main.qml")
    }
  }
}
