/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php.
   Author: ProDesert22                             */

import QtQuick 2.9
import QtQuick.Controls 2.2

import "components" as Components
import "qrc:/qml/components"

Item {
  id: nftsUserTemplateMain

  function reloadTokens() {
    nftList.clear();
    qmlApi.doCustomHttpRequest(
      "",
      "teste-api-fractional.herokuapp.com",
      443,
      "/v1/43114/getNftsUser/"+accountHeader.currentAddress,
      "GET",
      "",
      "getnftsuser"
    )
  }

  Component.onCompleted: reloadTokens()

  Connections {
    target: qmlApi
    function onCustomApiRequestAnswered(answer, requestID) {
      if (requestID == "getnftsuser") {
        loadingNfts.visible = false
        textLoading.visible = false
        var response = JSON.parse(answer)
        var tokens = response["result"]["items"]
        if (tokens.length == 0){
          textNotFound.visible = true
          return
        }
        tokenGrid.currentIndex = -1
        for (var i = 0; i < tokens.length; i++) {
          nftList.append(tokens[i]);
        }
        nftList.sortBySymbol();
      }
    }
  }

  property var selectedItem: null

  AVMEPopup {
    id: popupNft
    widthPct: 0.5
    heightPct: 0.95
    anchors.centerIn: parent
    Column {
      width: parent.width
      height: parent.height
      anchors.fill: parent
      anchors.topMargin: 10
      spacing: 10
      AVMEAsyncImage {
        id: tokenImage
        width: 250
        height: 250
        anchors.horizontalCenter: parent.horizontalCenter
        imageSource: {
          imageSource: selectedItem != null && selectedItem.itemImage != "" ? selectedItem.itemImage : "qrc:/img/unknown_token.png"
        }
      }
      Text {
        id: textName
        color: "#FFF"
        font.pixelSize: 18.0
        anchors.horizontalCenter: parent.horizontalCenter
        text: selectedItem != null ? "<b>Name</b>: "+selectedItem.itemName : ""
      }
      Text {
        id: textSymbol
        color: "#FFF"
        font.pixelSize: 18.0
        anchors.horizontalCenter: parent.horizontalCenter
        text: selectedItem!= null ? "<b>Symbol</b>: "+selectedItem.itemSymbol : ""
      }
      Text {
        id: textAddress
        color: "#FFF"
        font.pixelSize: 18.0
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        text: selectedItem != null ? "<b>Address</b>: <br>"+selectedItem.itemAddress : ""
      }
      Text {
        id: textId
        color: "#FFF"
        font.pixelSize: 18.0
        anchors.horizontalCenter: parent.horizontalCenter
        text: selectedItem != null ? "<b>Token ID</b>: "+selectedItem.itemId : ""
      }
      AVMEButton {
        id: btnExplorer
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: Qt.openUrlExternally("https://cchain.explorer.avax.network/tokens/"+selectedItem.itemAddress+"/instance/"+selectedItem.itemId+"/token-transfers")
        text: "View in C-Chain Explorer"
        width: (parent.width * 0.4)
      }
    }
    AVMEButton {
      id: btnClose
      width: (parent.width * 0.9)
      text: "Close"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 20
      onClicked: popupNft.close()
    }
  }

  AVMEPanel {
    id: nftsUserPanel
    height: parent.height * 0.95
    width: parent.width * 0.95
    anchors.centerIn: parent
    title: "Your NFTs"

    Text {
      id: textNotFound
      color: "#FFF"
      font.pixelSize: 20.0
      anchors.centerIn: parent
      horizontalAlignment: Text.AlignHCenter
      text: "<b>No NFTs Found<b/>"
      visible: false
    }

    Text {
      id: textLoading
      color: "#FFF"
      font.pixelSize: 20.0
      anchors.centerIn: parent
      horizontalAlignment: Text.AlignHCenter
      text: "<b>Loading...<b/>"
    }

    Image {
      id: loadingNfts
      height: parent.height * 0.50
      width: parent.width * 0.50
      anchors.centerIn: parent
      fillMode: Image.PreserveAspectFit
      source: "qrc:/img/icons/loading.png"
      RotationAnimator {
        target: loadingNfts
        from: 0
        to: 360
        duration: 1000
        loops: Animation.Infinite
        easing.type: Easing.InOutQuad
        running: true
      }
    }

    Components.NFTGrid {
      id: tokenGrid
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        bottom: parent.bottom
        topMargin: 80
        bottomMargin: 20
        leftMargin: 20
        rightMargin: 20
      }
      model: ListModel {
        id: nftList
        function sortBySymbol() {
          for (var i = 0; i < count; i++) {
            for (var j = 0; j < i; j++) {
              if (get(i).symbol < get(j).symbol) { move(i, j, 1) }
            }
          }
        }
      }
    }
  }
}
