import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"
/**
 * Custom grid view for managing nfts.
 */
GridView {
  id: nftGrid
  property color listHighlightColor: "#887AC1EB"
  property color listHoveredColor: "#447AC1EB"

  highlight: Rectangle { color: listHighlightColor; radius: 5 }
  highlightMoveDuration: 0
  focus: true
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  cellWidth: 300
  cellHeight: 300
  height: 300
  width: 300
  Component.onCompleted: forceActiveFocus()

  function selectNft(index){
    nftGrid.currentIndex = index
    popupNft.open()
    nftsUserTemplateMain.selectedItem = nftGrid.itemAtIndex(index)
  }

  delegate: Component {
    id: gridDelegate
    Item {
      id: gridItem
      readonly property string itemAddress: address
      readonly property string itemSymbol: symbol
      readonly property string itemName: name
      readonly property string itemImage: ImageURL
      readonly property string itemUri: URI
      readonly property int itemId: tokenId

      width: nftGrid.cellWidth - 10
      height: nftGrid.cellHeight - 10

      Rectangle { id: gridItemBg; anchors.fill: parent; radius: 5; color: "transparent" }
      Column {
        anchors.centerIn: parent
        spacing: 10
        AVMEAsyncImage {
          id: tokenImage
          width: 250
          height: 250
          anchors.horizontalCenter: parent.horizontalCenter
          imageSource: {
            imageSource: (itemImage != "") ? itemImage : "qrc:/img/unknown_token.png"
          }
        }
        Text {
          id: tokenName
          anchors {
            horizontalCenter: parent.horizontalCenter
          }
          color: "#FFFFFF"
          font.pixelSize: 18.0
          text: "<b>"+itemName+"#"+itemId+"</b>"
        }
      }

      MouseArea {
        id: delegateMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: gridItemBg.color = listHoveredColor
        onExited: gridItemBg.color = "transparent"
        onClicked: selectNft(index)
      }
    }
  }
}
