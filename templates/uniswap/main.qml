/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */

import QtQuick 2.9
import QtQuick.Controls 2.2

import "screen"
import "components"
import "qrc:/qml/components"
import "qrc:/qml/popups"

Item {
  id: uniswapTemplateMain
  property alias exchangeScreen: screenExchange
  property alias liquidityScreen: screenLiquidity

  anchors.fill: parent

  property string router: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106"
  property string factory: "0xefa94DE7a4656D787667C749f7E1223D71E9FD88"
  property string exchangeFee: "3" // 0.3% 
  property string screenName: "UniswapTemplate"

  Component.onCompleted: {
    exchangeScreen.visible = true
    liquidityScreen.visible = false
  }

  SideMenu {
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
  // due to centralization issues.
  AVMEPopupAssetSelect {
    id: exchangeLeftAssetPopup
    defaultToAVME: false
  }
  AVMEPopupAssetSelect {
    id: exchangeRightAssetPopup
    defaultToAVME: false
  }

  Item {
    id: uniswapTemplateContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: sideMenu.left
    anchors.bottom: parent.bottom
    ExchangeScreen {
      id: screenExchange
    }

    LiquidityScreen {
      id: screenLiquidity
    }
  }
}
