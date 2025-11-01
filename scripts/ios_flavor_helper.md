# iOS Flavor Support - Setup Guide

## Quick Solution: Use the Flutter Wrapper Script

Instead of running `flutter run --flavor staging`, use the wrapper script:

```bash
./scripts/flutter run --flavor staging
```

This script automatically:
- Detects if you're running on iOS
- Switches to the correct Firebase configuration
- Runs Flutter without the flavor flag (since iOS config is already switched)

## Manual Method

If you prefer to do it manually:

```bash
# Switch to staging
./ios/build-config.sh staging
flutter run

# Switch to production  
./ios/build-config.sh production
flutter run
```

## Setting Up Shell Alias (Recommended)

Add this to your `~/.zshrc` or `~/.bash_profile`:

```bash
# Flutter with iOS flavor support
alias flutter='f() {
    if [[ "$*" == *"--flavor"* ]] && [[ "$*" != *"-d"* ]] || [[ "$*" == *"-d"* ]] && [[ "$*" == *"ios"* ]] || [[ "$*" == *"-d"* ]] && [[ "$*" == *"iPhone"* ]]; then
        # Extract flavor
        FLAVOR_ARG=""
        for i in "$@"; do
            if [[ "$i" == "--flavor" ]]; then
                FLAVOR_ARG="next"
            elif [[ "$FLAVOR_ARG" == "next" ]]; then
                FLAVOR_ARG="$i"
                break
            fi
        done
        
        if [[ -n "$FLAVOR_ARG" ]] && [[ "$FLAVOR_ARG" != "next" ]]; then
            cd ios && ./build-config.sh "$FLAVOR_ARG" && cd ..
            # Remove --flavor flag for iOS
            NEW_ARGS=()
            SKIP=false
            for arg in "$@"; do
                if [[ "$SKIP" == true ]]; then
                    SKIP=false
                    continue
                fi
                if [[ "$arg" == "--flavor" ]]; then
                    SKIP=true
                    continue
                fi
                NEW_ARGS+=("$arg")
            done
            command flutter "${NEW_ARGS[@]}"
        else
            command flutter "$@"
        fi
    else
        command flutter "$@"
    fi
}; f'
```

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

After this, you can use:
```bash
flutter run --flavor staging   # Works automatically for iOS!
flutter run --flavor production
```

## Using the Script Directly

The simplest approach is to use the script:

```bash
# Make sure you're in the project root
./scripts/flutter run --flavor staging
```

This will automatically detect iOS and switch the configuration.

