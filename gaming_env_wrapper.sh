#!/bin/sh
#
# gaming_env_wrapper.sh Proton/DXVK/FSR4 env wrapper
# Copyright (C) 2025 furbakka
GENVW_VERSION="0.4.0"
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# Wrapper to control Proton / DXVK / FSR4 / CachyOS options
# via short toggles in Steam launch options.
#
# Example Steam launch options:
#   HDR=1 FSR4=4.0.2 LSC=1 NVMD=1 NTS=1 CPU=16 GP=1 GM=1 \
#   /home/youruser/bin/gaming_env_wrapper.sh %command%

# Animated gENVW banner (for interactive wizard only)
show_genvw_banner() {
  # Try to get terminal width, fall back to 80
  cols=$(tput cols 2>/dev/null || echo 80)

  # Approx width of the banner text (characters)
  BANNER_WIDTH=58

  if [ "$cols" -gt "$BANNER_WIDTH" ]; then
    indent=$(( (cols - BANNER_WIDTH) / 2 ))
  else
    indent=0
  fi

  # Left padding for centering
  pad=$(printf '%*s' "$indent" "")

  # Print banner line by line, centered
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Default: CachyOS cyan
    color="$CYAN"

    # Special color for "by furbakka" line (orange-ish = yellow)
    case "$line" in
      *"by furbakka"*)
        color="$YELLOW"
        ;;
    esac

    printf '%s%s%s%s\n' "$pad" "$color" "$line" "$RESET"
    sleep 0.25
  done <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                          gENVW                          ║
║          Proton / DXVK / FSR4 / MangoHUD helper         ║
║                           by furbakka                   ║
╚══════════════════════════════════════════════════════════╝
EOF

  printf '\n'

  # Keep it on screen – cyan bold prompt, centered with same padding
  printf '%s%sPress Enter to start gENVW...%s' "$pad" "$BOLD$CYAN" "$RESET"
  # Try /dev/tty first, fall back to normal stdin
  if ! read dummy </dev/tty 2>/dev/null; then
    read dummy
  fi
  echo
  echo
}

#####################
# Colors (only if stdout is a TTY)
#####################
if [ -t 1 ] && [ -z "${GENVW_NO_COLOR:-}" ]; then
    BOLD=$(printf '\033[1m')
    DIM=$(printf '\033[2m')
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    MAGENTA=$(printf '\033[35m')
    CYAN=$(printf '\033[36m')
    RESET=$(printf '\033[0m')
else
    BOLD=''
    DIM=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    RESET=''
fi

#####################
# RDNA generation detection helper (best-effort)
#####################
detect_rdna_gen() {

    if ! command -v lspci >/dev/null 2>&1; then
        echo 0
        return
    fi

    line=$(lspci -nn | grep -Ei 'VGA|Display' | grep -i 'AMD' | head -n1)
    gpu="$line"

    [ -z "$gpu" ] && { echo 0; return; }

    # RDNA2 – RX 6xxx family
    echo "$gpu" | grep -qiE 'RX[[:space:]]6[0-9]{2}|6600|6650|6700|6750|6800|6900' && { echo 2; return; }

    # RDNA3 – RX 7xxx family
    echo "$gpu" | grep -qiE 'RX[[:space:]]7[0-9]{2}|7600|7700|7800|7900' && { echo 3; return; }

    # RDNA4 – assuming RX 9xxx family (e.g. 9060, 9070, 9080, 9090)
    echo "$gpu" | grep -qiE 'RX[[:space:]]9[0-9]{2}|9060|9070|9080|9090' && { echo 4; return; }

    echo 0
}

