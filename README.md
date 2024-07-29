
# Install
```sh
fisher install soraxas/breeze-light
```

# Known bug
- If there are similar name files, the numeric number might not be correct. This is because the filename matching is very primitive and it currently only performs a glob match.
  - However, it has been improved to return a numeric that has the highest matched character count, which (likely) will always be the correct case.
