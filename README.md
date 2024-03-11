# sudo.yazi

Call `sudo` in yazi.

## Functions

- [x] copy files
- [x] move files
- [x] trash files (using [conceal](https://github.com/TD-Sky/conceal))
- [x] remove files
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
run = "plugin sudo --args='paste'"
desc = "sudo paste"

# sudo ln -s (absolute-path)
[[manager.keymap]]
on = ["R", "l"]
run = "plugin sudo --args='link'"
desc = "sudo link"

# sudo touch/mkdir
[[manager.keymap]]
on = ["R", "a"]
run = "plugin sudo --args='create'"
desc = "sudo create"

# sudo trash
[[manager.keymap]]
on = ["R", "d"]
run = "plugin sudo --args='remove'"
desc = "sudo trash"

# sudo delete
[[manager.keymap]]
on = ["R", "D"]
run = "plugin sudo --args='remove -P'"
desc = "sudo delete"
```
