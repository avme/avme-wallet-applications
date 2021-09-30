# AVME Wallet - Anatomy of a native DApp

Native DApps for the AVME Wallet are built using Qt's [QML](https://doc.qt.io/qt-5/qmlapplications.html) language.

There's no hard limit on how many files you can have (aside from common sense of course), but at the *very least* your DApp needs ***three*** files, *all of them located at the root folder*:

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
