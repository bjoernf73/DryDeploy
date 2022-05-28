## Proper submoduling
according to [this](https://stackoverflow.com/questions/19619747/git-submodule-update-remote-vs-git-pull) discussion. 

----
### Adding
To reference the `main` branch of a submodule: 
```sh
git submodule add -b main [URL to Git repo]
```

----
### Updating
```
git submodule update --remote --merge
```
Note: `git submodule update --remote` will only update the branch registered in the .gitmodule, and by default, you will end up with a detached HEAD, unless `--rebase` or `--merge` is specified or the key *submodule.$name.update* is set to *rebase*, *merge* or *none*. Well, it doesn't seem to be true, though. You'll end up with a detached head in any case it seems. 

----
### Init submodules
You forgot to clone with `--recurse`, so you need to init:
```
git submodule update --init --remote --merge
```

### Removing submodules

```powershell
$ToRemoves = @('windows-2019-core','windows-2019-desktop','windows-2022-core','windows-2022-desktop')
# The submodules are located in the BaseConfig folder at root
foreach ($ToRemove in $ToRemoves) {
    git submodule deinit -f BaseConfig/$ToRemove
    rmdir .git/modules/BaseConfig/$ToRemove -Recurse -Force
    git rm -f BaseConfig/$ToRemove
}
git add -A
git commit -am "removed old BaseConfigs"
git push
```