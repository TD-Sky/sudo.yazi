# sudo.yazi

Call `sudo` in yazi.

## Functions

- [x] copy files
- [x] move files
- [ ] trash files (using [conceal](https://github.com/TD-Sky/conceal))
- [ ] remove files
- [x] create absolute-path symbolic links
- [ ] create relative-path symbolic links
- [ ] touch new file
- [ ] make new directory

## Usage

Here are my own keymap for reference only:

```toml
# sudo cp/mv
[[manager.keymap]]
on = ["<C-p>"]
exec = "plugin sudo --args='paste'"
desc = "sudo paste"

# sudo ln -s (absolute-path)
[[manager.keymap]]
on = ["<C-l>"]
exec = "plugin sudo --args='link'"
desc = "sudo link"
```
