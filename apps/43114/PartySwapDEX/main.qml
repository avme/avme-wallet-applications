/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
import QtQuick 2.9
import QtQuick.Controls 2.2

import "screen" as Screen
import "components" as Components
import "qrc:/qml/components"
import "qrc:/qml/popups"

Item {
  id: uniswapTemplateMain
  property alias exchangeScreen: screenExchange
  property alias liquidityScreen: screenLiquidity
  property string router: "0xff164Ede3E7C375E8764E9e3a22D3E35F780EEBC"
  property string factory: "0x58A08bc28f3E8dab8Fb2773D8f243bC740398b09"
  property string exchangeFee: "3" // 0.3%
  property string screenName: "PartySwapDEX"
  property string exchangeName: "Party Swap"
  property string exchangeLogo: "../images/exchangeLogo.png"
  anchors.fill: parent

  Component.onCompleted: {
    exchangeScreen.visible = true
    liquidityScreen.visible = false
  }

  AVMEAsyncImage {
    id: logoBg
    width: 256
    height: 256
    z: 0
    anchors { left: parent.left; bottom: parent.bottom; margins: 50 }
    imageOpacity: 0.15
    imageSource: "images/exchangeLogo.png"
  }

  Components.SideMenu {
    id: sideMenu
    anchors.right: parent.right
    exchangeBtn.onClicked: {
      exchangeScreen.visible = true
      liquidityScreen.visible = false
    }
    liquidityBtn.onClicked: {
      exchangeScreen.visible = false
      liquidityScreen.visible = true
    }
    quitBtn.onClicked: closeScreen()
  }

  // Popups are *required* to be declared on the root window
  // due to how QML is OOP-centered regarding positioning, sizing,
  // centralization, etc. (it's always based on the *parent*).
  AVMEPopupInfo {
    id: fundsPopup; icon: "qrc:/img/warn.png"
    info: "Insufficient funds. Please check your inputs."
  }
  AVMEPopupExchangeSettings { id: slippageSettings }
  AVMEPopupConfirmTx { id: confirmTransactionPopup }
  AVMEPopupTxProgress { id: txProgressPopup }

  Item {
    id: uniswapTemplateContent
    anchors {
      top: parent.top
      left: parent.left
      right: sideMenu.left
      bottom: parent.bottom
    }
    Screen.ExchangeScreen { id: screenExchange }
    Screen.LiquidityScreen { id: screenLiquidity }
  }
}
