# AVME Wallet - Submit or update your DApp

Once your DApp is done and tested and you're ready to submit/update, do the following:

1. Fork this repo.
2. Put your DApp in a folder inside `apps/xxxxx`, according to the [chain ID](https://chainlist.org) of your DApp. Supported IDs are:

* **43114** - Avalanche Mainnet

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
