#!/bin/bash

###########################
##
##      File: prompt_generator.sh
##
##      Author: Jesus Sanchez (jsanchez.consultant@gmail.com)
##
##	Copyright Notice: Creative Commons Attribution-ShareAlike 4.0 International License
##
##      Usage: /path/to/prompt_generator.sh
##
######################################################################

function welcomeMessage {
    whiptail --backtitle "SILVARION'S LINUX PROMPT GENERATOR" \
    --title "Silvarion's Prompt Generator" \
    --msgbox "Welcome to the Linux Prompt Generator Utility.
You will be able to customize your prompt by using the next menus" 20 80
}

function mainMenu {
    whiptail \
    --backtitle "SILVARION'S LINUX PROMPT GENERATOR" \
    --title "Main Menu" \
    --menu "Choose what you want to do" 20 80 10 \
    "Start" "Build your prompt from scratch" \
    "Continue" "Continue working on your current prompt" \
    "Read from ENV" "Read your current PS1, if any" \
    "Show current PS1" "Show the export command for your custom prompt" \
    "Quit" "Exit this wizard"
}

function selectShell {
    whiptail \
    --backtitle "SILVARION'S LINUX PROMPT GENERATOR" \
    --title "Select your shell" \
    --radiolist "Select the shell for the prompt to do" 30 80 15 \
    "BASH" "Bourne Again Shell" ON \
    "KSH" "Korn Shell" OFF
    "CSH" "C Shell"
}

function customPromptMenu {
    whiptail \
    --backtitle "SILVARION'S LINUX PROMPT GENERATOR" \
    --title "Custom Prompt" \
    --menu "Choose what you want to do" 20 80 10 \
    "Start" "Build your prompt from scratch" ON \
    "Read from ENV" "Read your current PS1, if any" \
    "Add an element to the prompt" "Add an element at the end of the current prompt" \
    "Show current PS1" "Show the export command for your custom prompt" \
    "Back" "Return to the previous menu" \
    "Quit" "Exit this wizard"

}

####################
## MAIN ALGORITHM ##
####################

welcomeMessage
action="New"
while [[ ${action} != "Quit" ]]
do
    action=$(mainMenu 3>&1 1>&2 2>&3)
    case ${action} in
        ("Start")
            interpreter=$(selectShell 3>&1 1>&2 2>&3)
            while [[ ${option} != "Back" ]]
            do
                startAction=$(customPromptMenu 3>&1 1>&2 2>&3)
                case ${startAction} in
                    ("Back")
                        #TO-DO: Shell menu
                        ;;
                    (*)
                        #TO-DO: Shell menu
                        ;;
                esac
            done
            ;;
        ("Read from ENV")
            #TO-DO: Shell menu
            ;;
        ("Show current PS1")
            #TO-DO: Shell menu
            ;;
        ("Quit")
            #TO-DO: Shell menu
            exit(0)
            ;;
        (*)
            #TO-DO: Shell menu
            ;;
    esac
done
