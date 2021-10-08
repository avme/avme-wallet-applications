/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"

// Side menu with options.
Rectangle {
  id: menu
  property alias exchangeBtn: btnExchange
  property alias liquidityBtn: btnLiquidity
  property alias quitBtn: btnQuit
  anchors.verticalCenter: parent.verticalCenter
  width: (parent.width * 0.1)
  height: (menuCol.height * 1.25)
  color: "#1C2029"

  Column {
    id: menuCol
    anchors.centerIn: parent
    spacing: 20
    AVMEButton { id: btnExchange; text: "Exchange"; width: menu.width * 0.8 }
    AVMEButton { id: btnLiquidity; text: "Liquidity"; width: menu.width * 0.8 }
    AVMEButton { id: btnQuit; text: "Quit"; width: menu.width * 0.8 }
  }
}