show_help() {
    cat <<EOF
gENVW (gaming_env_wrapper.sh) - Proton / DXVK / FSR4 / MangoHUD wrapper

Usage:
  gaming_env_wrapper.sh [ENV_TOGGLES...] <command> [args...]
  HDR=1 FSR4=4.0.2 LSC=1 NVMD=1 NTS=1 CPU=16 GP=1 GM=1 \\
    gaming_env_wrapper.sh %command%

Interactive mode:
  Run gaming_env_wrapper.sh with no arguments in a terminal to start
  an interactive wizard that asks about HDR, FSR4, etc.
  It then prints a ready-to-paste Steam launch line.

Toggles (set as environment before the script):
  HDR=0|1        Wayland HDR path (PROTON_ENABLE_WAYLAND, PROTON_ENABLE_HDR, DXVK_HDR, ENABLE_HDR_WSI)
  FSR4=0|1|ver   RDNA3 FSR4 (PROTON_FSR4_RDNA3_UPGRADE=1 or =<ver>, allowed custom: 4.0.0, 4.0.1, 4.0.2)
  FSR4R4=0|1|ver RDNA4/global FSR4 (PROTON_FSR4_UPGRADE=1 or =<ver>)
  FSR4SHOW=0|1   FSR4 on-screen indicator (PROTON_FSR4_INDICATOR=1)
  FFSR=0|1-5     Wine fullscreen FSR scaler (SDR only)
  DEBUG=0|1      Proton/DXVK/VKD3D logging + FSR indicator
  ASYNC=0|1      DXVK async (singleplayer only)
  LSC=0|1        Local shader cache (PROTON_LOCAL_SHADER_CACHE=1)
  NVMD=0|1       No WM decoration (borderless, PROTON_NO_WM_DECORATION=1)
  NTS=0|1        Use NTSYNC backend (PROTON_USE_NTSYNC=1)
  CPU=0|N        Fake CPU topology, game sees N logical CPUs
  GP=0|1         Wrap command in game-performance (CachyOS)
  GM=0|1         Wrap command in gamemoderun (Feral GameMode)

Other:
  GENVW_NO_BANNER=1   Disable the animated banner in interactive mode.

Project page:
  https://github.com/furbakka/gaming-env-wrapper
EOF
}

show_version() {
    printf 'gENVW (gaming_env_wrapper.sh) version %s\n' "$GENVW_VERSION"
}

