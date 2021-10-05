/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
   
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"
import "qrc:/qml/popups"
import "../components"


Item {
  id: liquidityScreenItem
  anchors.centerIn: parent
  anchors.fill: parent

  Row {
    anchors.centerIn: parent
    spacing: 50
    AddLiquidityPanel {
      id: addLiquidityPanel
      title: "Add Liquidity"
      height: liquidityScreenItem.height * 0.8
      width: liquidityScreenItem.width * 0.45
    }

    RemoveLiquidityPanel {
      id: removeLiquidityPanel
      title: "Remove Liquidity"
      height: liquidityScreenItem.height * 0.8
      width: liquidityScreenItem.width * 0.45
    }
  }
}