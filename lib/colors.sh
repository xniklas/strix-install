#!/bin/bash

# Color definitions using tput

# Reset
RESET=$(tput sgr0)

# Regular Colors
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

# Bold
BOLD_BLACK=$(tput bold && tput setaf 0)
BOLD_RED=$(tput bold && tput setaf 1)
BOLD_GREEN=$(tput bold && tput setaf 2)
BOLD_YELLOW=$(tput bold && tput setaf 3)
BOLD_BLUE=$(tput bold && tput setaf 4)
BOLD_MAGENTA=$(tput bold && tput setaf 5)
BOLD_CYAN=$(tput bold && tput setaf 6)
BOLD_WHITE=$(tput bold && tput setaf 7)

# Underline
UNDERLINE_BLACK=$(tput smul && tput setaf 0)
UNDERLINE_RED=$(tput smul && tput setaf 1)
UNDERLINE_GREEN=$(tput smul && tput setaf 2)
UNDERLINE_YELLOW=$(tput smul && tput setaf 3)
UNDERLINE_BLUE=$(tput smul && tput setaf 4)
UNDERLINE_MAGENTA=$(tput smul && tput setaf 5)
UNDERLINE_CYAN=$(tput smul && tput setaf 6)
UNDERLINE_WHITE=$(tput smul && tput setaf 7)

# Background
BACKGROUND_BLACK=$(tput setab 0)
BACKGROUND_RED=$(tput setab 1)
BACKGROUND_GREEN=$(tput setab 2)
BACKGROUND_YELLOW=$(tput setab 3)
BACKGROUND_BLUE=$(tput setab 4)
BACKGROUND_MAGENTA=$(tput setab 5)
BACKGROUND_CYAN=$(tput setab 6)
BACKGROUND_WHITE=$(tput setab 7)

# High Intensity
HI_BLACK=$(tput setaf 8)
HI_RED=$(tput setaf 9)
HI_GREEN=$(tput setaf 10)
HI_YELLOW=$(tput setaf 11)
HI_BLUE=$(tput setaf 12)
HI_MAGENTA=$(tput setaf 13)
HI_CYAN=$(tput setaf 14)
HI_WHITE=$(tput setaf 15)

# Bold High Intensity
BOLD_HI_BLACK=$(tput bold && tput setaf 8)
BOLD_HI_RED=$(tput bold && tput setaf 9)
BOLD_HI_GREEN=$(tput bold && tput setaf 10)
BOLD_HI_YELLOW=$(tput bold && tput setaf 11)
BOLD_HI_BLUE=$(tput bold && tput setaf 12)
BOLD_HI_MAGENTA=$(tput bold && tput setaf 13)
BOLD_HI_CYAN=$(tput bold && tput setaf 14)
BOLD_HI_WHITE=$(tput bold && tput setaf 15)

# High Intensity backgrounds
BACKGROUND_HI_BLACK=$(tput setab 8)
BACKGROUND_HI_RED=$(tput setab 9)
BACKGROUND_HI_GREEN=$(tput setab 10)
BACKGROUND_HI_YELLOW=$(tput setab 11)
BACKGROUND_HI_BLUE=$(tput setab 12)
BACKGROUND_HI_MAGENTA=$(tput setab 13)
BACKGROUND_HI_CYAN=$(tput setab 14)
BACKGROUND_HI_WHITE=$(tput setab 15)

# Usage example:
# echo "${BOLD_GREEN}This is bold green text${RESET}"
# echo "${UNDERLINE_RED}This is underlined red text${RESET}"

# Function to print all colors for testing
# print_all_colors() {
#     echo "Regular Colors:"
#     echo -e "${BLACK}BLACK ${RED}RED ${GREEN}GREEN ${YELLOW}YELLOW ${BLUE}BLUE ${MAGENTA}MAGENTA ${CYAN}CYAN ${WHITE}WHITE${RESET}"
#     echo "Bold Colors:"
#     echo -e "${BOLD_BLACK}BOLD_BLACK ${BOLD_RED}BOLD_RED ${BOLD_GREEN}BOLD_GREEN ${BOLD_YELLOW}BOLD_YELLOW ${BOLD_BLUE}BOLD_BLUE ${BOLD_MAGENTA}BOLD_MAGENTA ${BOLD_CYAN}BOLD_CYAN ${BOLD_WHITE}BOLD_WHITE${RESET}"
#     echo "Underline Colors:"
#     echo -e "${UNDERLINE_BLACK}UNDERLINE_BLACK ${UNDERLINE_RED}UNDERLINE_RED ${UNDERLINE_GREEN}UNDERLINE_GREEN ${UNDERLINE_YELLOW}UNDERLINE_YELLOW ${UNDERLINE_BLUE}UNDERLINE_BLUE ${UNDERLINE_MAGENTA}UNDERLINE_MAGENTA ${UNDERLINE_CYAN}UNDERLINE_CYAN ${UNDERLINE_WHITE}UNDERLINE_WHITE${RESET}"
#     echo "Background Colors:"
#     echo -e "${BACKGROUND_BLACK} BG_BLACK ${BACKGROUND_RED} BG_RED ${BACKGROUND_GREEN} BG_GREEN ${BACKGROUND_YELLOW} BG_YELLOW ${BACKGROUND_BLUE} BG_BLUE ${BACKGROUND_MAGENTA} BG_MAGENTA ${BACKGROUND_CYAN} BG_CYAN ${BACKGROUND_WHITE} BG_WHITE ${RESET}"
#     echo "High Intensity Colors:"
#     echo -e "${HI_BLACK}HI_BLACK ${HI_RED}HI_RED ${HI_GREEN}HI_GREEN ${HI_YELLOW}HI_YELLOW ${HI_BLUE}HI_BLUE ${HI_MAGENTA}HI_MAGENTA ${HI_CYAN}HI_CYAN ${HI_WHITE}HI_WHITE${RESET}"
#     echo "Bold High Intensity Colors:"
#     echo -e "${BOLD_HI_BLACK}BOLD_HI_BLACK ${BOLD_HI_RED}BOLD_HI_RED ${BOLD_HI_GREEN}BOLD_HI_GREEN ${BOLD_HI_YELLOW}BOLD_HI_YELLOW ${BOLD_HI_BLUE}BOLD_HI_BLUE ${BOLD_HI_MAGENTA}BOLD_HI_MAGENTA ${BOLD_HI_CYAN}BOLD_HI_CYAN ${BOLD_HI_WHITE}BOLD_HI_WHITE${RESET}"
#     echo "High Intensity Backgrounds:"
#     echo -e "${BACKGROUND_HI_BLACK} BG_HI_BLACK ${BACKGROUND_HI_RED} BG_HI_RED ${BACKGROUND_HI_GREEN} BG_HI_GREEN ${BACKGROUND_HI_YELLOW} BG_HI_YELLOW ${BACKGROUND_HI_BLUE} BG_HI_BLUE ${BACKGROUND_HI_MAGENTA} BG_HI_MAGENTA ${BACKGROUND_HI_CYAN} BG_HI_CYAN ${BACKGROUND_HI_WHITE} BG_HI_WHITE ${RESET}"
# }

# Uncomment to test
# print_all_colors