# Help flag: print usage and exit
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Version flag: print version and exit
if [ "$1" = "-V" ] || [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    show_version
    exit 0
fi

#####################
# INTERACTIVE MODE
#####################
if [ "$#" -eq 0 ] && [ -t 0 ]; then
    # Show animated banner only in interactive mode & real terminal
    if [ -t 1 ] && [ -z "${GENVW_NO_BANNER:-}" ]; then
        show_genvw_banner
    fi

    printf "%s\n" "${BOLD}${CYAN}=== gaming_env_wrapper.sh – Interactive Steam launch options generator ===${RESET}"
    echo
    echo "Answer the questions below. At the end you'll get a line you can paste"
    echo "into Steam's Launch options for your game."
    echo

    LAUNCH_ENV=""
    HDR_ENABLED=0
    FSR4_RDNA3_USED=0

    # Helper to trim simple whitespace
    trim() {
        printf '%s' "$1" | awk '{$1=$1;print}'
    }

    # Strict yes/no helper
    ask_yes_no() {
        while :; do
            printf "%s" "$1"
            read ans
            ans=$(trim "$ans")
            case "$ans" in
                y|Y) return 0 ;;
                n|N) return 1 ;;
                *)
                    printf "%s\n\n" "${RED}Please answer 'y' or 'n'.${RESET}"
                    ;;
            esac
        done
    }

    # Detect RDNA generation
    RDNA_GEN=$(detect_rdna_gen)
    case "$RDNA_GEN" in
        2) printf "%s\n\n" "${GREEN}Detected GPU architecture: RDNA2${RESET}" ;;
        3) printf "%s\n\n" "${GREEN}Detected GPU architecture: RDNA3${RESET}" ;;
        4) printf "%s\n\n" "${GREEN}Detected GPU architecture: RDNA4${RESET}" ;;
        0) printf "%s\n\n" "${YELLOW}Could not detect RDNA generation automatically (RDNA_GEN=0).${RESET}" ;;
    esac

    # Detect maximum logical CPUs
    MAX_CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
    case "$MAX_CORES" in
        ''|*[!0-9]*)
            MAX_CORES=0
            ;;
    esac

    ########################
    # HDR (strict y/n)
    ########################
    echo "${BOLD}HDR:${RESET} Enable Wayland HDR path (PROTON_ENABLE_WAYLAND, PROTON_ENABLE_HDR, DXVK_HDR, ENABLE_HDR_WSI)."
    if ask_yes_no "${YELLOW}Enable HDR? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV HDR=1"
        HDR_ENABLED=1
    fi
    echo

    ###########################################################
    # FSR4 menus – behavior depends on RDNA generation
    ###########################################################
    case "$RDNA_GEN" in
        2)
            printf "%s\n\n" "${CYAN}RDNA2 detected → skipping FSR4 menus (FSR4 is aimed at RDNA3/RDNA4).${RESET}"
            ;;
        3)
            printf "%s\n\n" "${CYAN}RDNA3 detected → using RDNA3 FSR4 menu.${RESET}"

            while :; do
                echo "${BOLD}FSR4 (RDNA3):${RESET} Upscaling via FSR4 on AMD RDNA3."
                echo "  0 = off"
                echo "  1 = generic RDNA3 mode (PROTON_FSR4_RDNA3_UPGRADE=1)"
                echo "  2 = FSR4 4.0.2 (recommended default for RDNA3 right now)"
                echo "  3 = custom version (allowed: 4.0.0, 4.0.1, 4.0.2)"
                printf "%s" "${YELLOW}FSR4 choice for RDNA3 [0]: ${RESET}"
                read choice
                choice=$(trim "$choice")
                [ -z "$choice" ] && choice="0"

                case "$choice" in
                    0)
                        echo
                        break
                        ;;
                    1)
                        LAUNCH_ENV="$LAUNCH_ENV FSR4=1"
                        FSR4_RDNA3_USED=1
                        echo
                        break
                        ;;
                    2)
                        LAUNCH_ENV="$LAUNCH_ENV FSR4=4.0.2"
                        FSR4_RDNA3_USED=1
                        echo
                        break
                        ;;
                    3)
                        while :; do
                            echo "Enter FSR4 version string for RDNA3."
                            echo "Allowed versions: 4.0.0, 4.0.1, 4.0.2"
                            printf "%s" "${YELLOW}FSR4 version (RDNA3): ${RESET}"
                            read ver
                            ver=$(trim "$ver")
                            case "$ver" in
                                "")
                                    printf "%s\n\n" "${YELLOW}Empty version, skipping custom FSR4 for RDNA3.${RESET}"
                                    break
                                    ;;
                                4.0.0|4.0.1|4.0.2)
                                    LAUNCH_ENV="$LAUNCH_ENV FSR4=$ver"
                                    FSR4_RDNA3_USED=1
                                    echo
                                    break
                                    ;;
                                *)
                                    printf "%s\n\n" "${RED}Invalid version. Allowed values: 4.0.0, 4.0.1, 4.0.2.${RESET}"
                                    ;;
                            esac
                        done
                        break
                        ;;
                    *)
                        printf "%s\n\n" "${RED}Please enter 0, 1, 2 or 3.${RESET}"
                        ;;
                esac
            done
            ;;
        4)
            printf "%s\n\n" "${CYAN}RDNA4 detected → using RDNA4 FSR4R4 menu.${RESET}"

            while :; do
                echo "${BOLD}FSR4R4 (RDNA4):${RESET} FSR4 on RDNA4/global path."
                echo "  0 = off"
                echo "  1 = use Proton's default/latest for RDNA4 (PROTON_FSR4_UPGRADE=1)"
                echo "  2 = custom version (digits and dots only, e.g. 4.0.2)"
                printf "%s" "${YELLOW}FSR4R4 choice for RDNA4 [0]: ${RESET}"
                read choice
                choice=$(trim "$choice")
                [ -z "$choice" ] && choice="0"

                case "$choice" in
                    0)
                        echo
                        break
                        ;;
                    1)
                        LAUNCH_ENV="$LAUNCH_ENV FSR4R4=1"
                        echo
                        break
                        ;;
                    2)
                        while :; do
                            echo "Enter FSR4 version string for RDNA4 (e.g. 4.0.2). Digits and dots only."
                            printf "%s" "${YELLOW}FSR4R4 version: ${RESET}"
                            read ver
                            ver=$(trim "$ver")
                            case "$ver" in
                                "")
                                    printf "%s\n\n" "${YELLOW}Empty version, skipping FSR4R4.${RESET}"
                                    break
                                    ;;
                                *[!0-9.]*)
                                    printf "%s\n\n" "${RED}Invalid version (letters not allowed). Use only digits and dots.${RESET}"
                                    continue
                                    ;;
                                *)
                                    LAUNCH_ENV="$LAUNCH_ENV FSR4R4=$ver"
                                    echo
                                    break
                                    ;;
                            esac
                        done
                        break
                        ;;
                    *)
                        printf "%s\n\n" "${RED}Please enter 0, 1 or 2.${RESET}"
                        ;;
                esac
            done
            ;;
        *)
            printf "%s\n\n" "${YELLOW}RDNA generation unknown → showing both RDNA3 and RDNA4 FSR4 menus.${RESET}"

            # RDNA3 FSR4
            while :; do
                echo "${BOLD}FSR4 (RDNA3):${RESET} Upscaling via FSR4 on AMD RDNA3."
                echo "  0 = off"
                echo "  1 = generic RDNA3 mode (PROTON_FSR4_RDNA3_UPGRADE=1)"
                echo "  2 = FSR4 4.0.2 (recommended default for RDNA3 right now)"
                echo "  3 = custom version (allowed: 4.0.0, 4.0.1, 4.0.2)"
                printf "%s" "${YELLOW}FSR4 choice for RDNA3 [0]: ${RESET}"
                read choice
                choice=$(trim "$choice")
                [ -z "$choice" ] && choice="0"

                case "$choice" in
                    0)
                        echo
                        break
                        ;;
                    1)
                        LAUNCH_ENV="$LAUNCH_ENV FSR4=1"
                        FSR4_RDNA3_USED=1
                        echo
                        break
                        ;;
                    2)
                        LAUNCH_ENV="$LAUNCH_ENV FSR4=4.0.2"
                        FSR4_RDNA3_USED=1
                        echo
                        break
                        ;;
                    3)
                        while :; do
                            echo "Enter FSR4 version string for RDNA3."
                            echo "Allowed versions: 4.0.0, 4.0.1, 4.0.2"
                            printf "%s" "${YELLOW}FSR4 version (RDNA3): ${RESET}"
                            read ver
                            ver=$(trim "$ver")
                            case "$ver" in
                                "")
                                    printf "%s\n\n" "${YELLOW}Empty version, skipping custom FSR4 for RDNA3.${RESET}"
                                    break
                                    ;;
                                4.0.0|4.0.1|4.0.2)
                                    LAUNCH_ENV="$LAUNCH_ENV FSR4=$ver"
                                    FSR4_RDNA3_USED=1
                                    echo
                                    break
                                    ;;
                                *)
                                    printf "%s\n\n" "${RED}Invalid version. Allowed values: 4.0.0, 4.0.1, 4.0.2.${RESET}"
                                    ;;
                            esac
                        done
                        break
                        ;;
                    *)
                        printf "%s\n\n" "${RED}Please enter 0, 1, 2 or 3.${RESET}"
                        ;;
                esac
            done

            # RDNA4 FSR4R4 – only if RDNA3 FSR not selected
            if [ "$FSR4_RDNA3_USED" -eq 0 ]; then
                while :; do
                    echo "${BOLD}FSR4R4 (RDNA4):${RESET} FSR4 on RDNA4/global path."
                    echo "  0 = off"
                    echo "  1 = use Proton's default/latest for RDNA4 (PROTON_FSR4_UPGRADE=1)"
                    echo "  2 = custom version (digits and dots only, e.g. 4.0.2)"
                    printf "%s" "${YELLOW}FSR4R4 choice for RDNA4 [0]: ${RESET}"
                    read choice
                    choice=$(trim "$choice")
                    [ -z "$choice" ] && choice="0"

                    case "$choice" in
                        0)
                            echo
                            break
                            ;;
                        1)
                            LAUNCH_ENV="$LAUNCH_ENV FSR4R4=1"
                            echo
                            break
                            ;;
                        2)
                            while :; do
                                echo "Enter FSR4 version string for RDNA4 (e.g. 4.0.2). Digits and dots only."
                                printf "%s" "${YELLOW}FSR4R4 version: ${RESET}"
                                read ver
                                ver=$(trim "$ver")
                                case "$ver" in
                                    "")
                                        printf "%s\n\n" "${YELLOW}Empty version, skipping FSR4R4.${RESET}"
                                        break
                                        ;;
                                    *[!0-9.]*)
                                        printf "%s\n\n" "${RED}Invalid version (letters not allowed). Use only digits and dots.${RESET}"
                                        continue
                                        ;;
                                    *)
                                        LAUNCH_ENV="$LAUNCH_ENV FSR4R4=$ver"
                                        echo
                                        break
                                        ;;
                                esac
                            done
                            break
                            ;;
                        *)
                            printf "%s\n\n" "${RED}Please enter 0, 1 or 2.${RESET}"
                            ;;
                    esac
                done
            else
                printf "%s\n\n" "${CYAN}FSR4 for RDNA3 is enabled → skipping RDNA4 (FSR4R4) question.${RESET}"
            fi
            ;;
    esac

    ########################
    # FSR4 indicator
    ########################
    echo "${BOLD}FSR4SHOW:${RESET} Show on-screen FSR4 overlay (PROTON_FSR4_INDICATOR=1)."
    if ask_yes_no "${YELLOW}Show FSR4 overlay? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV FSR4SHOW=1"
    fi
    echo

    ########################
    # FFSR – numeric only 0 or 1–5
    ########################
    if [ "$HDR_ENABLED" -eq 0 ]; then
        while :; do
            echo "${BOLD}FFSR:${RESET} Wine fullscreen FSR scaler (SDR only)."
            echo "  0 = off"
            echo "  1 = enable with default strength"
            echo "  2–5 = enable and set that strength"
            printf "%s" "${YELLOW}FFSR value [0]: ${RESET}"
            read val
            val=$(trim "$val")
            [ -z "$val" ] && val="0"

            case "$val" in
                0)
                    echo
                    break
                    ;;
                *[!0-9]*)
                    printf "%s\n\n" "${RED}Please enter 0 or a number between 1 and 5.${RESET}"
                    ;;
                *)
                    if [ "$val" -ge 1 ] && [ "$val" -le 5 ]; then
                        LAUNCH_ENV="$LAUNCH_ENV FFSR=$val"
                        echo
                        break
                    else
                        printf "%s\n\n" "${RED}Please enter 0 or a number between 1 and 5.${RESET}"
                    fi
                    ;;
            esac
        done
    else
        printf "%s\n\n" "${CYAN}HDR is enabled → skipping fullscreen FSR (FFSR).${RESET}"
    fi

    ########################
    # DEBUG
    ########################
    echo "${BOLD}DEBUG:${RESET} Enable Proton/DXVK/VKD3D logging + FSR overlay (for troubleshooting)."
    if ask_yes_no "${YELLOW}Enable debug mode? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV DEBUG=1"
    fi
    echo

    ########################
    # DXVK async
    ########################
    echo "${BOLD}ASYNC:${RESET} DXVK async (DXVK_ASYNC=1). Use ONLY in singleplayer."
    if ask_yes_no "${YELLOW}Enable DXVK async? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV ASYNC=1"
    fi
    echo

    ########################
    # Local shader cache
    ########################
    echo "${BOLD}LSC:${RESET} Use local shader cache inside compatdata (PROTON_LOCAL_SHADER_CACHE=1)."
    if ask_yes_no "${YELLOW}Enable local shader cache? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV LSC=1"
    fi
    echo

    ########################
    # No WM decorations
    ########################
    echo "${BOLD}NVMD:${RESET} Disable WM decorations (borderless, PROTON_NO_WM_DECORATION=1)."
    if ask_yes_no "${YELLOW}Disable WM decorations? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV NVMD=1"
    fi
    echo

    ########################
    # NTSYNC
    ########################
    echo "${BOLD}NTS:${RESET} Use NTSYNC backend (PROTON_USE_NTSYNC=1, requires /dev/ntsync)."
    if ask_yes_no "${YELLOW}Enable NTSYNC? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV NTS=1"
    fi
    echo

    ########################
    # CPU topology – capped by MAX_CORES
    ########################
    while :; do
        echo "${BOLD}CPU:${RESET} Fake CPU topology for the game via WINE_CPU_TOPOLOGY."
        echo "  0 / empty = off"
        echo "  N (e.g. 8, 16) -> game sees N logical CPUs (N:0..N-1)."
        [ "$MAX_CORES" -gt 0 ] && echo "  (Max on this system: $MAX_CORES logical CPUs)"
        printf "%s" "${YELLOW}CPU visible to game [0]: ${RESET}"
        read val
        val=$(trim "$val")
        [ -z "$val" ] && val="0"

        case "$val" in
            0)
                echo
                break
                ;;
            *[!0-9]*)
                printf "%s\n\n" "${RED}Please enter 0 or a positive integer.${RESET}"
                ;;
            *)
                if [ "$MAX_CORES" -gt 0 ] && [ "$val" -gt "$MAX_CORES" ]; then
                    printf "%s\n" "${RED}You only have $MAX_CORES logical CPUs.${RESET}"
                    printf "%s\n\n" "${RED}Please enter 0 or a value between 1 and $MAX_CORES.${RESET}"
                else
                    LAUNCH_ENV="$LAUNCH_ENV CPU=$val"
                    echo
                    break
                fi
                ;;
        esac
    done

    ########################
    # game-performance
    ########################
    echo "${BOLD}GP:${RESET} Wrap command in CachyOS game-performance (if available)."
    if ask_yes_no "${YELLOW}Enable game-performance (GP=1)? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV GP=1"
    fi
    echo

    ########################
    # GameMode
    ########################
    echo "${BOLD}GM:${RESET} Wrap command in Feral GameMode (gamemoderun) if available."
    if ask_yes_no "${YELLOW}Enable GameMode (GM=1)? [y/n]: ${RESET}"; then
        LAUNCH_ENV="$LAUNCH_ENV GM=1"
    fi
    echo

    # Final output

    # Normalize CPU to avoid leading zeros, e.g. CPU=01 -> CPU=1
    LAUNCH_ENV=$(
        printf '%s\n' "$LAUNCH_ENV" \
        | sed -E 's/(^|[[:space:]])CPU=0+([1-9][0-9]*)/\1CPU=\2/g'
    )

    LAUNCH_ENV=$(trim "$LAUNCH_ENV")

    # Try to detect actual script path for the generated launch line
    if command -v gaming_env_wrapper.sh >/dev/null 2>&1; then
        SCRIPT_PATH=$(command -v gaming_env_wrapper.sh)
    elif [ -n "$0" ]; then
        SCRIPT_PATH="$0"
    else
        SCRIPT_PATH="$HOME/bin/gaming_env_wrapper.sh"
    fi

    printf "%s\n\n" "${BOLD}${CYAN}=== Generated Steam launch options ===${RESET}"
    if [ -n "$LAUNCH_ENV" ]; then
        printf "%s\n\n" "${GREEN}$LAUNCH_ENV $SCRIPT_PATH %command%${RESET}"
    else
        printf "%s\n\n" "${GREEN}$SCRIPT_PATH %command%${RESET}"
    fi
    echo "Copy the line above and paste it into the game's:"
    echo "  Steam → Properties → General → Launch options"
    echo
    exit 0
