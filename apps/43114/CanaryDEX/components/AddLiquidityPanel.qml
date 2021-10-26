/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
import QtQuick 2.9
import QtQuick.Controls 2.2

import "qrc:/qml/components"
import "qrc:/qml/popups"

AVMEPanel {
  id: addLiquidityPanel
  title: "Add Liquidity"
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
   *    "pair" : "0x..."
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
  // It cannot load objects inside the "addLiquidityInfo" property

  property var addLiquidityInfo: ({})
  property string leftSymbol: ""
  property string leftImageSource: ""
  property string leftDecimals: ""
  property string leftAllowance: ""
  property string leftContract: ""
  property bool leftAllowed: false
  property string rightSymbol: ""
  property string rightImageSource: ""
  property string rightDecimals: ""
  property string rightAllowance: ""
  property string rightContract: ""
  property bool rightAllowed: false

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


  Timer { id: reservesTimer; interval: 500; repeat: true; onTriggered: (fetchReserves()) }
  Timer { id: allowanceTimer; interval: 100; repeat: true; onTriggered: (fetchAllowancesAndPair(false)) }
  Timer { id: balanceTimer; interval: 10; repeat: true; onTriggered: (updateBalances()) }

  Connections {
    target: qmlApi
    function onApiRequestAnswered(answer, requestID) {
      var resp = JSON.parse(answer)
      if (requestID == screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID) {
        for (var item in resp) {
          if (resp[item]["id"] == 1) {
            addLiquidityInfo["pair"] = qmlApi.parseHex(resp[item].result, ["address"])
          }
          if (resp[item]["id"] == 2) {
            addLiquidityInfo["left"]["allowance"] = qmlApi.parseHex(resp[item].result, ["uint"])
          }
          if (resp[item]["id"] == 3) {
            addLiquidityInfo["right"]["allowance"] = qmlApi.parseHex(resp[item].result, ["uint"])
          }
        }
        if (addLiquidityInfo["pair"] == "0x0000000000000000000000000000000000000000") {
          addLiquidityDetailsColumn.visible = false
          addLiquidityApprovalColumn.visible = false
          addLiquidityPairUnavailable.visible = true
          addLiquidityLoadingPng.visible = false
          loading = false;
          return
        }

        leftAllowance = addLiquidityInfo["left"]["allowance"]
        rightAllowance = addLiquidityInfo["right"]["allowance"]

        // AVAX doesn't need approval, tokens do (and individually)
        if (leftContract == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
          leftAllowed = true
        } else {
          var asset = accountHeader.tokenList[leftContract]
          leftAllowed = (+leftAllowance > +qmlApi.fixedPointToWei(
            asset["rawBalance"], leftDecimals
          ))
        }
        if (rightContract == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
          rightAllowed = true
        } else {
          var asset = accountHeader.tokenList[rightContract]
          rightAllowed = (+rightAllowance > +qmlApi.fixedPointToWei(
            asset["rawBalance"], rightDecimals
          ))
        }

        addLiquidityInfo["left"]["allowed"] = leftAllowed
        addLiquidityInfo["right"]["allowed"] = rightAllowed

        if (leftAllowed && rightAllowed) {
          allowanceTimer.stop()
        } else {
          allowanceTimer.start()
        }
        reservesTimer.start()
      }
      if (requestID == screenName + "_" + title + "_" +  "_fetchReserves_" + randomID) {
        var reservesAnswer
        for (var item in resp) {
          if (resp[item]["id"] == 1) {
            reservesAnswer = qmlApi.parseHex(resp[item].result, ["uint", "uint", "uint"])
          }
        }

        var reserves = ({})
        var lowerAddress = qmlApi.getFirstFromPair(
          addLiquidityInfo["left"]["contract"], addLiquidityInfo["right"]["contract"]
        )
        if (lowerAddress == addLiquidityInfo["left"]["contract"]) {
          reserves["reservesIn"] = reservesAnswer[0]
          reserves["reservesOut"] = reservesAnswer[1]
        } else if (lowerAddress == addLiquidityInfo["right"]["contract"]) {
          reserves["reservesIn"] = reservesAnswer[1]
          reserves["reservesOut"] = reservesAnswer[0]
        }
        reserves["decimalsIn"] = addLiquidityInfo["left"]["decimals"]
        reserves["decimalsOut"] = addLiquidityInfo["right"]["decimals"]
        addLiquidityInfo["reserves"] = reserves

        loading = false;
        if (rightAllowed && leftAllowed) {
          addLiquidityDetailsColumn.visible = true
          addLiquidityApprovalColumn.visible = false
          addLiquidityPairUnavailable.visible = false
          addLiquidityLoadingPng.visible = false
          allowanceTimer.stop()
        } else {
          addLiquidityDetailsColumn.visible = false
          addLiquidityApprovalColumn.visible = true
          addLiquidityPairUnavailable.visible = false
          addLiquidityLoadingPng.visible = false
        }
      }
    }
  }

  Connections {
    target: addLiquidityLeftAssetCombobox
    function onActivated() {
      // No need to reload in case of the same asset is selected
      if (addLiquidityInfo["left"]["contract"] == addLiquidityLeftAssetCombobox.chosenAsset.address) {
        return
      }

      // Edge case for WAVAX
      if (addLiquidityLeftAssetCombobox.chosenAsset.address == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        addLiquidityInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        addLiquidityInfo["left"]["allowance"] = "0";
      }
      addLiquidityInfo["left"]["decimals"] = addLiquidityLeftAssetCombobox.chosenAsset.decimals
      addLiquidityInfo["left"]["contract"] = addLiquidityLeftAssetCombobox.chosenAsset.address
      addLiquidityInfo["left"]["symbol"] = addLiquidityLeftAssetCombobox.chosenAsset.symbol

      var img = ""
      if (addLiquidityLeftAssetCombobox.chosenAsset.address == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (addLiquidityLeftAssetCombobox.chosenAsset.address == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(addLiquidityLeftAssetCombobox.chosenAsset.address)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      addLiquidityInfo["left"]["imageSource"] = img
      addLiquidityInfo["pair"] = ""
      addLiquidityInfo["reserves"] = ({});

      // Prevent selecting the same two assets
      if (addLiquidityInfo["right"]["contract"] == addLiquidityLeftAssetCombobox.chosenAsset.address) {
        addLiquidityRightAssetCombobox.currentIndex = (addLiquidityLeftAssetCombobox.currentIndex == 0) ? 1 : 0
        addLiquidityRightAssetCombobox.activated(addLiquidityRightAssetCombobox.currentIndex)
        return
      }

      updateDisplay()
      fetchAllowancesAndPair(true)
    }
  }

  Connections {
    target: addLiquidityRightAssetCombobox
    function onActivated() {
      // No need to reload in case of the same asset is selected
      if (addLiquidityInfo["right"]["contract"] == addLiquidityRightAssetCombobox.chosenAsset.address) {
        return
      }

      // Edge case for WAVAX
      if (addLiquidityRightAssetCombobox.chosenAsset.address == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        addLiquidityInfo["right"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        addLiquidityInfo["right"]["allowance"] = "0";
      }
      addLiquidityInfo["right"]["decimals"] = addLiquidityRightAssetCombobox.chosenAsset.decimals
      addLiquidityInfo["right"]["contract"] = addLiquidityRightAssetCombobox.chosenAsset.address
      addLiquidityInfo["right"]["symbol"] = addLiquidityRightAssetCombobox.chosenAsset.symbol

      var img = ""
      if (addLiquidityRightAssetCombobox.chosenAsset.address == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (addLiquidityRightAssetCombobox.chosenAsset.address == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(addLiquidityRightAssetCombobox.chosenAsset.address)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      addLiquidityInfo["right"]["imageSource"] = img
      addLiquidityInfo["pair"] = "";
      addLiquidityInfo["reserves"] = ({});

      // Prevent selecting the same two assets
      if (addLiquidityInfo["left"]["contract"] == addLiquidityRightAssetCombobox.chosenAsset.address) {
        addLiquidityLeftAssetCombobox.currentIndex = (addLiquidityRightAssetCombobox.currentIndex == 0) ? 1 : 0
        addLiquidityLeftAssetCombobox.activated(addLiquidityLeftAssetCombobox.currentIndex)
        return
      }

      updateDisplay()
      fetchAllowancesAndPair(true)
    }
  }

  Component.onCompleted: {
    addLiquidityInfo["left"] = ({});
    addLiquidityInfo["right"] = ({});
    addLiquidityInfo["pair"] = "";
    addLiquidityInfo["reserves"] = ({});
    addLiquidityInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
    addLiquidityInfo["left"]["decimals"] = "18";
    addLiquidityInfo["left"]["contract"] = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    addLiquidityInfo["left"]["symbol"] = "AVAX";
    addLiquidityInfo["left"]["imageSource"] = "qrc:/img/avax_logo.png";
    addLiquidityInfo["left"]["allowed"] = true
    addLiquidityInfo["right"]["allowance"] = "0";
    addLiquidityInfo["right"]["decimals"] = "18";
    addLiquidityInfo["right"]["contract"] = "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed";
    addLiquidityInfo["right"]["symbol"] = "AVME";
    addLiquidityInfo["right"]["imageSource"] = "qrc:/img/avme_logo.png";
    addLiquidityInfo["right"]["allowed"] = false
    // Information displayed to the user needs to be kept on their own variable
    // As a string. For that reason we have created a updateDisplay() function
    // Which will provide these variables with the new information from
    // the addLiquidityInfo var
    updateDisplay()
    balanceTimer.start()
  }

  function updateDisplay() {
    randomID = qmlApi.getRandomID()
    addRightAssetInput.text   = ""
    addLeftAssetInput.text    = ""
    leftSymbol        = addLiquidityInfo["left"]["symbol"]
    leftImageSource   = addLiquidityInfo["left"]["imageSource"]
    leftDecimals      = addLiquidityInfo["left"]["decimals"]
    leftAllowance     = addLiquidityInfo["left"]["allowance"]
    leftContract      = addLiquidityInfo["left"]["contract"]
    leftAllowed       = addLiquidityInfo["left"]["allowed"]
    rightSymbol       = addLiquidityInfo["right"]["symbol"]
    rightImageSource  = addLiquidityInfo["right"]["imageSource"]
    rightDecimals     = addLiquidityInfo["right"]["decimals"]
    rightAllowance    = addLiquidityInfo["right"]["allowance"]
    rightContract     = addLiquidityInfo["right"]["contract"]
    rightAllowed      = addLiquidityInfo["right"]["allowed"]
    updateBalances()
    fetchAllowancesAndPair(true)
  }

  function updateBalances() {
    if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      assetBalance.text = "<b>" + accountHeader.coinRawBalance + " " + addLiquidityInfo["left"]["symbol"] + "</b>"
    } else {
      var asset = accountHeader.tokenList[addLiquidityInfo["left"]["contract"]]
      assetBalance.text = "<b>" + asset["rawBalance"] + " " + addLiquidityInfo["left"]["symbol"] + "</b>"
    }

    if (addLiquidityInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      assetBalance.text += "<br><b>" + accountHeader.coinRawBalance + " " + addLiquidityInfo["right"]["symbol"] + "</b>"
    } else {
      var asset = accountHeader.tokenList[addLiquidityInfo["right"]["contract"]]
      assetBalance.text += "<br><b>" + asset["rawBalance"] + " " + addLiquidityInfo["right"]["symbol"] + "</b>"
    }
  }

  function fetchAllowancesAndPair(firstCall) {
    if (firstCall) {
      randomID = qmlApi.getRandomID()
      addLiquidityDetailsColumn.visible = false
      addLiquidityApprovalColumn.visible = false
      addLiquidityPairUnavailable.visible = false
      addLiquidityLoadingPng.visible = true
      loading = true
      reservesTimer.stop()
      allowanceTimer.stop()
    }

    qmlApi.clearAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID)

    // LeftAsset/RightAsset pair
    qmlApi.buildGetPairReq(
      addLiquidityInfo["left"]["contract"],
      addLiquidityInfo["right"]["contract"],
      factory,
      screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID
    )
    // Left Asset allowance
    qmlApi.buildGetAllowanceReq(
      addLiquidityInfo["left"]["contract"],
      accountHeader.currentAddress,
      router,
      screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID
    )
    // Right Asset allowance
    qmlApi.buildGetAllowanceReq(
      addLiquidityInfo["right"]["contract"],
      accountHeader.currentAddress,
      router,
      screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID
    )
    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowancesAndPair_" + randomID)
  }

  function fetchReserves() {
    qmlApi.clearAPIRequests(screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
    qmlApi.buildGetReservesReq(addLiquidityInfo["pair"], screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
    qmlApi.buildGetTotalSupplyReq(addLiquidityInfo["pair"], screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
  }

  function calculateExchangeAmount(amountIn, inReserves, outReserves, inDecimals, outDecimals) {
    var amountInWei = qmlApi.fixedPointToWei(amountIn, inDecimals)

    var numerator = qmlApi.floor(qmlApi.mul(qmlApi.mul(amountInWei, 1000), outReserves))
    if (qmlApi.floor(qmlApi.div(qmlApi.div(numerator, outReserves),1000)) != amountInWei) { return } // Mul overflow

    var denominator = qmlApi.floor(qmlApi.mul(inReserves, 1000))
    if (qmlApi.floor(qmlApi.div(denominator,1000)) != inReserves) { return } // Mul overflow

    var amountOut = qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.div(numerator, denominator)), outDecimals)
    return amountOut
  }

  function calculateExchangeAmountText(amountIn, isLeft) {
    var amountOut = ""
    if (isLeft) {
      amountOut = calculateExchangeAmount(amountIn,
        addLiquidityInfo["reserves"]["reservesIn"],
        addLiquidityInfo["reserves"]["reservesOut"],
        addLiquidityInfo["reserves"]["decimalsIn"],
        addLiquidityInfo["reserves"]["decimalsOut"]
      )
    } else {
      amountOut = calculateExchangeAmount(amountIn,
        addLiquidityInfo["reserves"]["reservesOut"],
        addLiquidityInfo["reserves"]["reservesIn"],
        addLiquidityInfo["reserves"]["decimalsOut"],
        addLiquidityInfo["reserves"]["decimalsIn"])
    }
    return amountOut;
  }

  function calculateMaxAddLiquidityAmount() {
    // Get the max asset amounts, check who is lower and calculate accordingly
    var leftMax = ""
    var rightMax = ""

    if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      var transactionFee = qmlApi.floor(qmlApi.mul(500000, (+gasPrice * 1000000000)))
      var WeiFreeWAVAXBalance = qmlApi.floor(qmlApi.sub(qmlApi.fixedPointToWei(accountHeader.coinRawBalance,18), transactionFee))
      if (+WeiFreeWAVAXBalance > 0) {
        leftMax = qmlApi.weiToFixedPoint(WeiFreeWAVAXBalance, 18)
      } else {
        leftMax = "0"
      }
    } else {
      leftMax = accountHeader.tokenList[addLiquidityInfo["left"]["contract"]]["rawBalance"]
    }

    if (addLiquidityInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      var transactionFee = qmlApi.floor(qmlApi.mul(500000, (+gasPrice * 1000000000)))
      var WeiFreeWAVAXBalance = qmlApi.floor(qmlApi.sub(qmlApi.fixedPointToWei(accountHeader.coinRawBalance,18), transactionFee))
      if (+WeiFreeWAVAXBalance > 0) {
        rightMax = qmlApi.weiToFixedPoint(WeiFreeWAVAXBalance, 18)
      } else {
        rightMax = "0"
      }
    } else {
      rightMax = accountHeader.tokenList[addLiquidityInfo["right"]["contract"]]["rawBalance"]
    }
    var assetLeftAmount, assetRightAmount
    assetLeftAmount = calculateExchangeAmountText(leftMax, true)
    assetRightAmount = calculateExchangeAmountText(rightMax, false)
    var lowerAddress = qmlApi.getFirstFromPair(
      addLiquidityInfo["left"]["contract"], addLiquidityInfo["right"]["contract"]
    )
    // Limit the max amount to the lowest the user has, then set the right
    // values afterwards. If assetLeftAmount is higher than the balance in leftMax,
    // then that balance is limiting. Same with assetRightAmount and rightMax.
    var leftMaxTmp = leftMax
    var rightMaxTmp = rightMax
    // asset1MaxTmp = Input 1 Balance
    // asset2MaxTmp = Input 2 Balance
    // asset1Amount = How much 1 is worth at 2
    // asset2Amount = How much 2 is worth at 1
    if (+leftMaxTmp > +assetRightAmount) {
      leftMax = assetRightAmount
    }
    if (+rightMaxTmp > +assetLeftAmount) {
      rightMax = assetLeftAmount
    }
    if (lowerAddress == addLiquidityInfo["left"]["contract"]) {
      addLeftAssetInput.text = leftMax
      addRightAssetInput.text = calculateExchangeAmountText(leftMax, true)
    } else if (lowerAddress == addLiquidityInfo["right"]["contract"]) {
      addRightAssetInput.text = rightMax
      addLeftAssetInput.text = calculateExchangeAmountText(rightMax, false)
    }
  }

  function calculateTransactionCost(gasLimit, amountInLeft, amountInRight) {
    var transactionFee = qmlApi.floor(qmlApi.mul(gasLimit, (+gasPrice * 1000000000)))
    var WeiWAVAXBalance = qmlApi.floor(qmlApi.fixedPointToWei(accountHeader.coinRawBalance,18))
    if (+transactionFee > +WeiWAVAXBalance) {
      return false
    }

    // Edge case for WAVAX
    if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7" ||
        addLiquidityInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7"
        ) {
      var totalCost = qmlApi.weiToFixedPoint(qmlApi.sum(transactionFee, qmlApi.fixedPointToWei(
        ((addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") ?
          amountInLeft :
          amountInRight
        )
        ,18)),18)
      if (+totalCost > +accountHeader.coinRawBalance) {
        return false
      }
    }

    if (addLiquidityInfo["left"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      if (+amountInLeft > +accountHeader.tokenList[addLiquidityInfo["left"]["contract"]]["rawBalance"]) {
        return false
      }
    }
    if (addLiquidityInfo["right"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      if (+amountInRight > +accountHeader.tokenList[addLiquidityInfo["right"]["contract"]]["rawBalance"]) {
        return false
      }
    }

    return true
  }

  function approveTx(contract) {
    to = contract
    coinValue = 0
    gas = 70000
    var ethCallJson = ({})
    info = "You will approve <b>"
    + addLiquidityInfo["left"]["symbol"] + "/" + addLiquidityInfo["right"]["symbol"]
    + "</b> LP in + " + exchangeName + " router contract"
    historyInfo = "Approve <b>" + addLiquidityInfo["left"]["symbol"] + "/" + addLiquidityInfo["right"]["symbol"]  + " LP</b> in " + exchangeName
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

  function addLiquidityTx() {
    to = router
    gas = 500000
    info = "You will Add <b>" + addLeftAssetInput.text + " " + leftSymbol + "</b> <br>and<br> <b>"
    info += addRightAssetInput.text + " " + rightSymbol + "</b> on Pangolin Liquidity Pool"
    historyInfo = "Add <b>" + leftSymbol + "</b> and <b>" + rightSymbol + "</b> to " + exchangeName + " Liquidity"
    if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7" ||
        addLiquidityInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      var ethCallJson = ({})
      ethCallJson["function"] = "addLiquidityAVAX(address,uint256,uint256,uint256,address,uint256)"
      ethCallJson["args"] = []
      // Token
      if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        ethCallJson["args"].push(addLiquidityInfo["right"]["contract"])
      } else {
        ethCallJson["args"].push(addLiquidityInfo["left"]["contract"])
      }
      // amountTokenDesired
      var amountTokenDesired
      if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        amountTokenDesired = qmlApi.fixedPointToWei(addRightAssetInput.text, addLiquidityInfo["right"]["decimals"])
      } else {
        amountTokenDesired = qmlApi.fixedPointToWei(addLeftAssetInput.text, addLiquidityInfo["left"]["decimals"])
      }
      ethCallJson["args"].push(String(amountTokenDesired))
      // amountTokenMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(amountTokenDesired, desiredSlippage))) // 1% Slippage
      // amountAVAXMin
      var amountAVAX
      if (addLiquidityInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        amountAVAX = qmlApi.fixedPointToWei(addLeftAssetInput.text,18)
      } else {
        amountAVAX = qmlApi.fixedPointToWei(addRightAssetInput.text,18)
      }
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(amountAVAX, desiredSlippage)))
      // to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // deadline
      ethCallJson["args"].push(qmlApi.mul(qmlApi.sum(qmlApi.getCurrentUnixTime(),3600),1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      coinValue = qmlApi.weiToFixedPoint(amountAVAX, 18)
      txData = ABI
    } else {
      var ethCallJson = ({})
      ethCallJson["function"] = "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)"
      ethCallJson["args"] = []
      // tokenA
      ethCallJson["args"].push(addLiquidityInfo["left"]["contract"])
      // tokenB
      ethCallJson["args"].push(addLiquidityInfo["right"]["contract"])
      // amountADesired
      var amountADesired = qmlApi.fixedPointToWei(addLeftAssetInput.text, addLiquidityInfo["left"]["decimals"])
      ethCallJson["args"].push(amountADesired)
      // amountBDesired
      var amountBDesired = qmlApi.fixedPointToWei(addRightAssetInput.text, addLiquidityInfo["right"]["decimals"])
      ethCallJson["args"].push(amountBDesired)
      // amountAMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(amountADesired, desiredSlippage))) // 1% Slippage
      // amountBMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(amountBDesired, desiredSlippage))) // 1% Slippage
      // to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // deadline
      ethCallJson["args"].push(qmlApi.mul(qmlApi.sum(qmlApi.getCurrentUnixTime(),3600),1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      coinValue = "0"
      txData = ABI
    }
  }

  // ======================================================================
  // HEADER
  // ======================================================================

  Column {
    id: addLiquidityHeaderColumn
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
      id: addLiquidityHeader
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You will add liquidity to the <b>" + leftSymbol + "/" + rightSymbol + "</b> pool"
    }

    Row {
      id: addLiquidityLogos
      height: 64
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.margins: 20
      spacing: 10

      AVMEAssetCombobox {
        id: addLiquidityLeftAssetCombobox
        height: parent.height
        width: addLiquidityHeaderColumn.width / 3
        defaultToAVME: false
      }

      AVMEAssetCombobox {
        id: addLiquidityRightAssetCombobox
        height: parent.height
        width: addLiquidityHeaderColumn.width / 3
        defaultToAVME: true
      }

      Image {
        id: arrowImage
        height: 48
        width: 48
        anchors.verticalCenter: parent.verticalCenter
        fillMode: Image.PreserveAspectFit
        source: "qrc:/img/icons/arrow.png"
      }

      AVMEAsyncImage {
        id: addExchangeLogo
        height: 48
        width: 48
        anchors.verticalCenter: parent.verticalCenter
        imageSource: exchangeLogo
      }
    }

    Text {
      id: assetBalance
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "Loading asset balances..."
    }
  }

  // ======================================================================
  // LOADING IMAGE
  // ======================================================================

  Image {
    id: addLiquidityLoadingPng
    anchors {
      top: addLiquidityHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: 0
      bottomMargin: 50
    }
    fillMode: Image.PreserveAspectFit
    source: "qrc:/img/icons/loading.png"
    RotationAnimator {
      target: addLiquidityLoadingPng
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
    id: addLiquidityApprovalColumn
    anchors {
      top: addLiquidityHeaderColumn.bottom
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
      id: addLiquidityApprovalText
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You need to approve your Account in order to add<br><b>"
        + ((!leftAllowed) ? leftSymbol : "" )
        + ((!leftAllowed && !rightAllowed) ? " and " : "")
        + ((!rightAllowed) ? rightSymbol : "")
        + "</b> to the pool."
        + "<br>This operation will have a total gas cost of:<br><b>"
        + qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
        + " AVAX</b>"
    }

    AVMEButton {
      id: approveLeftAssetBtn
      width: parent.width
      visible: (!leftAllowed)
      enabled: (+accountHeader.coinRawBalance >=
        +qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
      )
      anchors.horizontalCenter: parent.horizontalCenter
      text: (enabled) ? "Approve " + leftSymbol : "Not enough funds"
      onClicked: {
        approveTx(addLiquidityInfo["left"]["contract"])
        if (calculateTransactionCost(70000, "0", "0")) {
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
    AVMEButton {
      id: approveRightAssetBtn
      width: parent.width
      visible: (!rightAllowed)
      enabled: (+accountHeader.coinRawBalance >=
        +qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
      )
      anchors.horizontalCenter: parent.horizontalCenter
      text: (enabled) ? "Approve " + rightSymbol : "Not enough funds"
      onClicked: {
        approveTx(addLiquidityInfo["right"]["contract"])
        if (calculateTransactionCost(70000, "0", "0")) {
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
    id: addLiquidityPairUnavailable
    anchors {
      top: addLiquidityHeaderColumn.bottom
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
    id: addLiquidityDetailsColumn
    anchors {
      top: addLiquidityHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      bottomMargin: 20
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 25

    AVMEInput {
      id: addLeftAssetInput
      width: parent.width
      validator: RegExpValidator { regExp: qmlApi.createRegExp("[0-9]{1,99}(?:\\.[0-9]{1," + leftDecimals + "})?") }
      label: leftSymbol + " Amount"
      placeholder: "Fixed point amount (e.g. 0.5)"
      onTextEdited: {
        addRightAssetInput.text = calculateExchangeAmountText(addLeftAssetInput.text, true)
      }
    }

    AVMEInput {
      id: addRightAssetInput
      width: parent.width
      validator: RegExpValidator { regExp: qmlApi.createRegExp("[0-9]{1,99}(?:\\.[0-9]{1," + leftDecimals + "})?") }
      label: rightSymbol + " Amount"
      placeholder: "Fixed point amount (e.g. 0.5)"
      onTextEdited: {
        addLeftAssetInput.text = calculateExchangeAmountText(addRightAssetInput.text, false)
      }
    }

    AVMEButton {
      id: addMaxBtn
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Max Amounts"
      onClicked: { calculateMaxAddLiquidityAmount() }
    }

    AVMEButton {
      id: addLiquidityBtn
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      enabled: (addLeftAssetInput.acceptableInput && addRightAssetInput.acceptableInput)
      text: "Add to the pool"
      onClicked: {
        addLiquidityTx()
        if (calculateTransactionCost(500000, addLeftAssetInput.text, addRightAssetInput.text)) {
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
    anchors.topMargin: 16
    anchors.rightMargin: 16
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
