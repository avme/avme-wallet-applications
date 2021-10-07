/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
   
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"
import "qrc:/qml/popups"


AVMEPanel {
  id: addLiquidityPanel
  title: "Remove Liquidity"
 /**
   *  Holds information about the assets, as follows:
   *  {
   *    "left" : {
   *      "allowance"  : "...",
   *      "decimals"   : "...",
   *      "contract"   : "...",
   *      "symbol"     : "...",
   *      "imageSource": "...",
   *      "approved"   : "..."
   *    },
   *    "right" : {
   *      "allowance"  : "...",
   *      "decimals"   : "...",
   *      "contract"   : "...",
   *      "symbol"     : "...",
   *      "imageSource": "...",
   *      "approved"   : "..."
   *    },
   *    
   *    "pair" : "0x...",
   *    "pairBalance" : "...",
   *    "pairAllowance": "..."
   *    "pairSupply" : "..."
   *    "userLeftReserves" : "..."
   *    "userRightReserves"  : "..."
   *    "userLPSharePercentage" : "..."
   *
   *    "reserves":
   *      {
   *        "reservesIn" : "...",
   *        "reservesOut": "...",
   *        "decimalsIn" : xx,
   *        "decimalsOut": yy
   *      }
   *  }
   */
  
  // We need properties for information
  // used inside objects, as when you open a new screen
  // It cannot load objects inside the "removeLiquidityInfo" property

  property var removeLiquidityInfo: ({})
  property string leftSymbol: ""
  property string leftImageSource: ""
  property string leftDecimals: ""
  property string leftAllowance: ""
  property string leftContract: ""
  property bool leftAllowed: false
  property string removeAssetLeftEstimate: "0"
  property string rightSymbol: ""
  property string rightImageSource: ""
  property string rightDecimals: ""
  property string rightAllowance: ""
  property string rightContract: ""
  property bool rightAllowed: false
  property string removeAssetRightEstimate: "0"
  property string pairBalance: "Loading balance..."
  property string removeLPEstimate: ""

  // Transaction information
  property string desiredSlippage: slippageSettings.slippage
  property string to
  property string coinValue
  property string txData
  property string gas
  property string gasPrice: qmlApi.sum(accountHeader.gasPrice, 15)
  property bool automaticGas: true
  property string info
  property string historyInfo

  // Helper properties

  property string randomID
  property bool loading: true
  
  Timer { id: requestsTimer; interval: 5000; repeat: true; onTriggered: (fetchAllowanceBalanceReservesAndSupply()) }

  Connections {
    target: qmlApi
    function onApiRequestAnswered(answer, requestID) {
      var resp = JSON.parse(answer)
      if (requestID == screenName + "_" + title + "_" +  "_fetchPair_" + randomID) {
        removeLiquidityInfo["pair"] = qmlApi.parseHex(resp[0].result, ["address"])
        if (removeLiquidityInfo["pair"] != "0x0000000000000000000000000000000000000000") {
          fetchAllowanceBalanceReservesAndSupply()
          requestsTimer.start()
        } else {
          removeLiquidityPanelApprovalColumn.visible = false
          removeLiquidityPanelDetailsColumn.visible = false
          removeLiquidityPanelPairUnavailable.visible = true
          removeLiquidityLoadingPng.visible = false
          loading = false
          return;
        }
      }
      if (requestID == screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID) {
        var reserves
        for (var item in resp) {
          if (resp[item]["id"] == 1) {
            removeLiquidityInfo["pairBalance"] = qmlApi.weiToFixedPoint(qmlApi.parseHex(resp[item].result, ["uint"]), 18)
          }
          if (resp[item]["id"] == 2) {
            removeLiquidityInfo["pairAllowance"] = qmlApi.parseHex(resp[item].result, ["uint"])
          }
          if (resp[item]["id"] == 3) {
            reserves = qmlApi.parseHex(resp[item].result, ["uint", "uint", "uint"])
          }
          if (resp[item]["id"] == 4) {
            removeLiquidityInfo["pairSupply"] = qmlApi.parseHex(resp[item].result, ["uint"])
          }
        }
        pairBalance = "<b>" + removeLiquidityInfo["pairBalance"] + " " + removeLiquidityInfo["left"]["symbol"] + "/" + removeLiquidityInfo["right"]["symbol"] + "</b>"
        if (+removeLiquidityInfo["pairAllowance"] < +removeLiquidityInfo["pairBalance"]) { // TODO: block if balance is zero, check with >=
          removeLiquidityPanelApprovalColumn.visible = true
          removeLiquidityPanelDetailsColumn.visible = false
          removeLiquidityPanelPairUnavailable.visible = false
          removeLiquidityLoadingPng.visible = false
        } else {
          removeLiquidityPanelApprovalColumn.visible = false
          removeLiquidityPanelDetailsColumn.visible = true
          removeLiquidityPanelPairUnavailable.visible = false
          removeLiquidityLoadingPng.visible = false
        }
        var lowerAddress = qmlApi.getFirstFromPair(
          removeLiquidityInfo["left"]["contract"], removeLiquidityInfo["right"]["contract"]
        )
        if (lowerAddress == removeLiquidityInfo["left"]["contract"]) {
          reserves["reservesIn"] = reserves[0]
          reserves["reservesOut"] = reserves[1]
        } else if (lowerAddress == removeLiquidityInfo["right"]["contract"]) {
          reserves["reservesIn"] = reserves[1]
          reserves["reservesOut"] = reserves[0]
        }
        reserves["decimalsIn"] = removeLiquidityInfo["left"]["decimals"]
        reserves["decimalsOut"] = removeLiquidityInfo["right"]["decimals"]
        removeLiquidityInfo["reserves"] = reserves

        var userShares = calculatePoolShares(
          reserves["reservesIn"], reserves["reservesOut"], removeLiquidityInfo["pairBalance"], removeLiquidityInfo["pairSupply"] 
        )
        removeLiquidityInfo["userLeftReserves"] = userShares.left
        removeLiquidityInfo["userRightReserves"] = userShares.right
        removeLiquidityInfo["userLPSharePercentage"] = userShares.liquidity
        loading = false
      } 
    }
  }

  Connections {
    target: removeLiquidityLeftAssetPopup 
    function onAboutToHide() {
      // No need to reload in case of the same asset is selected
      if (removeLiquidityInfo["left"]["contract"] == removeLiquidityLeftAssetPopup.chosenAssetAddress) {
        return
      }

      // Do not allow to set a swap between the same assets
      if (removeLiquidityInfo["right"]["contract"] == removeLiquidityLeftAssetPopup.chosenAssetAddress) {
        return
      }
      
      // Edge case for WAVAX
      if (removeLiquidityLeftAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        removeLiquidityInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        removeLiquidityInfo["left"]["allowance"] = "0";
      }
      removeLiquidityInfo["left"]["decimals"] = removeLiquidityLeftAssetPopup.chosenAssetDecimals
      removeLiquidityInfo["left"]["contract"] = removeLiquidityLeftAssetPopup.chosenAssetAddress
      removeLiquidityInfo["left"]["symbol"] = removeLiquidityLeftAssetPopup.chosenAssetSymbol

      var img = ""
      if (removeLiquidityLeftAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (removeLiquidityLeftAssetPopup.chosenAssetAddress == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(removeLiquidityLeftAssetPopup.chosenAssetAddress)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      removeLiquidityInfo["left"]["imageSource"] = img
      removeLiquidityInfo["pair"] = ""
      removeLiquidityInfo["reserves"] = ({});
      updateDisplay()
    }
  }

  Connections {
    target: removeLiquidityRightAssetPopup 
    function onAboutToHide() {
      // No need to reload in case of the same asset is selected
      if (removeLiquidityInfo["right"]["contract"] == removeLiquidityRightAssetPopup.chosenAssetAddress) {
        return
      }

      // Do not allow to set a swap between the same assets
      if (removeLiquidityInfo["left"]["contract"] == removeLiquidityRightAssetPopup.chosenAssetAddress) {
        return
      }
      
      // Edge case for WAVAX
      if (removeLiquidityRightAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        removeLiquidityInfo["right"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        removeLiquidityInfo["right"]["allowance"] = "0";
      }
      removeLiquidityInfo["right"]["decimals"] = removeLiquidityRightAssetPopup.chosenAssetDecimals
      removeLiquidityInfo["right"]["contract"] = removeLiquidityRightAssetPopup.chosenAssetAddress
      removeLiquidityInfo["right"]["symbol"] = removeLiquidityRightAssetPopup.chosenAssetSymbol

      var img = ""
      if (removeLiquidityRightAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (removeLiquidityRightAssetPopup.chosenAssetAddress == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(removeLiquidityRightAssetPopup.chosenAssetAddress)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      removeLiquidityInfo["right"]["imageSource"] = img
      removeLiquidityInfo["pair"] = "";
      removeLiquidityInfo["reserves"] = ({});
      updateDisplay()
    }
  }

  Component.onCompleted: {
    removeLiquidityInfo["left"] = ({});
    removeLiquidityInfo["right"] = ({});
    removeLiquidityInfo["pair"] = "";
    removeLiquidityInfo["reserves"] = ({});
    removeLiquidityInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
    removeLiquidityInfo["left"]["decimals"] = "18";
    removeLiquidityInfo["left"]["contract"] = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    removeLiquidityInfo["left"]["symbol"] = "AVAX";
    removeLiquidityInfo["left"]["imageSource"] = "qrc:/img/avax_logo.png";
    removeLiquidityInfo["left"]["allowed"] = true
    removeLiquidityInfo["right"]["allowance"] = "0";
    removeLiquidityInfo["right"]["decimals"] = "18";
    removeLiquidityInfo["right"]["contract"] = "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed";
    removeLiquidityInfo["right"]["symbol"] = "AVME";
    removeLiquidityInfo["right"]["imageSource"] = "qrc:/img/avme_logo.png";
    removeLiquidityInfo["right"]["allowed"] = false
    // Information displayed to the user needs to be kept on their own variable
    // As a string. For that reason we have created a updateDisplay() function
    // Which will provide these variables with the new information from
    // the removeLiquidityInfo var
    updateDisplay()
  }

  function updateDisplay() {
    randomID = qmlApi.getRandomID()
    //addRightAssetInput.text   = ""
    //addLeftAssetInput.text    = ""
    leftSymbol        = removeLiquidityInfo["left"]["symbol"]
    leftImageSource   = removeLiquidityInfo["left"]["imageSource"]
    leftDecimals      = removeLiquidityInfo["left"]["decimals"]
    leftAllowance     = removeLiquidityInfo["left"]["allowance"]
    leftContract      = removeLiquidityInfo["left"]["contract"]
    leftAllowed       = removeLiquidityInfo["left"]["allowed"]
    rightSymbol       = removeLiquidityInfo["right"]["symbol"]
    rightImageSource  = removeLiquidityInfo["right"]["imageSource"]
    rightDecimals     = removeLiquidityInfo["right"]["decimals"]
    rightAllowance    = removeLiquidityInfo["right"]["allowance"]
    rightContract     = removeLiquidityInfo["right"]["contract"]
    rightAllowed      = removeLiquidityInfo["right"]["allowed"]
    //updateBalances()
    fetchPair()
  }

  function fetchPair() {
    removeLiquidityPanelApprovalColumn.visible = false
    removeLiquidityPanelDetailsColumn.visible = false
    removeLiquidityPanelPairUnavailable.visible = false
    removeLiquidityLoadingPng.visible = true
    loading = true
    randomID = qmlApi.getRandomID()
    requestsTimer.stop()

    removeLiquidityInfo["pair"] = ""
    removeLiquidityInfo["reserves"] = ({});
    removeLiquidityInfo["pairBalance"] = ""
    removeLiquidityInfo["pairAllowance"] = ""
    removeLiquidityInfo["pairSupply"] = ""
    removeLiquidityInfo["userLeftReserves"] = ""
    removeLiquidityInfo["userRightReserves"] = ""
    removeLiquidityInfo["userLPSharePercentage"] = ""

    removeAssetLeftEstimate = "0"
    removeAssetRightEstimate = "0"
    pairBalance = "Loading balance..."
    removeLPEstimate = ""

    qmlApi.clearAPIRequests(screenName + "_" + title + "_" +  "_fetchPair_" + randomID)

    qmlApi.buildGetPairReq(
      removeLiquidityInfo["left"]["contract"],
      removeLiquidityInfo["right"]["contract"],
      factory,
      screenName + "_" + title + "_" +  "_fetchPair_" + randomID
    )

    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchPair_" + randomID)
  }

  function fetchAllowanceBalanceReservesAndSupply() {
    qmlApi.clearAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID)
    qmlApi.buildGetTokenBalanceReq(
      removeLiquidityInfo["pair"],
      accountHeader.currentAddress,
      screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID
    )
    qmlApi.buildGetAllowanceReq(
      removeLiquidityInfo["pair"],
      accountHeader.currentAddress,
      router,
      screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID
    )
    qmlApi.buildGetReservesReq(removeLiquidityInfo["pair"], screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID)
    qmlApi.buildGetTotalSupplyReq(removeLiquidityInfo["pair"], screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID)
    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowanceBalanceReservesAndSupply_" + randomID)
  }

  function calculatePoolShares(reservesIn, reservesOut, _pairBalance, _pairSupply) {
    var ret = ({})
    _pairBalance = qmlApi.fixedPointToWei(_pairBalance, 18)

    var userLPPercentage = qmlApi.div(_pairBalance, _pairSupply)
    var userLeftReserves = qmlApi.floor(qmlApi.mul(reservesIn, userLPPercentage))
    var userRightReserves = qmlApi.floor(qmlApi.mul(reservesOut, userLPPercentage))

    ret["left"] = userLeftReserves
    ret["right"] = userRightReserves
    ret["liquidity"] = qmlApi.mul(userLPPercentage, 100)
    return ret
  }

  function calculateRemoveLiquidityAmount(reservesIn, reservesOut, percentage, _pairBalance) {
    var ret = ({})
    _pairBalance = qmlApi.fixedPointToWei(_pairBalance, 18)
    
    var pc = qmlApi.div(percentage,100)

    var left = qmlApi.floor(qmlApi.mul(reservesIn, pc))
    var right = qmlApi.floor(qmlApi.mul(reservesOut, pc))
    var lp = qmlApi.floor(qmlApi.mul(_pairBalance, pc))

    ret["left"] = left
    ret["right"] = right
    ret["lp"] = lp
    return ret
  }


  function approveTx() {
    to = removeLiquidityInfo["pair"]
    coinValue = 0
    gas = 70000
    var ethCallJson = ({})
    info = "You will approve <b>"
    + removeLiquidityInfo["left"]["symbol"] + "/" + removeLiquidityInfo["right"]["symbol"] 
    + "</b> LP in + " + exchangeName + " router contract"
    historyInfo = "Approve <\b>" + removeLiquidityInfo["left"]["symbol"]  + "/" + removeLiquidityInfo["right"]["symbol"]  + " LP <\b>in " + exchangeName
    ethCallJson["function"] = "approve(address,uint256)"
    ethCallJson["args"] = []
    ethCallJson["args"].push(router)
    ethCallJson["args"].push(qmlApi.MAX_U256_VALUE())
    ethCallJson["types"] = []
    ethCallJson["types"].push("address")
    ethCallJson["types"].push("uint*")
    var ethCallString = JSON.stringify(ethCallJson)
    var ABI = qmlApi.buildCustomABI(ethCallString)
    txData = ABI
  }
  
  function removeLiquidityTx() {
    to = router
    coinValue = 0
    gas = 600000
    var ethCallJson = ({})
    info = "You will remove <b><br>"
    + qmlApi.weiToFixedPoint(removeAssetLeftEstimate, removeLiquidityInfo["left"]["decimals"]) + " " + removeLiquidityInfo["left"]["symbol"]
    + " and "
    + qmlApi.weiToFixedPoint(removeAssetRightEstimate, removeLiquidityInfo["right"]["decimals"]) + " " + removeLiquidityInfo["right"]["symbol"]
    + "<br></b> LP in + " + exchangeName + " router contract (estimated)"
    historyInfo = "Remove <b>" + removeLiquidityInfo["left"]["symbol"]  + "<\b> and <b> " + removeLiquidityInfo["right"]["symbol"] + "<\b> from " + exchangeName  + " Liquidity"
    if (removeLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7" ||
        removeLiquidityInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      ethCallJson["function"] = "removeLiquidityAVAX(address,uint256,uint256,uint256,address,uint256)"
      ethCallJson["args"] = []
      // token
      ethCallJson["args"].push(
        (removeLiquidityInfo["left"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") ?
        removeLiquidityInfo["left"]["contract"]
        :
        removeLiquidityInfo["right"]["contract"]
      )
      // Liquidity
      ethCallJson["args"].push(qmlApi.fixedPointToWei(removeLPEstimate, 18))
      // amountTokenMin
      var amountTokenMin
      if (removeLiquidityInfo["left"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        amountTokenMin = qmlApi.floor(qmlApi.mul(removeAssetLeftEstimate, desiredSlippage))
      } else {
        amountTokenMin = qmlApi.floor(qmlApi.mul(removeAssetRightEstimate, desiredSlippage))
      }
      ethCallJson["args"].push(amountTokenMin)
      // amountETHMin
      var amountAVAXMin
      if (removeLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        amountAVAXMin = qmlApi.floor(qmlApi.mul(removeAssetLeftEstimate, desiredSlippage))
      } else {
        amountAVAXMin = qmlApi.floor(qmlApi.mul(removeAssetRightEstimate, desiredSlippage))
      }
      ethCallJson["args"].push(amountAVAXMin)
      // to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // deadline
      ethCallJson["args"].push(String((+qmlApi.getCurrentUnixTime() + 3600) * 1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      txData = ABI
    } else {
      ethCallJson["function"] = "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)"
      ethCallJson["args"] = []
      // tokenA
      ethCallJson["args"].push(removeLiquidityInfo["left"]["contract"])
      // tokenB
      ethCallJson["args"].push(removeLiquidityInfo["right"]["contract"])
      // liquidity
      ethCallJson["args"].push(qmlApi.fixedPointToWei(removeLPEstimate, 18))
      // amountAMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(removeAssetLeftEstimate, desiredSlippage)))
      // amountBMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(removeAssetRightEstimate, desiredSlippage)))
      // to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // deadline
      ethCallJson["args"].push(String((+qmlApi.getCurrentUnixTime() + 3600) * 1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      txData = ABI
    }
  }

  function checkTransactionFunds() {
    var Fees = +qmlApi.mul(qmlApi.fixedPointToWei(gasPrice, 9), gas)
    if (+Fees > +qmlApi.fixedPointToWei(accountHeader.coinRawBalance, 18)) {
      return false
    }
    if (pairBalance) {
      if (+pairBalance < +removeLPEstimate) {
        return false;
      }
    }
    return true;
  }
  
  // ======================================================================
  // HEADER
  // ======================================================================

  Column {
    id: removeLiquidityPanelHeaderColumn
    height: (parent.height * 0.5) - anchors.topMargin
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
      topMargin: 80
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 20

    Text {
      id: removeLiquidityHeader
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You will remove liquidity from the <b>" +
      leftSymbol + "/" + rightSymbol
      + "</b> pool"
    }

    Row {
      id: removeLiquidityLogos
      height: 64
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 20

      AVMEAsyncImage {
        id: addExchangeLogo
        height: 48
        width: 48
        anchors.verticalCenter: parent.verticalCenter
        imageSource: exchangeLogo
      }

      Text {
        id: removeLiquidityOrder
        anchors.verticalCenter: parent.verticalCenter
        color: "#FFFFFF"
        font.pixelSize: 48.0
        text: " -> "
      }

      Rectangle {
        id: leftLogoRectangle
        height: 64
        width: 64
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        radius: 5
        anchors.margins: 20

        AVMEAsyncImage {
          id: leftLogo
          height: 48
          width: 48
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          imageSource: leftImageSource
        }
        MouseArea { 
          id: leftLogoMouseArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: (!loading)
          onEntered: leftLogoRectangle.color = "#1d1827"
          onExited: leftLogoRectangle.color = "transparent"
          onClicked: { removeLiquidityLeftAssetPopup.open() }
        }
      }

      Rectangle {
        id: rightLogoRectangle
        height: 64
        width: 64
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 20
        color: "transparent"
        radius: 5
        AVMEAsyncImage {
          id: rightLogo
          height: 48
          width: 48
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          imageSource: rightImageSource
        }
        MouseArea { 
          id: rightLogoMouseArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: (!loading)
          onEntered: rightLogoRectangle.color = "#1d1827"
          onExited: rightLogoRectangle.color = "transparent"
          onClicked: { removeLiquidityRightAssetPopup.open() }
        }
      }
    }
    Text {
      id: assetBalance
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: pairBalance
    }
  }

  // ======================================================================
  // LOADING IMAGE
  // ======================================================================

  Image {
    id: removeLiquidityLoadingPng
    anchors {
      top: removeLiquidityPanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: 0
      bottomMargin: 50
    }
    fillMode: Image.PreserveAspectFit
    source: "qrc:/img/icons/loading.png"
    RotationAnimator {
      target: removeLiquidityLoadingPng
      from: 0
      to: 360
      duration: 1000
      loops: Animation.Infinite
      easing.type: Easing.InOutQuad
      running: true
    }
  }

  // ======================================================================
  // APPROVAL
  // ======================================================================

  Column {
    id: removeLiquidityPanelApprovalColumn
    anchors {
      top: removeLiquidityPanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: 20
      bottomMargin: 20
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 20

    Text {
      id: removeLiquidityApprovalText
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You need to approve your Account <br> in order to remove<br><b>"
        + leftSymbol + "/" + rightSymbol
        + "</b> from the pool"
        + "<br>This operation will have a total gas cost of:<br><b>"
        + qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
        + " AVAX</b>"
    }

    AVMEButton {
      id: approveBtn
      width: parent.width
      enabled: true
      anchors.horizontalCenter: parent.horizontalCenter
      text: (enabled) ? "Approve" : "Not enough funds"
      onClicked: { 
        approveTx()
        if (checkTransactionFunds()) {
          confirmTransactionPopup.setData(
            to,
            coinValue,
            txData,
            gas,
            gasPrice,
            true,
            info,
            historyInfo
          )
          confirmTransactionPopup.open()
        } else {
          fundsPopup.open();
        }
      }
    }
  }

  // ======================================================================
  // UNAVAILABLE PAIR
  // ======================================================================

  Column {
    id: removeLiquidityPanelPairUnavailable
    anchors {
      top: removeLiquidityPanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: 20
      bottomMargin: 20
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 20

    Text {
      id: addLiquidityPairUnavailableText
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: "#FFFFFF"
      font.pixelSize: 18.0
      text: "The desired pair is unavailable<br>Please select other"
    }
  }
  // ======================================================================
  // DETAILS
  // ======================================================================

  Column {
    id: removeLiquidityPanelDetailsColumn
    anchors {
      top: removeLiquidityPanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: -40
      bottomMargin: 20
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 20

    Slider {
      id: liquidityLPSlider
      from: 0
      value: 0
      to: 100
      stepSize: 1
      snapMode: Slider.SnapAlways
      width: parent.width * 0.8
      anchors.left: parent.left
      anchors.margins: 20
      background: Rectangle {
        x: liquidityLPSlider.leftPadding
        y: liquidityLPSlider.topPadding + (liquidityLPSlider.availableHeight / 2) - (height / 2)
        width: liquidityLPSlider.availableWidth
        height: liquidityLPSlider.availableHeight * 0.1
        radius: 5
        color: "#888888"
        Rectangle {
          width: liquidityLPSlider.visualPosition * parent.width
          height: parent.height
          color: "#AD00FA"
          radius: 5
        }
      }
      onMoved: { 
        var estimates = calculateRemoveLiquidityAmount(
          removeLiquidityInfo["userLeftReserves"], removeLiquidityInfo["userRightReserves"], value, removeLiquidityInfo["pairBalance"]
        )
        removeAssetLeftEstimate = estimates.left
        removeAssetRightEstimate = estimates.right
        removeLPEstimate = qmlApi.weiToFixedPoint(estimates.lp,18)

       }
      Text {
        id: sliderText
        anchors.left: parent.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: (parent.enabled) ? "#FFFFFF" : "#444444"
        font.pixelSize: 24.0
        text: parent.value + "%"
      }
    }

    Row {
      id: sliderBtnRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 20

      AVMEButton {
        id: sliderBtn25
        enabled: (+pairBalance != 0)
        width: (parent.parent.width * 0.2)
        text: "25%"
        onClicked: { liquidityLPSlider.value = 25; liquidityLPSlider.moved(); }
      }

      AVMEButton {
        id: sliderBtn50
        enabled: (+pairBalance != 0)
        width: (parent.parent.width * 0.2)
        text: "50%"
        onClicked: { liquidityLPSlider.value = 50; liquidityLPSlider.moved(); }
      }

      AVMEButton {
        id: sliderBtn75
        enabled: (+pairBalance != 0)
        width: (parent.parent.width * 0.2)
        text: "75%"
        onClicked: { liquidityLPSlider.value = 75; liquidityLPSlider.moved(); }
      }

      AVMEButton {
        id: sliderBtn100
        enabled: (+pairBalance != 0)
        width: (parent.parent.width * 0.2)
        text: "100%"
        onClicked: { liquidityLPSlider.value = 100; liquidityLPSlider.moved(); }
      }
    }

    Text {
      id: removeEstimate
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "<b>" + ((removeLPEstimate) ? removeLPEstimate : "0") + " LP</b>"
      + "<br><br>Estimated returns:<br>"
      + "<b>" + qmlApi.weiToFixedPoint(
        removeAssetLeftEstimate, leftDecimals
      )
      + " " + leftSymbol
      + "<br>" + qmlApi.weiToFixedPoint(
        removeAssetRightEstimate, rightDecimals
      )
      + " " + rightSymbol + "</b>"
    }

    AVMEButton {
      id: removeLiquidityBtn
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      enabled: ((liquidityLPSlider.value > 0) && +removeLPEstimate != 0)
      text: "Remove from the pool"
      onClicked: { 
        removeLiquidityTx()
        if (checkTransactionFunds()) {
          confirmTransactionPopup.setData(
            to,
            coinValue,
            txData,
            gas,
            gasPrice,
            true,
            info,
            historyInfo
          )
          confirmTransactionPopup.open()
        } else {
          fundsPopup.open();
        }
      }
    }
  }
  Rectangle {
    id: settingsRectangle
    height: 48
    width: 48
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 32
    anchors.rightMargin: 32
    color: "transparent"
    radius: 5
    Image {
      id: slippageSettingsImage
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: 32
      height: 32
      source: "qrc:/img/icons/Icon_Settings.png"
    }
    MouseArea {
      id: settingsMouseArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: settingsRectangle.color = "#1d1827"
      onExited: settingsRectangle.color = "transparent"
      onClicked: {
        slippageSettings.open();
      }
    }
  }
}