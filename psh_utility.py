#!/usr/bin/env python
import logging
import os
import subprocess
from psh_logging import outputError

PSH_COMMON_MESSAGES = {
    'psh_cli': {
        'event': 'Checking for the Platform.sh CLI tool',
        'fail_message': """
            The Platform.sh CLI tool is not installed. Please add its installation to the build section of your
            .platform.app.yaml. See https://github.com/platformsh/platformsh-cli#installation for more information
        """,
        'success_message': 'The Platform.sh CLI tool is installed.'
    },
    'psh_cli_token': {
        'event': 'Checking for the Platform.sh CLI API token',
        'fail_message': """
        You will need to create an environmental variable 'PLATFORMSH_CLI_TOKEN' that contains a valid platform.sh
        API token before I can run platform.sh cli commands
        """,
        'success_message': 'Platform.sh CLI API token is available.'
    }
}


def runCommand(command, cwd=None):
    """
    Runs a subprocess on the system. Mostly used to interact with psh cli and git
    :param string|list command: Command to be run as a string or as a list
    :param string cwd: path to where we need the process to be run
    :return: dict {result: boolean, message: strdout|stderr }
    """
    procUpdate = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    output, procerror = procUpdate.communicate()

    if 0 == procUpdate.returncode:
        returnStatement = True
        message = output
    else:
        returnStatement = False
        message = procerror

    return {"result": returnStatement, "message": message}


def verifyPshCliInstalled():
    """
    Checks to make sure the psh cli tool is installed
    :return: bool
    @todo since we've moved the messaging, is this one needed anymore?
    """
    procResult = runCommand("which platform")
    return procResult['result']


def verifyPshCliToken():
    pshToken = os.getenv('PLATFORMSH_CLI_TOKEN', None)
    if pshToken is None:
        return False
    else:
        return True
