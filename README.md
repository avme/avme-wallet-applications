# avme-wallet-applications

Official repository with DApps for the AVME Wallet.

## Anatomy of a DApp

DApps for the AVME Wallet are built using Qt's [QML](https://doc.qt.io/qt-5/qmlapplications.html) language. There's no hard limit on how many files you can have (aside from common sense of course), but at the *very least* your DApp needs three files, all of them located at the root folder:

* **main.qml** - the entry point for your DApp
* **icon.png** - a 256x256 icon for displaying your DApp inside the wallet
* **files.json** - a list with all the extra local files used in your DApp (not counting those other two), like so:

```
{
  "files": [
    "file1.qml",
    "file2.qml",
    "img/img1.png",
    "img/icons/okIcon.png",
    ...
  ]
}
```

In theory, if it's simple enough, you can make your whole DApp inside the **main.qml** file, but you'll still need to have the **files.json** file even if you don't have any extra local files (whether you don't need them or if you're just linking to external resources). If that's the case then just make an empty list, like `{ "files": [] }`.

You're free to organize your DApp as you see fit (folder structure, code division, etc.), **as long as those three files exist and are located at the root folder of your DApp**.

## How to test your DApp

You can test your DApp locally in the AVME Wallet (starting from v2.0.0) by doing the following steps:

1. Go to the Settings screen (the little cog on the bottom left).
2. Check the "Developer Mode" setting. This will enable an extra option in the Applications screen.
3. Go to the Applications screen and click on "Open Local App".
4. Select your DApp's root folder and confirm.

You only need the **main.qml** file for testing locally. The other two files (**icon.png** and **files.json**) are only required when submitting your DApp.

## How to submit/update your DApp

Once your DApp is done and tested and you're ready to submit/update, do the following:

1. Fork this repo.

2. Put your DApp in a folder inside `apps/xxxxx`, according to the chain ID of your DApp. Supported IDs are:

* **41113** - Avalanche DApp

3. Add an entry to `applist.json` (if it isn't there yet) and replace the information accordingly, like so:

```
{
  "apps": [
    {
      "chainId": xxxxx,
      "folder": "Your-DApp-Folder-Name",
      "name": "Your-DApp-Name",
      "major": X,
      "minor": Y,
      "patch": Z
    },
    ...
  ]
}
```

4. Make a pull request with your changes for approval.

## Rules for submitting a DApp

Before submitting your pull request, check if all of the following apply:

1. Your DApp has all three required files in the root folder (**main.qml**, **icon.png** and **files.json**).
2. Your DApp is entirely contained within its folder (this means not locally accessing any files outside root, e.g. `../`).
3. Your DApp is only using select permitted components from the wallet:
  - Functions from [`QmlApi`](https://github.com/avme/avme-wallet/blob/main/src/qmlwrap/QmlApi.h)
  - Components from [`qml/components`](https://github.com/avme/avme-wallet/tree/main/src/qml/components):
    - `AVMEButton`
    - `AVMEInput`
    - `AVMEPanel`
    - `AVMEPopup`
    - `AVMEAsyncImage`
  - Components from [`qml/popups`](https://github.com/avme/avme-wallet/tree/main/src/qml/popups):
    - `AVMEPopupInfo`
    - `AVMEPopupYesNo`
    - `AVMEPopupAssetSelect`
    - `AVMEPopupConfirmTx` and `AVMEPopupTxProgress` (used together)
4. Any and all external resources (e.g. images, helper code, etc.) used in your DApp are not malicious and/or harmful.
5. Your DApp is not using any of the following JS functions:
  - eval()

The pull request won't be accepted until all of the conditions are met, but will be kept open for you to fix them.

Keep in mind those rules are subject to change at any time, depending on the situation. Always check the most recent commit on the `main` branch to make sure.