fi

###############################################################################
# NORMAL WRAPPER MODE (used by Steam) – non-interactive
###############################################################################

# HDR toggle
if [ "${HDR:-0}" = "1" ]; then
    export PROTON_ENABLE_WAYLAND=1
    export PROTON_ENABLE_HDR=1
    export DXVK_HDR=1
    export ENABLE_HDR_WSI=1
fi

# RDNA3 FSR4
if [ -n "${FSR4:-}" ] && [ "$FSR4" != "0" ]; then
    if [ "$FSR4" = "1" ]; then
        export PROTON_FSR4_RDNA3_UPGRADE=1
    else
        export PROTON_FSR4_RDNA3_UPGRADE=1
        if [ "$FSR4" != "1" ]; then
            export PROTON_FSR4_RDNA3_UPGRADE="$FSR4"
        fi
    fi
fi

# RDNA4 FSR4
if [ -n "${FSR4R4:-}" ] && [ "$FSR4R4" != "0" ]; then
    if [ "$FSR4R4" = "1" ]; then
        export PROTON_FSR4_UPGRADE=1
    else
        export PROTON_FSR4_UPGRADE="$FSR4R4"
    fi
fi

# FSR4 indicator
if [ "${FSR4SHOW:-0}" = "1" ]; then
    export PROTON_FSR4_INDICATOR=1
