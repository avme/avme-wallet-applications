# AVME Wallet - How the API works

Native DApps in the AVME Wallet use a built-in API for network requests. This API is internally called `QmlApi`, accessed through a QML object called `qmlApi` (with a lowercase "q"), and is bound to the wallet's version, being updated along as required.

## How requests work

Requests on the `QmlApi` class are first *built*, then *made*.

### Building requests

First, call one (or more) of the [request builder](api-reference.md#request-builders) functions, according to what you want to do. Those functions will build their respective requests and queue them into an internal list, *at the order you called them*.

Every request builder function requires a `requestID`, which is an identifier string for grouping several requests into one batch. You can put anything here, *as long as the identifier is unique*.

We recommend using discernable names for IDs (like you do variables), but alternatively you can call the API helper function `getRandomID()` and use that as in ID instead. Just store it somewhere in a variable if you do so, as you'll need it later.

Let's suppose you want to query a given token's balance from five different user addresses. Just for explanation purposes, the token address would be "0x0", and the user addresses are "0x1" to "0x5". Building the requests in order would look like this:

```
qmlApi.buildGetTokenBalanceReq("0x0", "0x1", "queryID1")
qmlApi.buildGetTokenBalanceReq("0x0", "0x2", "queryID1")
qmlApi.buildGetTokenBalanceReq("0x0", "0x3", "queryID1")
qmlApi.buildGetTokenBalanceReq("0x0", "0x4", "queryID1")
qmlApi.buildGetTokenBalanceReq("0x0", "0x5", "queryID1")
```

*Remember the order*. If you want "0x3" to be queried first, or "0x1" to be called last, for example, then change your call order accordingly. This is important because *API answers can return unordered*, and to find out which answer is from which request, you'll have to filter them later.

You can use [helper functions](api-reference.md#helper-functions) to aid you with stuff like really big number mathematics and ABI bytecode conversions.

### Making requests

Once your requests are built the way you want them, simply call the `doApiRequests()` function, giving it the unique ID you created. The API will then send all of the requests you made under that ID to the network in a single batch.

Using the example above, you would call `qmlApi.doAPIRequests("queryID1")`. *Make sure to remember that ID*, as it will be necessary to retrieve the data.

All requests with the given ID are automatically cleared from the list once the function is done running. If you want to be sure anyway just in case, you can issue a manual clear with `qmlApi.clearAPIRequests("queryID1")` before building. This is not required but it may bring peace of mind.

## Receiving request data

When the request batch returns, a [signal](api-reference.md#signals) called `apiRequestAnswered()` is emitted with the data from all requests made under the previously specified ID.

To receive said data when it arrives, use QML's [Connections](https://doc.qt.io/qt-5/qml-qtqml-connections.html) object to filter the IDs you've used and get the request data for them.

The "answer" parameter is meant to be passed through Javascript's `JSON.parse()`, so you can iterate through each request's answer with a loop, and use the API helper function `parseHex()` to retrieve the values you want.

Using the example above, it would be like this:

```
Connections {
  function onApiRequestAnswered(answer, requestID) {
    if (requestID == "queryID1") {
      var respArr = JSON.parse(answer)
      var balances = []
      for (var answerItem in respArr) {
        if (respArr[answerItem]["id"] == 1) {
          // Balance from "0x1"
          balances[0] = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
        }
        if (respArr[answerItem]["id"] == 2) {
          // Balance from "0x2"
          balances[1] = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
        }
        if (respArr[answerItem]["id"] == 3) {
          // Balance from "0x3"
          balances[2] = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
        }
        if (respArr[answerItem]["id"] == 4) {
          // Balance from "0x4"
          balances[3] = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
        }
        if (respArr[answerItem]["id"] == 5) {
          // Balance from "0x5"
          balances[4] = qmlApi.parseHex(respArr[answerItem].result, ["uint"])
        }
      }
    } else if (requestID == "queryID2") {
      // ...
    }
  }
}
```

*Remember the API request answers can return unordered*. This is why those "if"s are there - if you called the "0x3" balance request first, then *that* is going to return with an id of "1".
