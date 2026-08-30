#!/bin/sh

# Resolve paths relative to the script's location, not cwd
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CURSOR_DIR="$SCRIPT_DIR/linux"

# Function to show usage and available themes
show_usage() {
    echo "Usage: $0 <cursor-theme-name>"
    echo ""
    echo "Available cursor themes:"

    if [ -d "$CURSOR_DIR" ]; then
        found=0
        for theme_dir in "$CURSOR_DIR"/*/; do
            if [ -d "$theme_dir" ]; then
                theme_name=$(basename "$theme_dir")
                echo "  - $theme_name"
                found=1
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "  (no themes found in $CURSOR_DIR)"
        fi
    else
        echo "  (cursor directory not found: $CURSOR_DIR)"
    fi

    echo ""
    echo "Example: $0 black"
}

# Check if argument provided
if [ -z "$1" ]; then
    echo "Error: No cursor theme specified"
    echo ""
    show_usage
    exit 1
fi

THEME_NAME="$1"

# Validate the cursor theme exists
if [ ! -d "$CURSOR_DIR/$THEME_NAME" ]; then
    echo "Error: Cursor theme '$THEME_NAME' not found"
    echo ""
    show_usage
    exit 1
fi

echo "Installing cursor theme: $THEME_NAME"

# Copy cursor files to ~/.icons/
mkdir -p ~/.icons
cp -r "$CURSOR_DIR/$THEME_NAME" ~/.icons/
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy cursor files"
    exit 1
fi

echo "✓ Copied to ~/.icons/$THEME_NAME"

# Update ~/.Xresources (replace existing entries or add new ones)
if [ -f ~/.Xresources ]; then
    if grep -q "Xcursor.theme:" ~/.Xresources; then
        sed -i "s|Xcursor.theme:.*|Xcursor.theme: $THEME_NAME|" ~/.Xresources
        echo "✓ Updated Xcursor.theme in ~/.Xresources"
    else
        echo "Xcursor.theme: $THEME_NAME" >> ~/.Xresources
        echo "✓ Added Xcursor.theme to ~/.Xresources"
    fi

    if grep -q "Xcursor.size:" ~/.Xresources; then
        sed -i "s|Xcursor.size:.*|Xcursor.size:  20|" ~/.Xresources
        echo "✓ Updated Xcursor.size in ~/.Xresources"
    else
        echo "Xcursor.size:  20" >> ~/.Xresources
        echo "✓ Added Xcursor.size to ~/.Xresources"
    fi
else
    echo "Xcursor.theme: $THEME_NAME" > ~/.Xresources
    echo "Xcursor.size:  20" >> ~/.Xresources
    echo "✓ Created ~/.Xresources"
fi

# Reload Xresources
if command -v xrdb >/dev/null 2>&1; then
    xrdb -merge ~/.Xresources
    echo "✓ Reloaded Xresources"
fi

# Update GTK settings if config exists
for ver in 3.0 4.0; do
    GTK_DIR="$HOME/.config/gtk-$ver"
    GTK_FILE="$GTK_DIR/settings.ini"

    if [ -f "$GTK_FILE" ]; then
        if grep -q "gtk-cursor-theme-name=" "$GTK_FILE"; then
            sed -i "s|gtk-cursor-theme-name=.*|gtk-cursor-theme-name=$THEME_NAME|" "$GTK_FILE"
            echo "✓ Updated gtk-cursor-theme-name in GTK $ver"
        else
            sed -i "/^\[Settings\]/a gtk-cursor-theme-name=$THEME_NAME" "$GTK_FILE"
            echo "✓ Added gtk-cursor-theme-name to GTK $ver"
        fi

        if grep -q "gtk-cursor-theme-size=" "$GTK_FILE"; then
            sed -i "s|gtk-cursor-theme-size=.*|gtk-cursor-theme-size=20|" "$GTK_FILE"
            echo "✓ Updated gtk-cursor-theme-size in GTK $ver"
        else
            sed -i "/^\[Settings\]/a gtk-cursor-theme-size=20" "$GTK_FILE"
            echo "✓ Added gtk-cursor-theme-size to GTK $ver"
        fi
    fi
done

# Update default cursor theme
mkdir -p ~/.icons/default
cat > ~/.icons/default/index.theme << THEEOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=$THEME_NAME
THEEOF
echo "✓ Set default cursor theme"

# Set environment variables (update the right shell/session config)
# Priority: .xprofile (X11 session) > .profile (sh/bash login) > .zprofile (zsh login) > .bashrc > .zshrc
ENV_FILE=""
for candidate in .xprofile .profile .zprofile .bashrc .zshrc; do
    if [ -f "$HOME/$candidate" ]; then
        ENV_FILE="$HOME/$candidate"
        break
    fi
done

# If none exist, create .profile (safe fallback for sh/bash login shells)
if [ -z "$ENV_FILE" ]; then
    ENV_FILE="$HOME/.profile"
    echo "#!/bin/sh" > "$ENV_FILE"
    echo "✓ Created ~/.profile (no shell config found)"
fi

if grep -q "XCURSOR_THEME=$THEME_NAME" "$ENV_FILE"; then
    echo "✓ Environment variables already set in $ENV_FILE"
else
    if grep -q "export XCURSOR_THEME=" "$ENV_FILE"; then
        sed -i "s|export XCURSOR_THEME=.*|export XCURSOR_THEME=$THEME_NAME|" "$ENV_FILE"
        echo "✓ Updated XCURSOR_THEME in $ENV_FILE"
    else
        printf '\n# Cursor theme\nexport XCURSOR_THEME=%s\nexport XCURSOR_SIZE=20\n' "$THEME_NAME" >> "$ENV_FILE"
        echo "✓ Added cursor environment variables to $ENV_FILE"
    fi

    if grep -q "export XCURSOR_SIZE=" "$ENV_FILE"; then
        sed -i "s|export XCURSOR_SIZE=.*|export XCURSOR_SIZE=20|" "$ENV_FILE"
    fi
fi

echo ""
echo "Installation complete!"
echo "Note: Restart your window manager or log out/in for all changes to take effect."
