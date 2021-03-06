/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"
import "qrc:/qml/popups"
import "../components" as Components

Item {
  id: liquidityScreenItem
  anchors.centerIn: parent
  anchors.fill: parent

  Row {
    anchors.centerIn: parent
    spacing: 25
    Components.AddLiquidityPanel {
      id: addLiquidityPanel
      title: "Add Liquidity"
      width: (liquidityScreenItem.width * 0.475)
      height: (liquidityScreenItem.height * 0.8)
    }

    Components.RemoveLiquidityPanel {
      id: removeLiquidityPanel
      title: "Remove Liquidity"
      width: (liquidityScreenItem.width * 0.475)
      height: (liquidityScreenItem.height * 0.8)
    }
  }
}