fi

# Wine fullscreen FSR (FFSR) – SDR only
if [ "${HDR:-0}" != "1" ] && [ -n "${FFSR:-}" ] && [ "$FFSR" != "0" ]; then
    export WINE_FULLSCREEN_FSR=1
    case "$FFSR" in
        ''|*[!0-9]*)
            ;;
        1)
            ;;
        *)
            export WINE_FULLSCREEN_FSR_STRENGTH="$FFSR"
            ;;
    esac
fi

# Debug / logging
if [ "${DEBUG:-0}" = "1" ]; then
    export PROTON_LOG=1
    export WINEDEBUG=-all
    export DXVK_LOG_LEVEL=debug
    export VKD3D_DEBUG=warn
    export PROTON_FSR4_INDICATOR=1
fi

# DXVK async
if [ "${ASYNC:-0}" = "1" ]; then
    export DXVK_ASYNC=1
fi

# Local shader cache
if [ "${LSC:-0}" = "1" ]; then
    export PROTON_LOCAL_SHADER_CACHE=1
fi

# No WM decoration
if [ "${NVMD:-0}" = "1" ]; then
    export PROTON_NO_WM_DECORATION=1
fi

# NTSYNC
if [ "${NTS:-0}" = "1" ]; then
    export PROTON_USE_NTSYNC=1
