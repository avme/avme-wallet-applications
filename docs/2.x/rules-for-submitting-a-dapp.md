# AVME Wallet - Rules for submitting a DApp

Before submitting your DApp, check if all of the following apply:

1. Your DApp has all three required files in the root folder (**main.qml**, **icon.png** and **files.json**).
2. Your DApp is entirely contained within its folder (this means not locally accessing any files beyond/outside the DApp's root folder).
3. Your DApp is only using select permitted components from the wallet:
  - Functions from [`QmlApi`](https://github.com/avme/avme-wallet/blob/main/src/qmlwrap/QmlApi.h)
  - Components from [`qml/components`](https://github.com/avme/avme-wallet/tree/main/src/qml/components):
    - `AVMEButton`
    - `AVMEInput`
    - `AVMEPanel`
    - `AVMEPopup`
    - `AVMEAsyncImage`
    - `AVMECheckbox`
    - `AVMESpinbox`
    - `AVMECombobox`
    - `AVMEAssetCombobox` (contains the user's assets - AVAX + tokens)
  - Components from [`qml/popups`](https://github.com/avme/avme-wallet/tree/main/src/qml/popups):
    - `AVMEPopupInfo`
    - `AVMEPopupYesNo`
    - `AVMEPopupAssetSelect`
    - `AVMEPopupConfirmTx` and `AVMEPopupTxProgress` (used together)
  - Data from inside the `AVMEAccountHeader` component, such as:
    - `accountHeader.currentAddress` (the user's currently selected address)
4. Any and all external resources (e.g. images, helper code, etc.) used in your DApp are not malicious and/or harmful.
5. Your DApp is not using any of the following JS functions:
  - eval()

The pull request won't be accepted until all of the conditions are met, but will be kept open for you to fix them.

Keep in mind those rules are subject to change at any time, depending on the situation. Always check the most recent commit on the `main` branch to make sure you're up to date.
