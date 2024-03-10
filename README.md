# sudo.yazi

Call `sudo` in yazi.

## Functions

- [x] copy files
- [x] move files
- [ ] trash files (using [conceal](https://github.com/TD-Sky/conceal))
- [ ] remove files
- [x] create absolute-path symbolic links
- [ ] create relative-path symbolic links
- [x] touch new file
- [x] make new directory

## Usage

Here are my own keymap for reference only:

```toml
# sudo cp/mv
[[manager.keymap]]
on = ["R", "p"]
exec = "plugin sudo --args='paste'"
desc = "sudo paste"

# sudo ln -s (absolute-path)
[[manager.keymap]]
on = ["R", "l"]
exec = "plugin sudo --args='link'"
desc = "sudo link"

# sudo touch/mkdir
[[manager.keymap]]
on = ["R", "a"]
exec = "plugin sudo --args='create'"
desc = "sudo create"
```
