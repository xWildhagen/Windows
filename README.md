# Windows

## Initial setup

### Installation

1. (Optional) Log in to account(s)
2. Windows update
3. Winget update

```
winget update --all
winget install git.git
git clone https://github.com/xWildhagen/Windows
```

4. Microsoft Store update
5. Driver update

## Stuff

### Pull changes from GitHub

```
git -C windows pull
git -C windows reset --hard
```

## Missing

### Settings

- System > Display > Night light
- System > Clipboard > Clipboard history across your devices
- Personalisation > Colours > Accent colour (#7A6D98)
- Accounts > Sign-in options
- Time & Language > Language & region
