/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"

Rectangle {
   id: sideMenuRectangle
   property alias exchangeBtn: btnExchange
   property alias liquidityBtn: btnLiquidity
   property alias quitBtn: btnQuit
   anchors.verticalCenter: parent.verticalCenter
   height: sideMenuColumn.height * 1.5
   width: parent.width * 0.1
   color: "#1C2029"

   Column {
      id: sideMenuColumn
      anchors.centerIn: parent
      spacing: 30
      AVMEButton {
         id: btnExchange
         text: "Exchange"
         width: parent.parent.width * 0.8
      }
      AVMEButton {
         id: btnLiquidity
         text: "Liquidity"
         width: parent.parent.width * 0.8
      }
      AVMEButton {
         id: btnQuit
         text: "Quit"
         width: parent.parent.width * 0.8
      }
   }
}