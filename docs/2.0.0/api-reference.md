# AVME Wallet - API Reference

## Signals

`void apiRequestAnswered(QString answer, QString requestID)`
Emitted when a request batch from the API is returned from the network.

`void tokenPriceHistoryAnswered(QString answer, QString requestID, int days)`
Emitted when the graph request for token price history is returned from the network.

## Request builders

`void doAPIRequests(QString requestID)`
Send every request under the specified ID to the network in a single connection.
Automatically clears the requests under the specified ID from the list when done.
Emits the `apiRequestAnswered()` signal.

`void clearAPIRequests(QString requestID)`
Manually clear the requests under the specified ID from the list if necessary.

`void buildGetBalanceReq(QString address, QString requestID)`
Build a request for getting the AVAX balance of a given address.

`void buildGetTokenBalanceReq(QString tokenContract, QString address, QString requestID)`
Build a request for getting the token balance of a given address.

`void buildGetTotalSupplyReq(QString pairAddress, QString requestID)`
Build a request for getting the total LP supply of a given pair address.

`void buildGetCurrentBlockNumberReq(QString requestID)`
Build a request for getting the current block number in the blockchain.

`void buildGetTxReceiptReq(QString txidHex, QString requestID)`
Build a request for getting the details of a transaction (e.g. block number, status, etc.)

`void buildGetEstimateGasLimitReq(QString jsonStr, QString requestID)`
Build a request for getting the estimated gas limit in the blockchain.
Requires a JSON string formatted like this:
```
{
  from: ADDRESS
  to: ADDRESS
  gas: HEX_INT
  gasPrice: HEX_INT
  value: HEX_INT
  data: ETH_CALL
}
```

`void buildARC20TokenExistsReq(QString address, QString requestID)`
Build a request for querying if an ARC20 token exists.

`void buildGetARC20TokenDataReq(QString address, QString requestID)`
Build a request for getting an ARC20 token's data.

`void buildGetAllowanceReq(QString receiver, QString owner, QString spender, QString requestID)`
Build a request for getting the allowance amount between `owner` and `spender` addresses in the given `receiver` address.

`void buildGetPairReq(QString assetAddress1, QString assetAddress2, QString requestID)`
Build a request for getting the pair address for two given assets (tokens).

`void buildGetReservesReq(QString pairAddress, QString requestID)`
Build a request for getting the reserves for the given pair address.

`void buildCustomEthCallReq(QString contract, QString ABI, QString requestID)`
Build a request for a custom `eth_call` request.
`ABI` should ideally be the output of `buildCustomABI()`.

## Helper functions

`QStringList parseHex(QString hexStr, QStringList types)`
Parse a given ABI hex string according to the values given.
Accepted values from the ABI are:
* uint
* bool
* address
**Examples:**
* `parseHex("0000000000000000000000000000000000000000000000000de0b6b3a7640000
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000001234567890abcdefedcb1234567890abcdedcbaf",
["uint", "bool", "address"])` -> `["1000000000000000000", "1", "1234567890abcdefedcb1234567890abcdedcbaf"]`

`QString getFirstFromPair(QString assetAddressA, QString assetAddressB)`
Returns the first (lower) address from the given two asset address.
The "lower" address would be the one with a lower hex value (e.g. "0xABCD" is lower than "0xABCE").

`void getTokenPriceHistory(QString address, int days, QString requestID)`
Build a request for getting the fiat price history of the last X days for a given ARC20 token.
Emits the `tokenPriceHistoryAnswered()` signal.

`QString buildCustomABI(QString input)`
Convert `input` to a custom ABI bytecode.
Returns the encoded ABI bytecode as a string, to be used in `buildCustomEthCallReq()`.

`QString weiToFixedPoint(QString amount, int decimals)`
Convert a full Wei value to a fixed point value, based on the asset's amount of decimals.
Returns a string with the converted value.
**Examples**:
* `weiToFixedPoint("5000000000000000000", 18)` -> `"0.5"`
* `weiToFixedPoint("250000000000", 9)` -> `"250"`

`QString fixedPointToWei(QString amount, int decimals)`
Convert a fixed point value to a full Wei value, based on the asset's amount of decimals.
Returns a string with the converted value.
**Examples**:
* `fixedPointToWei("0.5", 18)` -> `"5000000000000000000"`
* `fixedPointToWei("250", 9)` -> `"250000000000"`

`QString uintToHex(QString input, bool isPadded = true)`
`QString uintFromHex(QString hex)`
`QString addressToHex(QString input)`
`QString addressFromHex(QString hex)`
`QString bytesToHex(QString input, bool isUint)`
`QString bytesFromHex(QString hex)`
Convert from a given type to a 32-byte ABI hex value, or vice-versa.
Returns the encoded hex or value as a string.
* uintFrom/uintTo Work with `uint<M>`, `bytes` and `bool`
* uintFrom returns the hex with padding by default, pass "false" on isPadded to return the pure value
* addressFrom/addressTo are solely for addresses
* bytesFrom/bytesTo convert a string of characters from/to a byte array, and return the respective byte array with left-padding
* isUint tells whether to encode as a number (true) or as a literal/string (false)
TODO: examples and have a look again at all of this

`QString MAX_U256_VALUE()`
Return a string with the maximum 256-bit unsigned integer value.
Can be used for error handling.

`QString getCurrentUnixTime()`
Return the current UNIX timestamp (time since epoch) in seconds.

`void logToDebug(QString log)`
Writes the given string to the user's wallet `debug.log` file`.

`QString getRandomID()`
Generate a random 8-byte hex ID.

`QString sum(QString a, QString b)`
`QString sub(QString a, QString b)`
`QString mul(QString a, QString b)`
`QString div(QString a, QString b)`
`QString round(QString a)`
`QString floor(QString a)`
`QString ceil(QString a)`
Safe math functions for really big numbers. Use those to calculate asset values.