fi

# CPU topology (non-interactive: from CPU= env/toggle)
if [ -n "${CPU:-}" ]; then
    case "$CPU" in
        ''|*[!0-9]*)
            ;;
        *)
            count="$CPU"
            if [ "$count" -gt 0 ]; then
                i=0
                cpu_list=""
                while [ "$i" -lt "$count" ]; do
                    if [ -z "$cpu_list" ]; then
                        cpu_list="$i"
                    else
                        cpu_list="$cpu_list,$i"
                    fi
                    i=$((i + 1))
                done
                export WINE_CPU_TOPOLOGY="${count}:${cpu_list}"
            fi
            ;;
    esac
fi

# Optional debug: show final important env vars and command
if [ "${GENVW_DEBUG:-0}" = "1" ]; then
    echo "gENVW debug: effective environment and command:" >&2
    for var in \
        PROTON_ENABLE_WAYLAND PROTON_ENABLE_HDR DXVK_HDR ENABLE_HDR_WSI \
        PROTON_FSR4_RDNA3_UPGRADE PROTON_FSR4_UPGRADE PROTON_FSR4_INDICATOR \
        WINE_FULLSCREEN_FSR WINE_FULLSCREEN_FSR_STRENGTH \
        MANGOHUD \
        PROTON_LOG WINEDEBUG DXVK_LOG_LEVEL VKD3D_DEBUG \
        DXVK_ASYNC PROTON_LOCAL_SHADER_CACHE PROTON_NO_WM_DECORATION \
        PROTON_USE_NTSYNC WINE_CPU_TOPOLOGY
    do
        eval val=\$$var
        if [ -n "$val" ]; then
            echo "  $var=$val" >&2
        fi
    done
    echo "  GP=${GP:-0} GM=${GM:-0}" >&2
    echo "  Command: $*" >&2
fi

# CachyOS game-performance
if [ "${GP:-0}" = "1" ] && command -v game-performance >/dev/null 2>&1; then
    set -- game-performance "$@"
fi

# GameMode
if [ "${GM:-0}" = "1" ] && command -v gamemoderun >/dev/null 2>&1; then
    exec gamemoderun "$@"
else
    exec "$@"
fi
# end of gENVW
