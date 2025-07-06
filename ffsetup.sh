#!/bin/sh

# Firefox Setup Script

die() { # Print error and exit
    printf "%s\n" "$1" >&2
    exit 1
}

which firefox >/dev/null 2>&1 || { die "Firefox is not installed!" }

echo "A Firefox setup script"
printf "\nStarting Firefox...\n"

# Run Firefox headless to generate a profile
firefox --headless >/dev/null 2>&1 &
sleep 3
pkill "firefox"

# Grab profile
profile="$HOME/.mozilla/firefox/$(grep "Default=.*\.default-release" $HOME/.mozilla/firefox/profiles.ini | sed "s/Default=//")"
[ ! -d "$profile" ] && die "Could not create/fetch Firefox profile"

# Install Betterfox user.js
echo "Installing Betterfox user.js..."
curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$profile/user.js"

# Create temp directory
tempff="$(mktemp -d)"
trap "rm -rf $tempff" HUP INT QUIT TERM PWR EXIT

# Install extensions
echo "Installing browser extensions..."
extensions="ublock-origin decentraleyes clearurls noscript"
IFS=' '
mkdir "$profile/extensions/"
for x in $extensions; do
    extensionurl="$(curl -sL "https://addons.mozilla.org/en-US/firefox/addon/${x}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
    file="${extensionurl##*/}"
    curl -sL "$extensionurl" > "$tempff/$file"
    id="$(unzip -p "$tempff/$file" manifest.json | grep "\"id\"")"
    id="${id%\"*}"
    id="${id##*\"}"
    mv "$tempff/$file" "$profile/extensions/$id.xpi" || die "Could not install an extension correctly"
done

# Enable extensions
echo "Enabling extensions..."

# Generate extensions.json
firefox --headless >/dev/null 2>&1 &
sleep 10
pkill "firefox"

# Edit prefs to enable extensions
sed -i 's/\(seen":\)false/\1true/g; s/\(active":\)false\(,"userDisabled":\)true/\1true\2false/g' "$profile/extensions.json"
sed -i 's/\(extensions\.pendingOperations", \)false/\1true/' "$profile/prefs.js"

echo "All done!"
