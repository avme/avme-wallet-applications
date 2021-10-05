/* Copyright (c) 2020-2021 AVME Developers
   Distributed under the MIT/X11 software license, see the accompanying
   file LICENSE or http://www.opensource.org/licenses/mit-license.php. */
   
import QtQuick 2.15
import QtQuick.Controls 2.2

import "qrc:/qml/components"
import "qrc:/qml/popups"


AVMEPanel {
  id: exchangeScreenPanel
  anchors.centerIn: parent
  title: "Exchange"
  height: parent.height * 0.8
  width: parent.width * 0.4

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
   *    "pairs" : [
   *      "0x...",
   *      "0x..."
   *    ]
   *
   *    "routing": [
   *      "0x...",
   *      "0x..."
   *    ]
   *    "reserves": [
   *      {
   *        "reservesIn" : "...",
   *        "reservesOut": "...",
   *        "decimalsIn" : xx,
   *        "decimalsOut": yy
   *      },
   *      {
   *        "reservesIn" : "...",
   *        "reservesOut": "..."
   *        "decimalsIn" : xx,
   *        "decimalsOut": yy
   *      }
   *    ]
   *  }
   */
  
  // We need properties for information
  // used inside objects, as when you open a new screen
  // It cannot load objects inside the "exchangeInfo" property

  property var exchangeInfo: ({})
  property string leftSymbol: ""
  property string leftImageSource: ""
  property string leftDecimals: ""
  property string leftAllowance: ""
  property string leftContract: ""
  property string rightSymbol: ""
  property string rightImageSource: ""
  property string rightDecimals: ""
  property string rightAllowance: ""
  property string rightContract: ""
  property double swapImpact: 0

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


  // Timers for constantly update values

  Timer { id: balanceTimer; interval: 10; repeat: true; onTriggered: (updateBalances()) }
  Timer { id: reservesTimer; interval: 500; repeat: true; onTriggered: (fetchReserves()) }
  Timer { id: allowanceTimer; interval: 100; repeat: true; onTriggered: (fetchAllowanceAndPairs(false)) }

  // Connections to handle API answers
  Connections {
    target: qmlApi
    function onApiRequestAnswered(answer, requestID) {
      if (requestID == screenName + "_" + title + "_" + "_fetchAllowanceAndPairs_" + randomID) {
        // Parse the answer as a JSON
        var respArr = JSON.parse(answer)
        var leftAllowance = ""
        var rightAllowance = ""
        var pairAddress = ""
        var pairTokenInAddress = ""
        var pairTokenOutAddress = ""
        for (var answerItem in respArr) {
          if (respArr[answerItem]["id"] == 1) {
            // Allowance for leftAsset
            leftAllowance = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
          }
          if (respArr[answerItem]["id"] == 2) {
            // allowance for rightAsset
            rightAllowance = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
          }
          if (respArr[answerItem]["id"] == 3) {
            // pair left/right
            pairAddress = qmlApi.parseHex(respArr[answerItem].result, ["address"])
          }
          if (respArr[answerItem]["id"] == 4) {
            // pair left/WAVAX
            pairTokenInAddress = qmlApi.parseHex(respArr[answerItem].result, ["address"])
          }
          if (respArr[answerItem]["id"] == 5) {
            // pair right/WAVAX
            pairTokenOutAddress = qmlApi.parseHex(respArr[answerItem].result, ["address"])
          }
        }
        
        exchangeInfo["left"]["allowance"] = leftAllowance
        exchangeInfo["right"]["allowance"] = rightAllowance
        if (!(exchangeInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7")) {
          var asset = accountHeader.tokenList[exchangeInfo["left"]["contract"]]
          if (+qmlApi.fixedPointToWei(asset["rawBalance"], asset["decimals"]) >= +leftAllowance) {
            exchangeInfo["left"]["approved"] = false
          } else {
            exchangeInfo["left"]["approved"] = true
          }
        } else {
          // WAVAX does not require approval
          exchangeInfo["left"]["approved"] = true
        }

        if (!(exchangeInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7")) {
          var asset = accountHeader.tokenList[exchangeInfo["right"]["contract"]]
          if (+qmlApi.fixedPointToWei(asset["rawBalance"], asset["decimals"]) >= +rightAllowance) {
            exchangeInfo["right"]["approved"] = false
          } else {
            exchangeInfo["right"]["approved"] = true
          }
        } else {
          // WAVAX does not require approval
          exchangeInfo["right"]["approved"] = true
        }

        // Add edge case situation where the token is not available on the DEX
        if (pairAddress == 0x0000000000000000000000000000000000000000 &&
            pairTokenInAddress == 0x0000000000000000000000000000000000000000 &&
            pairTokenOutAddress == 0x0000000000000000000000000000000000000000) {
            exchangePanelApprovalColumn.visible = false
            exchangePanelDetailsColumn.visible = false
            exchangePanelLoadingPng.visible = false
            exchangePanelUnavailablePair.visible = true
            loading = false
            return
        }
        

        // Check allowance to see if we can proceed collecting further information
        // Only check if it is a token and not WAVAX, as WAVAX does NOT require allowance
        if (!exchangeInfo["left"]["approved"]) {
          // Required allowance on the input asset!
          reservesTimer.start()
        } else {
          allowanceTimer.stop()
        }
        // Add the pair contracts and proper routing for the contract call
        // Only allow to push new pairs if the array is empty.
        if (exchangeInfo["pairs"].length == 0) {
          if (pairAddress == 0x0000000000000000000000000000000000000000) {
            exchangeInfo["pairs"].push(pairTokenInAddress)
            exchangeInfo["pairs"].push(pairTokenOutAddress)
            exchangeInfo["routing"].push(exchangeInfo["left"]["contract"])
            exchangeInfo["routing"].push("0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") // WAVAX
            exchangeInfo["routing"].push(exchangeInfo["right"]["contract"])
          } else {
            exchangeInfo["pairs"].push(pairAddress)
            exchangeInfo["routing"].push(exchangeInfo["left"]["contract"])
            exchangeInfo["routing"].push(exchangeInfo["right"]["contract"])
          }
        }
        reservesTimer.start()
      } else if (requestID == screenName + "_" + title + "_" +  "_fetchReserves_" + randomID) {
        var resp = JSON.parse(answer)
        exchangeInfo["reserves"] = ([])
        if (exchangeInfo["pairs"].length == 1) {
          var reservesAnswer = qmlApi.parseHex(resp[0].result, ["uint", "uint", "uint"])
          var reserves = ({})
          var lowerAddress = qmlApi.getFirstFromPair(
            exchangeInfo["left"]["contract"], exchangeInfo["right"]["contract"]
          )
          if (lowerAddress == exchangeInfo["left"]["contract"]) {
            reserves["reservesIn"] = reservesAnswer[0]
            reserves["reservesOut"] = reservesAnswer[1]
          } else if (lowerAddress == exchangeInfo["right"]["contract"]) {
            reserves["reservesIn"] = reservesAnswer[1]
            reserves["reservesOut"] = reservesAnswer[0]
          }
          reserves["decimalsIn"] = exchangeInfo["left"]["decimals"]
          reserves["decimalsOut"] = exchangeInfo["right"]["decimals"]
          exchangeInfo["reserves"].push(reserves)

        } else if (exchangeInfo["pairs"].length == 2) {
          // API can answer UNORDERED! we need to keep track properly
          var reservesTokenIn = ({})
          var reservesTokenOut = ({})
          for (var i = 0; i < resp.length; ++i) {
            // ID = 1 means reservesTokenIn
            // ID = 2 means reservesTokenOut
            if (resp[i]["id"] == 1) {
              var reservesAnswer = qmlApi.parseHex(resp[i].result, ["uint", "uint", "uint"])
              var reserves = ({})
              var lowerAddress = qmlApi.getFirstFromPair(
                exchangeInfo["left"]["contract"], "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7"
              )
              if (lowerAddress == exchangeInfo["left"]["contract"]) {
                reserves["reservesIn"] = reservesAnswer[0]
                reserves["reservesOut"] = reservesAnswer[1]
              } else if (lowerAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
                reserves["reservesIn"] = reservesAnswer[1]
                reserves["reservesOut"] = reservesAnswer[0]
              }
              reserves["decimalsIn"] = exchangeInfo["left"]["decimals"]
              reserves["decimalsOut"] = 18 // Exits as WAVAX.
              exchangeInfo["reserves"].push(reserves)
            }
            if (resp[i]["id"] == 2) {
              var reservesAnswer = qmlApi.parseHex(resp[i].result, ["uint", "uint", "uint"])
              var reserves = ({})
              var lowerAddress = qmlApi.getFirstFromPair(
                exchangeInfo["right"]["contract"], "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7"
              )
              if (lowerAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
                reserves["reservesIn"] = reservesAnswer[0]
                reserves["reservesOut"] = reservesAnswer[1]
              } else if (lowerAddress == exchangeInfo["right"]["contract"]) {
                reserves["reservesIn"] = reservesAnswer[1]
                reserves["reservesOut"] = reservesAnswer[0]
              }
              reserves["decimalsIn"] = 18 // Enters as WAVAX
              reserves["decimalsOut"] = exchangeInfo["right"]["decimals"]
              exchangeInfo["reserves"].push(reserves)
            }
          }
        }
        if (exchangeInfo["left"]["approved"]) {
          exchangePanelApprovalColumn.visible = false
          exchangePanelDetailsColumn.visible = true
          exchangePanelLoadingPng.visible = false
          exchangePanelUnavailablePair.visible = false
        } else {
          exchangePanelApprovalColumn.visible = true
          exchangePanelDetailsColumn.visible = false
          exchangePanelLoadingPng.visible = false
          exchangePanelUnavailablePair.visible = false
          allowanceTimer.start()
        }
        loading = false
      }
    }
  }

  Connections {
    target: exchangeLeftAssetPopup 
    function onAboutToHide() {
      // No need to reload in case of the same asset is selected
      if (exchangeInfo["left"]["contract"] == exchangeLeftAssetPopup.chosenAssetAddress) {
        return
      }

      // Do not allow to set a swap between the same assets
      if (exchangeInfo["right"]["contract"] == exchangeLeftAssetPopup.chosenAssetAddress) {
        return
      }
      
      // Edge case for WAVAX
      if (exchangeLeftAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        exchangeInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        exchangeInfo["left"]["allowance"] = "0";
      }
      exchangeInfo["left"]["decimals"] = exchangeLeftAssetPopup.chosenAssetDecimals
      exchangeInfo["left"]["contract"] = exchangeLeftAssetPopup.chosenAssetAddress
      exchangeInfo["left"]["symbol"] = exchangeLeftAssetPopup.chosenAssetSymbol

      var img = ""
      if (exchangeLeftAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (exchangeLeftAssetPopup.chosenAssetAddress == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(exchangeLeftAssetPopup.chosenAssetAddress)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      exchangeInfo["left"]["imageSource"] = img
      exchangeInfo["pairs"] = ([]);
      exchangeInfo["routing"] = ([]);
      exchangeInfo["reserves"] = ([]);
      updateDisplay()
      fetchAllowanceAndPairs(true)
    }
  }

  Connections {
    target: exchangeRightAssetPopup 
    function onAboutToHide() {
      // No need to reload in case of the same asset is selected
      if (exchangeInfo["right"]["contract"] == exchangeRightAssetPopup.chosenAssetAddress) {
        return
      }

      // Do not allow to set a swap between the same assets
      if (exchangeInfo["left"]["contract"] == exchangeRightAssetPopup.chosenAssetAddress) {
        return
      }
      
      // Edge case for WAVAX
      if (exchangeRightAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        exchangeInfo["right"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
      } else {
        exchangeInfo["right"]["allowance"] = "0";
      }
      exchangeInfo["right"]["decimals"] = exchangeRightAssetPopup.chosenAssetDecimals
      exchangeInfo["right"]["contract"] = exchangeRightAssetPopup.chosenAssetAddress
      exchangeInfo["right"]["symbol"] = exchangeRightAssetPopup.chosenAssetSymbol

      var img = ""
      if (exchangeRightAssetPopup.chosenAssetAddress == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
        img = "qrc:/img/avax_logo.png"
      } else if (exchangeRightAssetPopup.chosenAssetAddress == "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed") {
        img = "qrc:/img/avme_logo.png"
      } else {
        var tmpImg = qmlApi.getARC20TokenImage(exchangeRightAssetPopup.chosenAssetAddress)
        img = (tmpImg != "") ? "file:" + tmpImg : "qrc:/img/unknown_token.png"
      }

      exchangeInfo["right"]["imageSource"] = img
      exchangeInfo["pairs"] = ([]);
      exchangeInfo["routing"] = ([]);
      exchangeInfo["reserves"] = ([]);
      updateDisplay()
      fetchAllowanceAndPairs(true)
    }
  }

  // Initiallize and set assets to default to AVAX -> AVME
  Component.onCompleted: {
    exchangeInfo["left"] = ({});
    exchangeInfo["right"] = ({});
    exchangeInfo["pairs"] = ([]);
    exchangeInfo["routing"] = ([]);
    exchangeInfo["reserves"] = ([]);
    exchangeInfo["left"]["allowance"] = qmlApi.MAX_U256_VALUE(); // WAVAX does not require allowance
    exchangeInfo["left"]["decimals"] = "18";
    exchangeInfo["left"]["contract"] = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    exchangeInfo["left"]["symbol"] = "AVAX";
    exchangeInfo["left"]["imageSource"] = "qrc:/img/avax_logo.png";
    exchangeInfo["right"]["allowance"] = "0";
    exchangeInfo["right"]["decimals"] = "18";
    exchangeInfo["right"]["contract"] = "0x1ECd47FF4d9598f89721A2866BFEb99505a413Ed";
    exchangeInfo["right"]["symbol"] = "AVME";
    exchangeInfo["right"]["imageSource"] = "qrc:/img/avme_logo.png";
    // Information displayed to the user needs to be kept on their own variable
    // As a string. For that reason we have created a updateDisplay() function
    // Which will provide these variables with the new information from
    // the exchangeInfo var
    updateDisplay()
    fetchAllowanceAndPairs(true)
    balanceTimer.start()
  }

  function fetchReserves() {
    if (exchangeInfo["pairs"].length == 2) {
      // id 1 == left/WAVAX pair
      // id 2 == right/WAVAX pair
      qmlApi.buildGetReservesReq(exchangeInfo["pairs"][0], screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
      qmlApi.buildGetReservesReq(exchangeInfo["pairs"][1], screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
    } else {
      // id 1 == left/right pair
      qmlApi.buildGetReservesReq(exchangeInfo["pairs"][0], screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)
    }
    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchReserves_" + randomID)

  }

  function fetchAllowanceAndPairs(updateAssets) {
    if (updateAssets) {
      allowanceTimer.stop()
      reservesTimer.stop()
      randomID = qmlApi.getRandomID()
      exchangePanelApprovalColumn.visible = false
      exchangePanelDetailsColumn.visible = false
      exchangePanelUnavailablePair.visible = false 
      exchangePanelLoadingPng.visible = true
      loading = true
    }

    qmlApi.clearAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID)
    // Get allowance for inToken and reserves for all
    // Including reserves for both in/out tokens against WAVAX

    // Allowance for leftAsset
    qmlApi.buildGetAllowanceReq(
      exchangeInfo["left"]["contract"],
      accountHeader.currentAddress,
      router,
      screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID
    )
    // Allowance for rightAsset
    qmlApi.buildGetAllowanceReq(
      exchangeInfo["right"]["contract"],
      accountHeader.currentAddress,
      router,
      screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID
    )
    // Pair contract for left/right
    qmlApi.buildGetPairReq(
      exchangeInfo["left"]["contract"],
      exchangeInfo["right"]["contract"],
      factory,
      screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID
    )
    // Pair contract for left/WAVAX
    qmlApi.buildGetPairReq(
      exchangeInfo["left"]["contract"],
      "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7",
      factory,
      screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID
    )
    // Pair contract for right/WAVAX
    qmlApi.buildGetPairReq(
      "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7",
      exchangeInfo["right"]["contract"],
      factory,
      screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID
    )
    // id 1: allowance for left
    // id 2: allowance for right
    // id 3: Pair contract for left/right
    // id 4: Pair contract for left/WAVAX
    // id 5: Pair contract for right/WAVAX
    
    qmlApi.doAPIRequests(screenName + "_" + title + "_" +  "_fetchAllowanceAndPairs_" + randomID)
  }

  function updateDisplay() {
    randomID = qmlApi.getRandomID()
    rightInput.text   = ""
    leftInput.text    = ""
    leftSymbol        = exchangeInfo["left"]["symbol"]
    leftImageSource   = exchangeInfo["left"]["imageSource"]
    leftDecimals      = exchangeInfo["left"]["decimals"]
    leftAllowance     = exchangeInfo["left"]["allowance"]
    leftContract      = exchangeInfo["left"]["contract"]
    rightSymbol       = exchangeInfo["right"]["symbol"]
    rightImageSource  = exchangeInfo["right"]["imageSource"]
    rightDecimals     = exchangeInfo["right"]["decimals"]
    rightAllowance    = exchangeInfo["right"]["allowance"]
    rightContract     = exchangeInfo["right"]["contract"]
    updateBalances()

    // Check allowance to see if we should ask the user to allow it.
    // Only check if it is a token and not WAVAX, as WAVAX does NOT require allowance
    if (!exchangeInfo["left"]["approved"]) {
      // Reset the randomID, if there is a reserves request pending on the C++ side
      // It won't set the screens to visible again
      // Required allowance on the input asset!
      exchangePanelApprovalColumn.visible = true
      exchangePanelDetailsColumn.visible = false
      exchangePanelLoadingPng.visible = false
      exchangePanelUnavailablePair.visible = false
      reservesTimer.start()
      allowanceTimer.start()
    } else {
      // Set the screens back to visible, if allowed.
      exchangePanelApprovalColumn.visible = false
      exchangePanelDetailsColumn.visible = true
      exchangePanelLoadingPng.visible = false
      exchangePanelUnavailablePair.visible = false
      allowanceTimer.stop()
    }
  }

  function updateBalances() {
    if (exchangeInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      assetBalance.text = "<b>" + accountHeader.coinRawBalance + " " + exchangeInfo["left"]["symbol"] + "</b>"
    } else {
      var asset = accountHeader.tokenList[exchangeInfo["left"]["contract"]]
      assetBalance.text = "<b>" + asset["rawBalance"] + " " + exchangeInfo["left"]["symbol"] + "</b>"
    }
  }

  function swapOrder() {
    var tmpLeft = ({})
    var tmpRight = ({})
    tmpLeft = exchangeInfo["right"]
    tmpRight = exchangeInfo["left"]
    
    exchangeInfo["left"] = ({})
    exchangeInfo["right"] = ({})
    exchangeInfo["left"] = tmpLeft
    exchangeInfo["right"] = tmpRight

    // Invert pair/routing/reserves
    if (exchangeInfo["pairs"].length == 1) {
      var tmpRouting = ([])
      tmpRouting.push(exchangeInfo["routing"][1])
      tmpRouting.push(exchangeInfo["routing"][0])
      exchangeInfo["routing"] = tmpRouting

      var tmpReserves = ({})
      tmpReserves["reservesIn"]  = exchangeInfo["reserves"][0]["reservesOut"]
      tmpReserves["reservesOut"] = exchangeInfo["reserves"][0]["reservesIn"]
      tmpReserves["decimalsIn"]  = exchangeInfo["reserves"][0]["decimalsOut"]
      tmpReserves["decimalsOut"] = exchangeInfo["reserves"][0]["decimalsIn"]
      exchangeInfo["reserves"] = ([])
      exchangeInfo["reserves"].push(tmpReserves)
 
    } else {
      var tmpPairs = ([])
      tmpPairs.push(exchangeInfo["pairs"][1])
      tmpPairs.push(exchangeInfo["pairs"][0])
      exchangeInfo["pairs"] = tmpPairs

      var tmpRouting = ([])
      tmpRouting.push(exchangeInfo["routing"][2])
      tmpRouting.push(exchangeInfo["routing"][1])
      tmpRouting.push(exchangeInfo["routing"][0])
      exchangeInfo["routing"] = tmpRouting

      var tmpReserves1 = ({})
      var tmpReserves2 = ({})
      tmpReserves1["reservesIn"]  = exchangeInfo["reserves"][1]["reservesOut"]
      tmpReserves1["reservesOut"] = exchangeInfo["reserves"][1]["reservesIn"]
      tmpReserves1["decimalsIn"]  = exchangeInfo["reserves"][1]["decimalsOut"]
      tmpReserves1["decimalsOut"] = exchangeInfo["reserves"][1]["decimalsIn"]
      tmpReserves2["reservesIn"]  = exchangeInfo["reserves"][0]["reservesOut"]
      tmpReserves2["reservesOut"] = exchangeInfo["reserves"][0]["reservesIn"]
      tmpReserves2["decimalsIn"]  = exchangeInfo["reserves"][0]["decimalsOut"]
      tmpReserves2["decimalsOut"] = exchangeInfo["reserves"][0]["decimalsIn"]
      exchangeInfo["reserves"] = ([])
      exchangeInfo["reserves"] = ([])
      exchangeInfo["reserves"].push(tmpReserves1)
      exchangeInfo["reserves"].push(tmpReserves2)
    }

    updateDisplay()
  }

  function calculateExchangeAmount(amountIn, inReserves, outReserves, inDecimals, outDecimals) {
    var amountInWei = qmlApi.fixedPointToWei(amountIn, inDecimals)

    var amountInWithFee = qmlApi.floor(qmlApi.mul(amountInWei, qmlApi.sub(1000, exchangeFee)))
    if (qmlApi.floor(qmlApi.div(amountInWithFee, qmlApi.sub(1000, exchangeFee))) != amountInWei) { return } // Mul overflow 

    var numerator = qmlApi.floor(qmlApi.mul(amountInWithFee, outReserves))
    if (qmlApi.floor(qmlApi.div(numerator, outReserves)) != amountInWithFee) { return } // Mul overflow

    var denominator = qmlApi.floor(qmlApi.mul(inReserves, 1000))
    if (qmlApi.floor(qmlApi.div(denominator,1000)) != inReserves) { return } // Mul overflow
    if (+qmlApi.sum(denominator, amountInWithFee) < +denominator) { return }

    var amountOut = qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.div(numerator, denominator)), outDecimals)
    return amountOut
  }

  // Is right is used to know which order we need to use
  // in order to calculate which asset will be outputted
  // right or left asset.
  function calculateExchangeAmountText(amountIn, isLeft) {
    var amountOut = ""
    if (exchangeInfo["reserves"].length == 1) {
      if (isLeft) {
        amountOut = calculateExchangeAmount(amountIn, 
          exchangeInfo["reserves"][0]["reservesIn"], 
          exchangeInfo["reserves"][0]["reservesOut"], 
          exchangeInfo["reserves"][0]["decimalsIn"], 
          exchangeInfo["reserves"][0]["decimalsOut"]
        )
      } else {
        amountOut = calculateExchangeAmount(amountIn, 
          exchangeInfo["reserves"][0]["reservesOut"],  
          exchangeInfo["reserves"][0]["reservesIn"], 
          exchangeInfo["reserves"][0]["decimalsOut"], 
          exchangeInfo["reserves"][0]["decimalsIn"])
      }
    } else {
      if (isLeft) {
        amountOut = calculateExchangeAmount(amountIn, 
          exchangeInfo["reserves"][0]["reservesIn"], 
          exchangeInfo["reserves"][0]["reservesOut"],
          exchangeInfo["reserves"][0]["decimalsIn"], 
          exchangeInfo["reserves"][0]["decimalsOut"]
        )
        amountOut = calculateExchangeAmount(amountOut, 
          exchangeInfo["reserves"][1]["reservesIn"], 
          exchangeInfo["reserves"][1]["reservesOut"], 
          exchangeInfo["reserves"][1]["decimalsIn"], 
          exchangeInfo["reserves"][1]["decimalsOut"]
        )
      } else {
        amountOut = calculateExchangeAmount(amountIn, 
          exchangeInfo["reserves"][1]["reservesOut"], 
          exchangeInfo["reserves"][1]["reservesIn"], 
          exchangeInfo["reserves"][1]["decimalsIn"], 
          exchangeInfo["reserves"][1]["decimalsOut"]
        )
        amountOut = calculateExchangeAmount(amountOut, 
          exchangeInfo["reserves"][0]["reservesOut"], 
          exchangeInfo["reserves"][0]["reservesIn"], 
          exchangeInfo["reserves"][0]["decimalsIn"], 
          exchangeInfo["reserves"][0]["decimalsOut"]
        )
      }
    }
    return amountOut
  }

  function calculateExchangePriceImpact(reservesIn, amountIn, decimalsIn) {
    var amountInWei = qmlApi.fixedPointToWei(amountIn, decimalsIn)

    var priceImpactFloat = qmlApi.mul(
      100,qmlApi.sub(
        1, qmlApi.div(
          reservesIn, qmlApi.sum(
            reservesIn, amountInWei
          )
        )
      )
    )

    var priceImpact = qmlApi.div(
      qmlApi.floor(
        qmlApi.mul(priceImpactFloat, 100)
      ), 100
    )
    return priceImpact
  }

  function calculatePriceImpactText(amountIn) {
    return calculateExchangePriceImpact(exchangeInfo["reserves"][0]["reservesIn"], amountIn, exchangeInfo["reserves"][0]["decimalsIn"])
  }
  
  // ======================================================================
  // TRANSACTION RELATED FUNCTIONS
  // ======================================================================

  function approveTx() {
    to = exchangeInfo["left"]["contract"]
    coinValue = 0
    gas = 70000
    info = "You will Approve <b>" + exchangeInfo["left"]["symbol"] + "<\b> on " + exchangeName + " Router Contract"
    historyInfo = "Approve <b>" + exchangeInfo["left"]["symbol"] + "<\b< on " + exchangeName

    // approve(address,uint256)
    var ethCallJson = ({})
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

function swapTx(amountIn, amountOut) {
    to = router
    gas = 500000
    info = "You will Swap <b>" + amountIn + " " + exchangeInfo["left"]["symbol"] + "<\b> to <b>" +
    amountOut + " " + exchangeInfo["right"]["symbol"]   + "<\b> on Pangolin"
    historyInfo = "Swap <b>" + exchangeInfo["left"]["symbol"] +
    "<\b> to <b>" + exchangeInfo["right"]["symbol"] + "<\b>"
    if (exchangeInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      coinValue = String(amountIn)
      var ethCallJson = ({})
      var routing = ([])
      // swapExactAVAXForTokens(uint256,address[],address,uint256)
      ethCallJson["function"] = "swapExactAVAXForTokens(uint256,address[],address,uint256)"
      ethCallJson["args"] = []
      // uint256 amountOutMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(qmlApi.fixedPointToWei(amountOut, exchangeInfo["right"]["decimals"]), desiredSlippage)))
      // address[] path
      ethCallJson["args"].push(exchangeInfo["routing"])
      // address to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // uint256 deadline, 60 minutes deadline
      ethCallJson["args"].push(String((+qmlApi.getCurrentUnixTime() + 3600) * 1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address[]")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      txData = ABI
      return;
    }
    if (exchangeInfo["right"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      coinValue = 0
      var ethCallJson = ({})
      var routing = ([])
      // swapExactTokensForAVAX(uint256,uint256,address[],address,uint256)
      ethCallJson["function"] = "swapExactTokensForAVAX(uint256,uint256,address[],address,uint256)"
      ethCallJson["args"] = []
      // uint256 amountIn
      ethCallJson["args"].push(String(qmlApi.fixedPointToWei(amountIn, exchangeInfo["left"]["decimals"])))
      // amountOutMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(qmlApi.fixedPointToWei(amountOut, 18), desiredSlippage)))
      // address[] path
      ethCallJson["args"].push(exchangeInfo["routing"])
      // address to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // uint256 deadline 60 minutes deadline
      ethCallJson["args"].push(String((+qmlApi.getCurrentUnixTime() + 3600) * 1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address[]")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      txData = ABI
      return;
    }
    if (exchangeInfo["left"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7" && 
        exchangeInfo["right"]["contract"] != "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      coinValue = 0
      var ethCallJson = ({})
      var routing = ([])
      ethCallJson["function"] = "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)"
      ethCallJson["args"] = []
      // uint256 amountIn
      ethCallJson["args"].push(String(qmlApi.fixedPointToWei(amountIn, exchangeInfo["left"]["decimals"])))
      // uint256 amountOutMin
      ethCallJson["args"].push(qmlApi.floor(qmlApi.mul(qmlApi.fixedPointToWei(amountOut, exchangeInfo["right"]["decimals"]), desiredSlippage)))
      // address[] path
      ethCallJson["args"].push(exchangeInfo["routing"])
      // address to
      ethCallJson["args"].push(accountHeader.currentAddress)
      // uint256 deadline 60 minutes deadline
      ethCallJson["args"].push(String((+qmlApi.getCurrentUnixTime() + 3600) * 1000))
      ethCallJson["types"] = []
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("uint*")
      ethCallJson["types"].push("address[]")
      ethCallJson["types"].push("address")
      ethCallJson["types"].push("uint*")
      var ethCallString = JSON.stringify(ethCallJson)
      var ABI = qmlApi.buildCustomABI(ethCallString)
      txData = ABI
      return;
    }
  }

  function calculateTransactionCost(gasLimit, amountIn) {
    var transactionFee = qmlApi.floor(qmlApi.mul(gasLimit, (+gasPrice * 1000000000)))
    var WeiWAVAXBalance = qmlApi.floor(qmlApi.fixedPointToWei(accountHeader.coinRawBalance,18))
    if (+transactionFee > +WeiWAVAXBalance) {
      return false
    }

    // Edge case for WAVAX
    if (exchangeInfo["left"]["contract"] == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
      var totalCost = qmlApi.weiToFixedPoint(qmlApi.sum(transactionFee, qmlApi.fixedPointToWei(amountIn,18)),18)
      if (+totalCost > +accountHeader.coinRawBalance) {
        return false
      }
    } else { 
      if (+amountIn > +accountHeader.tokenList[exchangeInfo["left"]["contract"]]["rawBalance"]) {
        return false
      }
    }
    return true
  }
  

  // ======================================================================
  // HEADER
  // ======================================================================

  Column {
    id: exchangePanelHeaderColumn 
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
      id: exchangeHeaderText
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You will swap from <b>" + leftSymbol
      + "</b> to <b>" + rightSymbol + "</b>"
    }

    Row {
      id: exchangeLogos
      height: 64
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.margins: 20

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
          onClicked: { exchangeLeftAssetPopup.open() }
        }
      }

      Rectangle {
        id: swapOrderRectangle
        height: 64
        width: 80
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        radius: 5
        Image {
          id: swapOrderImage
          height: 48
          width: 48
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          fillMode: Image.PreserveAspectFit
          source: "qrc:/img/icons/arrow.png"
        }

        MouseArea {
          id: swapOrderMouseArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: (!loading)
          onEntered: swapOrderRectangle.color = "#1d1827"
          onExited: swapOrderRectangle.color = "transparent" 
          onClicked: { swapOrder() }
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
          onClicked: { exchangeRightAssetPopup.open() }
        }
      }
    }
    Text {
      id: assetBalance
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "Loading asset balance..."
    }
  }

  // ======================================================================
  // LOADING IMAGE
  // ======================================================================

  Image {
    id: exchangePanelLoadingPng
    anchors {
      top: exchangePanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: 0
      bottomMargin: 50
    }
    fillMode: Image.PreserveAspectFit
    source: "qrc:/img/icons/loading.png"
    RotationAnimator {
      target: exchangePanelLoadingPng
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
    id: exchangePanelApprovalColumn
    anchors {
      top: exchangePanelHeaderColumn.bottom
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
      id: exchangeApprovalText
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: "#FFFFFF"
      font.pixelSize: 14.0
      text: "You need to approve your <br>Account in order to swap <b>"
      + leftSymbol + "</b>."
      + "<br>This operation will have <br>a total gas cost of:<br><b>"
      + qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
      + " AVAX</b>"
    }

    AVMEButton {
      id: btnApprove
      width: parent.width
      enabled: (+accountHeader.coinRawBalance >=
        +qmlApi.weiToFixedPoint(qmlApi.floor(qmlApi.mul("70000", (gasPrice * 1000000000))),18)
      )
      anchors.horizontalCenter: parent.horizontalCenter
      text: (enabled) ? "Approve" : "Not enough funds"
      onClicked: {
        approveTx()
        if (calculateTransactionCost(70000, "0")) {
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
  // PAIR UNAVAILABLE
  // ======================================================================

  Column {
    id: exchangePanelUnavailablePair
    anchors {
      top: exchangePanelHeaderColumn.bottom
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
      id: exchangePanelUnavailablePairText
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
    id: exchangePanelDetailsColumn 
    anchors {
      top: exchangePanelHeaderColumn.bottom
      bottom: parent.bottom
      left: parent.left
      right: parent.right
      topMargin: -20
      bottomMargin: 20
      leftMargin: 40
      rightMargin: 40
    }
    spacing: 20

    AVMEInput {
      id: leftInput
      width: (parent.width * 0.8)
      label: leftSymbol + " Amount"
      validator: RegExpValidator { regExp: qmlApi.createRegExp("[0-9]{1,99}(?:\\.[0-9]{1," + leftDecimals + "})?") }
      placeholder: "Amount (e.g. 0.5)"
      onTextEdited: {
        rightInput.text = calculateExchangeAmountText(leftInput.text, true)
        swapImpact = +calculatePriceImpactText(leftInput.text)
      }
      AVMEButton {
        id: swapMaxBtn
        width: (parent.parent.width * 0.2) - 10
        anchors {
          left: parent.right
          leftMargin: 10
        }
        text: "Max"
        onClicked: { 
          // AVAX Edge Case
          if (leftContract == "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") {
            var totalFees = qmlApi.floor(qmlApi.mul(500000, (+gasPrice * 1000000000)))
            var maxWeiWAVAX = qmlApi.floor(qmlApi.sub(qmlApi.fixedPointToWei(accountHeader.coinRawBalance,18),totalFees))
            var maxWAVAX = qmlApi.weiToFixedPoint(maxWeiWAVAX, 18)
            if (+maxWAVAX > 0) {
              leftInput.text = maxWAVAX
            }
          } else {
            leftInput.text = accountHeader.tokenList[exchangeInfo["left"]["contract"]]["rawBalance"]
          }
          rightInput.text = calculateExchangeAmountText(leftInput.text, true)
          swapImpact = +calculatePriceImpactText(leftInput.text)
        }
      }
    }

    AVMEInput {
      id: rightInput
      width: parent.width
      label: rightSymbol + " Amount"
      validator: RegExpValidator { regExp: qmlApi.createRegExp("[0-9]{1,99}(?:\\.[0-9]{1," + rightDecimals + "})?") }
      placeholder: "Amount (e.g. 0.5)"
      onTextEdited: {
        leftInput.text = calculateExchangeAmountText(rightInput.text, false)
        swapImpact = +calculatePriceImpactText(leftInput.text)
      }
    }

    Text {
      id: swapImpactText
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: {
        if (swapImpact == 0.0) {
          color: "#FFFFFF"
        } else if (swapImpact > 0.0 && swapImpact <= 5.0) {
          color: "#44FF44"
        } else if (swapImpact > 5.0 && swapImpact <= 7.5) {
          color: "#FFFF44"
        } else if (swapImpact > 7.5 && swapImpact <= 10.0) {
          color: "#FF8844"
        } else if (swapImpact > 10.0) {
          color: "#FF4444"
        }
      }
      font.pixelSize: 14.0
      text: "Price impact: <b>" + swapImpact + "%</b>"
    }
    CheckBox {
      id: ignoreImpactCheck
      checked: false
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Allow high price impact swaps (>10%)"
      contentItem: Text {
        text: parent.text
        font.pixelSize: 14.0
        color: parent.checked ? "#FFFFFF" : "#888888"
        verticalAlignment: Text.AlignVCenter
        leftPadding: parent.indicator.width + parent.spacing
      }
      ToolTip {
        id: impactTooltip
        visible: parent.hovered
        delay: 500
        text: "Asset prices raise or lower based on the amounts you buy or sell."
        + "<br>Larger amounts have bigger impact on prices."
        + "<br>Swap is disabled by default at a 10% or greater price impact."
        + "<br>You can still allow it if you wish, although not recommended."
        contentItem: Text {
          font.pixelSize: 12.0
          color: "#FFFFFF"
          text: impactTooltip.text
        }
        background: Rectangle { color: "#1C2029" }
      }
    }
    AVMEButton { 
      id: btnSwap
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      visible: true
      enabled: ((rightInput.acceptableInput && (swapImpact <= 10.0 || ignoreImpactCheck.checked)) && +rightInput.text != 0)
      text: (swapImpact <= 10.0 || ignoreImpactCheck.checked) ? "Make Swap" : "Price impact too high"
      onClicked: {
        swapTx(leftInput.text, rightInput.text)
        if (calculateTransactionCost(500000, leftInput.text)) {
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